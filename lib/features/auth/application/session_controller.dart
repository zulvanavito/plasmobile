import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plasmobile/core/constants/api_error_codes.dart';
import 'package:plasmobile/core/errors/plas_exception.dart';
import 'package:plasmobile/core/router/app_router.dart';
import 'package:plasmobile/core/sync/pending_sync_queue.dart';
import 'package:plasmobile/data/dto/student_profile_dto.dart';
import 'package:plasmobile/data/repositories/plas_repository.dart';
import 'package:plasmobile/data/services/auth_service.dart';
import 'package:plasmobile/features/shared/providers/plas_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

String classOnboardingDoneKey(String mahasiswaId) =>
    'plas_class_onboarding_done_$mahasiswaId';

class SessionState {
  const SessionState({
    this.authUser,
    this.profile,
    this.isBusy = false,
    this.bootstrapError,
  });

  final AuthSessionUser? authUser;
  final StudentProfileDto? profile;
  final bool isBusy;
  final String? bootstrapError;

  bool get isClassLocked =>
      (profile?.preTestSubmitted ?? false) && profile?.kelas != null;

  SessionState copyWith({
    AuthSessionUser? authUser,
    bool clearAuthUser = false,
    StudentProfileDto? profile,
    bool clearProfile = false,
    bool? isBusy,
    String? bootstrapError,
    bool clearBootstrapError = false,
  }) {
    return SessionState(
      authUser: clearAuthUser ? null : (authUser ?? this.authUser),
      profile: clearProfile ? null : (profile ?? this.profile),
      isBusy: isBusy ?? this.isBusy,
      bootstrapError: clearBootstrapError
          ? null
          : (bootstrapError ?? this.bootstrapError),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SessionState &&
          runtimeType == other.runtimeType &&
          authUser == other.authUser &&
          profile == other.profile &&
          isBusy == other.isBusy &&
          bootstrapError == other.bootstrapError;

  @override
  int get hashCode =>
      Object.hash(authUser, profile, isBusy, bootstrapError);
}

class SessionController extends Notifier<SessionState> {
  StreamSubscription<AuthSessionUser?>? _authSubscription;
  bool _isExplicitAuthAction = false;
  bool _disposed = false;
  int _bootstrapRevision = 0;

  AuthService get _authService => ref.read(authServiceProvider);
  PlasRepository get _repository => ref.read(plasRepositoryProvider);
  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);
  StateController<AuthGateStatus> get _gateNotifier =>
      ref.read(authGateStatusProvider.notifier);

  @override
  SessionState build() {
    _disposed = false;
    _authSubscription?.cancel();
    final authService = ref.watch(authServiceProvider);
    _authSubscription = authService.authStateChanges().listen(
      _handleAuthStateChange,
    );
    ref.onDispose(() {
      _disposed = true;
      _authSubscription?.cancel();
      _authSubscription = null;
    });
    return SessionState(authUser: authService.currentUser);
  }

  void _handleAuthStateChange(AuthSessionUser? user) {
    if (_disposed || _isExplicitAuthAction) return;

    if (user == null) {
      if (_authService.currentUser != null) return;
      final currentGate = _gateNotifier.state;
      final wasAuthenticated =
          state.authUser != null ||
          (currentGate != AuthGateStatus.unauthenticated &&
              currentGate != AuthGateStatus.loading);
      if (wasAuthenticated) {
        _bootstrapRevision++;
        state = const SessionState();
        ref.invalidate(classesProvider);
        invalidateLearningDataRef(ref);
        _gateNotifier.state = AuthGateStatus.unauthenticated;
      }
      return;
    }

    if (state.authUser?.userId == user.userId) {
      state = state.copyWith(authUser: user);
    }
  }

  AuthGateStatus _resolveGateForProfile(StudentProfileDto profile) {
    final onboardingDone =
        _prefs.getBool(classOnboardingDoneKey(profile.mahasiswaId)) ?? false;
    if (profile.kelas != null || profile.preTestSubmitted || onboardingDone) {
      return AuthGateStatus.authenticated;
    }
    return AuthGateStatus.needsClass;
  }

  Future<void> bootstrap() async {
    final revision = ++_bootstrapRevision;
    final user = _authService.currentUser;
    if (user == null) {
      if (_disposed) return;
      state = const SessionState();
      _gateNotifier.state = AuthGateStatus.unauthenticated;
      return;
    }

    state = state.copyWith(
      authUser: user,
      isBusy: true,
      clearBootstrapError: true,
    );
    _gateNotifier.state = AuthGateStatus.loading;

    try {
      final profile = await _repository.getMe();
      if (_disposed ||
          revision != _bootstrapRevision ||
          _authService.currentUser?.userId != user.userId) {
        return;
      }
      state = state.copyWith(
        authUser: user,
        profile: profile,
        isBusy: false,
        clearBootstrapError: true,
      );
      _gateNotifier.state = _resolveGateForProfile(profile);
    } on PlasApiException catch (error) {
      if (_disposed ||
          revision != _bootstrapRevision ||
          _authService.currentUser?.userId != user.userId) {
        return;
      }
      if (error.code == ApiErrorCodes.profileNotFound ||
          error.statusCode == 404) {
        state = state.copyWith(
          authUser: user,
          clearProfile: true,
          isBusy: false,
          clearBootstrapError: true,
        );
        _gateNotifier.state = AuthGateStatus.needsIdentity;
        return;
      }
      if (error.code == ApiErrorCodes.unauthorized || error.statusCode == 401) {
        _isExplicitAuthAction = true;
        try {
          try {
            await _authService.signOut();
          } catch (_) {
            // Ensure local state transitions even if remote sign-out fails.
          }
          if (_disposed) return;
          state = const SessionState();
          ref.invalidate(classesProvider);
          invalidateLearningDataRef(ref);
          _gateNotifier.state = AuthGateStatus.unauthenticated;
        } finally {
          _isExplicitAuthAction = false;
        }
        return;
      }

      _gateNotifier.state = AuthGateStatus.loading;
      state = state.copyWith(
        authUser: user,
        isBusy: false,
        bootstrapError: error.message,
      );
    } catch (error) {
      if (_disposed ||
          revision != _bootstrapRevision ||
          _authService.currentUser?.userId != user.userId) {
        return;
      }
      _gateNotifier.state = AuthGateStatus.loading;
      state = state.copyWith(
        authUser: user,
        isBusy: false,
        bootstrapError: plasErrorMessage(
          ApiErrorCodes.serverError,
          fallback: error.toString(),
        ),
      );
    }
  }

  Future<void> signInWithGoogle() {
    return _performSignIn(() => _authService.signInWithGoogle());
  }

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) {
    return _performSignIn(
      () => _authService.signInWithEmail(email: email, password: password),
    );
  }

  Future<void> signUpWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) {
    return _performSignIn(
      () => _authService.signUpWithEmail(
        email: email,
        password: password,
        displayName: displayName,
      ),
    );
  }

  Future<void> _performSignIn(
    Future<AuthSessionUser> Function() authenticate,
  ) async {
    _isExplicitAuthAction = true;
    _bootstrapRevision++;
    state = state.copyWith(isBusy: true, clearBootstrapError: true);

    try {
      final user = await authenticate();
      if (_disposed) return;
      await _loadProfileAfterAuth(user);
    } catch (_) {
      if (!_disposed) {
        state = state.copyWith(isBusy: false);
      }
      rethrow;
    } finally {
      _isExplicitAuthAction = false;
    }
  }

  Future<void> _loadProfileAfterAuth(AuthSessionUser user) async {
    try {
      final profile = await _repository.getMe();
      if (_disposed) return;
      state = state.copyWith(
        authUser: user,
        profile: profile,
        isBusy: false,
        clearBootstrapError: true,
      );
      _gateNotifier.state = _resolveGateForProfile(profile);
    } on PlasApiException catch (error) {
      if (_disposed) return;
      if (error.code == ApiErrorCodes.profileNotFound ||
          error.statusCode == 404) {
        state = state.copyWith(
          authUser: user,
          clearProfile: true,
          isBusy: false,
          clearBootstrapError: true,
        );
        _gateNotifier.state = AuthGateStatus.needsIdentity;
        return;
      }
      if (error.code == ApiErrorCodes.unauthorized || error.statusCode == 401) {
        try {
          await _authService.signOut();
        } catch (_) {
          // Best-effort cleanup before rethrowing auth error to M02.
        }
        if (_disposed) return;
        state = const SessionState();
        _gateNotifier.state = AuthGateStatus.unauthenticated;
        rethrow;
      }
      state = state.copyWith(authUser: user, isBusy: false);
      rethrow;
    }
  }

  Future<void> completeIdentity({
    required String nama,
    required String nim,
  }) async {
    state = state.copyWith(isBusy: true, clearBootstrapError: true);
    try {
      final profile = await _repository.createProfile(
        CreateProfileRequest(
          nama: nama.trim(),
          nim: nim.trim(),
          kelasId: null,
        ),
      );
      if (_disposed) return;
      state = state.copyWith(
        profile: profile,
        isBusy: false,
        clearBootstrapError: true,
      );
      _gateNotifier.state = _resolveGateForProfile(profile);
    } catch (_) {
      if (!_disposed) {
        state = state.copyWith(isBusy: false);
      }
      rethrow;
    }
  }

  Future<void> joinClass(String kelasId) async {
    state = state.copyWith(isBusy: true, clearBootstrapError: true);
    try {
      final updated = await _repository.updateClass(kelasId);
      await _prefs.setBool(classOnboardingDoneKey(updated.mahasiswaId), true);
      if (_disposed) return;
      state = state.copyWith(
        profile: updated,
        isBusy: false,
        clearBootstrapError: true,
      );
      _gateNotifier.state = AuthGateStatus.authenticated;
    } catch (_) {
      if (!_disposed) {
        state = state.copyWith(isBusy: false);
      }
      rethrow;
    }
  }

  Future<void> skipClassOnboarding() async {
    final profile = state.profile;
    if (profile != null) {
      await _prefs.setBool(classOnboardingDoneKey(profile.mahasiswaId), true);
    }
    if (_disposed) return;
    _gateNotifier.state = AuthGateStatus.authenticated;
  }

  Future<void> refreshProfile() async {
    final revision = _bootstrapRevision;
    final userId = _authService.currentUser?.userId;
    if (userId == null) return;
    final profile = await _repository.getMe();
    if (_disposed ||
        revision != _bootstrapRevision ||
        _authService.currentUser?.userId != userId) {
      return;
    }
    state = state.copyWith(profile: profile);
  }

  Future<void> signOut() async {
    _isExplicitAuthAction = true;
    _bootstrapRevision++;
    state = state.copyWith(isBusy: true, clearBootstrapError: true);
    try {
      try {
        await _authService.signOut();
      } catch (_) {
        // Local session state must still clear if remote sign-out fails.
      }
      if (_disposed) return;
      state = const SessionState();
      ref.invalidate(classesProvider);
      invalidateLearningDataRef(ref);
      _gateNotifier.state = AuthGateStatus.unauthenticated;
    } finally {
      _isExplicitAuthAction = false;
    }
  }
}

final sessionControllerProvider =
    NotifierProvider<SessionController, SessionState>(
  SessionController.new,
);
