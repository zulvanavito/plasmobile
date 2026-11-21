import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:plasmobile/core/config/app_env.dart';
import 'package:plasmobile/core/constants/api_error_codes.dart';
import 'package:plasmobile/core/errors/plas_exception.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthSessionUser {
  const AuthSessionUser({
    required this.userId,
    required this.email,
    this.displayName,
    required this.accessToken,
  });

  final String userId;
  final String email;
  final String? displayName;
  final String accessToken;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthSessionUser &&
          runtimeType == other.runtimeType &&
          userId == other.userId &&
          email == other.email &&
          displayName == other.displayName &&
          accessToken == other.accessToken;

  @override
  int get hashCode => Object.hash(userId, email, displayName, accessToken);

  @override
  String toString() =>
      'AuthSessionUser(userId: $userId, email: $email, displayName: $displayName)';
}

abstract interface class AuthService {
  AuthSessionUser? get currentUser;

  Stream<AuthSessionUser?> authStateChanges();

  Future<String?> getAccessToken();

  Future<AuthSessionUser> signInWithEmail({
    required String email,
    required String password,
  });

  Future<AuthSessionUser> signUpWithEmail({
    required String email,
    required String password,
    String? displayName,
  });

  Future<AuthSessionUser> signInWithGoogle();

  Future<void> signOut();
}

/// Auth-only Supabase wrapper (`GoTrueClient` + `GoogleSignIn`).
/// Never performs direct PostgREST table or RPC queries (P1/P4).
class SupabaseAuthService implements AuthService {
  const SupabaseAuthService({
    this.authClient,
    this.googleSignIn,
  });

  @visibleForTesting
  final GoTrueClient? authClient;
  @visibleForTesting
  final GoogleSignIn? googleSignIn;

  GoTrueClient get _auth => authClient ?? Supabase.instance.client.auth;

  GoogleSignIn get _google =>
      googleSignIn ??
      GoogleSignIn(
        scopes: const ['email', 'profile'],
        serverClientId:
            AppEnv.googleWebClientId.isEmpty ? null : AppEnv.googleWebClientId,
      );

  @override
  AuthSessionUser? get currentUser => _mapSession(_auth.currentSession);

  @override
  Stream<AuthSessionUser?> authStateChanges() {
    return _auth.onAuthStateChange.map((state) => _mapSession(state.session));
  }

  @override
  Future<String?> getAccessToken() async {
    final session = _auth.currentSession;
    if (session == null) return null;
    if (session.isExpired) {
      try {
        final refreshed = await _auth.refreshSession();
        return refreshed.session?.accessToken;
      } on AuthException {
        return null;
      }
    }
    return session.accessToken;
  }

  @override
  Future<AuthSessionUser> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      final user = _mapSession(response.session);
      if (user == null) {
        throw PlasApiException.fromApiCode(
          ApiErrorCodes.unauthorized,
          statusCode: 401,
          serverMessage: 'Sesi Supabase tidak tersedia setelah login.',
        );
      }
      return user;
    } on PlasApiException {
      rethrow;
    } on AuthException catch (e) {
      throw _mapAuthException(e);
    } catch (e) {
      throw PlasApiException.fromApiCode(
        ApiErrorCodes.unauthorized,
        statusCode: 401,
        serverMessage: e.toString(),
      );
    }
  }

  @override
  Future<AuthSessionUser> signUpWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) async {
    try {
      final trimmedName = displayName?.trim();
      final response = await _auth.signUp(
        email: email.trim(),
        password: password,
        data: trimmedName != null && trimmedName.isNotEmpty
            ? <String, dynamic>{'full_name': trimmedName}
            : null,
      );
      final user = _mapSession(response.session);
      if (user == null) {
        throw PlasApiException.fromApiCode(
          ApiErrorCodes.unauthorized,
          statusCode: 401,
          serverMessage:
              'Pendaftaran berhasil, tetapi sesi aktif belum tersedia.',
        );
      }
      return user;
    } on PlasApiException {
      rethrow;
    } on AuthException catch (e) {
      throw _mapAuthException(e);
    } catch (e) {
      throw PlasApiException.fromApiCode(
        ApiErrorCodes.unauthorized,
        statusCode: 401,
        serverMessage: e.toString(),
      );
    }
  }

  @override
  Future<AuthSessionUser> signInWithGoogle() async {
    try {
      final googleAccount = await _google.signIn();
      if (googleAccount == null) {
        throw PlasApiException.fromApiCode(
          ApiErrorCodes.unauthorized,
          statusCode: 401,
          serverMessage: 'Login Google dibatalkan.',
        );
      }

      final googleAuth = await googleAccount.authentication;
      final idToken = googleAuth.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw PlasApiException.fromApiCode(
          ApiErrorCodes.unauthorized,
          statusCode: 401,
          serverMessage: 'ID token Google tidak tersedia.',
        );
      }

      // Required by gotrue 2.10 for native Google Sign-In ID token exchange.
      // ignore: experimental_member_use
      final response = await _auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: googleAuth.accessToken,
      );
      final user = _mapSession(response.session);
      if (user == null) {
        throw PlasApiException.fromApiCode(
          ApiErrorCodes.unauthorized,
          statusCode: 401,
          serverMessage: 'Sesi Supabase tidak tersedia setelah login Google.',
        );
      }
      return user;
    } on PlasApiException {
      rethrow;
    } on AuthException catch (e) {
      throw _mapAuthException(e);
    } catch (e) {
      throw PlasApiException.fromApiCode(
        ApiErrorCodes.unauthorized,
        statusCode: 401,
        serverMessage: e.toString(),
      );
    }
  }

  @override
  Future<void> signOut() async {
    try {
      try {
        await _google.signOut();
      } catch (_) {
        // Best-effort Google session cleanup; proceed with GoTrue signOut.
      }
      await _auth.signOut();
    } on AuthException catch (e) {
      throw _mapAuthException(e);
    }
  }

  AuthSessionUser? _mapSession(Session? session) {
    if (session == null) return null;
    final user = session.user;
    final metadata = user.userMetadata;
    final displayName = metadata?['full_name'] as String? ??
        metadata?['name'] as String? ??
        metadata?['display_name'] as String?;
    return AuthSessionUser(
      userId: user.id,
      email: user.email ?? '',
      displayName: displayName,
      accessToken: session.accessToken,
    );
  }

  PlasApiException _mapAuthException(AuthException error) {
    if (error is AuthRetryableFetchException) {
      return PlasApiException.offline(error.message);
    }
    final status = int.tryParse(error.statusCode ?? '');
    final String code;
    if (status == 400 || status == 422) {
      code = ApiErrorCodes.validationError;
    } else if (status == 401 || status == 403) {
      code = ApiErrorCodes.unauthorized;
    } else if (status != null && status >= 500) {
      code = ApiErrorCodes.serverError;
    } else {
      code = ApiErrorCodes.unauthorized;
    }
    return PlasApiException.fromApiCode(
      code,
      statusCode: status ?? 401,
      serverMessage: error.message,
    );
  }
}

class MockAuthService implements AuthService {
  MockAuthService({AuthSessionUser? initialUser}) : _currentUser = initialUser;

  final StreamController<AuthSessionUser?> _controller =
      StreamController<AuthSessionUser?>.broadcast();
  AuthSessionUser? _currentUser;

  @override
  AuthSessionUser? get currentUser => _currentUser;

  @override
  Stream<AuthSessionUser?> authStateChanges() => _controller.stream;

  @override
  Future<String?> getAccessToken() async => _currentUser?.accessToken;

  @override
  Future<AuthSessionUser> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = _validateCredentials(email, password);
    final user = AuthSessionUser(
      userId: 'mock-student-001',
      email: normalizedEmail,
      displayName: _currentUser?.displayName ?? _deriveName(normalizedEmail),
      accessToken: 'mock-jwt-token',
    );
    _setUser(user);
    return user;
  }

  @override
  Future<AuthSessionUser> signUpWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final normalizedEmail = _validateCredentials(email, password);
    final trimmedName = displayName?.trim();
    final user = AuthSessionUser(
      userId: 'mock-student-001',
      email: normalizedEmail,
      displayName: trimmedName != null && trimmedName.isNotEmpty
          ? trimmedName
          : _deriveName(normalizedEmail),
      accessToken: 'mock-jwt-token',
    );
    _setUser(user);
    return user;
  }

  @override
  Future<AuthSessionUser> signInWithGoogle() async {
    const user = AuthSessionUser(
      userId: 'mock-google-001',
      email: 'mahasiswa.google@plas.ac.id',
      displayName: 'Mahasiswa PLAS',
      accessToken: 'mock-google-jwt-token',
    );
    _setUser(user);
    return user;
  }

  @override
  Future<void> signOut() async {
    _setUser(null);
  }

  void dispose() {
    if (!_controller.isClosed) {
      _controller.close();
    }
  }

  String _validateCredentials(String email, String password) {
    final normalized = email.trim();
    if (!normalized.contains('@') || !normalized.contains('.')) {
      throw PlasApiException.fromApiCode(
        ApiErrorCodes.validationError,
        statusCode: 400,
        serverMessage: 'Format email tidak valid.',
      );
    }
    if (password.length < 6) {
      throw PlasApiException.fromApiCode(
        ApiErrorCodes.validationError,
        statusCode: 400,
        serverMessage: 'Password minimal 6 karakter.',
      );
    }
    return normalized;
  }

  String _deriveName(String email) {
    final localPart = email.split('@').first;
    if (localPart.isEmpty) return 'Mahasiswa PLAS';
    return localPart;
  }

  void _setUser(AuthSessionUser? user) {
    _currentUser = user;
    if (!_controller.isClosed) {
      _controller.add(user);
    }
  }
}

final authServiceProvider = Provider<AuthService>((ref) {
  if (AppEnv.useMock) {
    final mockService = MockAuthService();
    ref.onDispose(mockService.dispose);
    return mockService;
  }
  return SupabaseAuthService();
});
