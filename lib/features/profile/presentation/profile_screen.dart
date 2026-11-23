import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:plasmobile/core/constants/api_error_codes.dart';
import 'package:plasmobile/core/errors/plas_exception.dart';
import 'package:plasmobile/core/theme/plas_tokens.dart';
import 'package:plasmobile/data/dto/ai_dto.dart';
import 'package:plasmobile/data/dto/student_profile_dto.dart';
import 'package:plasmobile/data/services/auth_service.dart';
import 'package:plasmobile/features/auth/application/session_controller.dart';
import 'package:plasmobile/features/shared/providers/plas_providers.dart';
import 'package:plasmobile/shared/widgets/confirm_dialog.dart';
import 'package:plasmobile/shared/widgets/plas_state_views.dart';
import 'package:plasmobile/shared/widgets/plas_status_badge.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _lockedCodeController = TextEditingController();

  String? _classActionError;
  String? _classActionSuccess;
  bool _isSavingClass = false;

  @override
  void initState() {
    super.initState();
    _syncLockedCodeText(ref.read(sessionControllerProvider).profile);
  }

  @override
  void dispose() {
    _codeController.dispose();
    _lockedCodeController.dispose();
    super.dispose();
  }

  void _syncLockedCodeText(StudentProfileDto? profile) {
    final lockedDisplayText =
        profile?.kelas?.kode ?? 'Pengguna Umum (Tanpa Kelas)';
    if (_lockedCodeController.text != lockedDisplayText) {
      _lockedCodeController.text = lockedDisplayText;
    }
  }

  Future<void> _handleRefresh() async {
    ref.invalidate(aiQuotaProvider);
    ref.invalidate(classesProvider);
    await Future.wait<void>([
      ref
          .read(sessionControllerProvider.notifier)
          .refreshProfile()
          .catchError((_) {}),
      ref.read(aiQuotaProvider.future).then((_) {}).catchError((_) {}),
      ref.read(classesProvider.future).then((_) {}).catchError((_) {}),
    ]);
  }

  ClassInfoDto? _findMatchingClass(List<ClassInfoDto> classes) {
    final normalized = _codeController.text.trim().toUpperCase();
    if (normalized.isEmpty) return null;
    for (final item in classes) {
      if (item.kode.trim().toUpperCase() == normalized) {
        return item;
      }
    }
    return null;
  }

  Future<void> _saveClass(ClassInfoDto selected) async {
    setState(() {
      _isSavingClass = true;
      _classActionError = null;
      _classActionSuccess = null;
    });
    try {
      await ref
          .read(sessionControllerProvider.notifier)
          .joinClass(selected.kelasId);
      await ref
          .read(sessionControllerProvider.notifier)
          .refreshProfile()
          .catchError((_) {});
      ref.invalidate(classesProvider);
      if (!mounted) return;
      _codeController.clear();
      setState(() {
        _isSavingClass = false;
        _classActionError = null;
        _classActionSuccess =
            'Kelas berhasil diperbarui menjadi ${selected.kode}.';
      });
    } on PlasApiException catch (error) {
      if (error.code == ApiErrorCodes.classLocked) {
        try {
          await ref.read(sessionControllerProvider.notifier).refreshProfile();
        } catch (_) {
          // Keep class_locked message visible if profile refresh fails.
        }
      }
      if (!mounted) return;
      final isNowLocked = ref.read(sessionControllerProvider).isClassLocked;
      setState(() {
        _isSavingClass = false;
        _classActionSuccess = null;
        _classActionError =
            (error.code == ApiErrorCodes.classLocked && isNowLocked)
                ? null
                : error.message;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isSavingClass = false;
        _classActionSuccess = null;
        _classActionError = plasErrorMessage(
          ApiErrorCodes.serverError,
          fallback: error.toString(),
        );
      });
    }
  }

  Future<void> _handleLogout() async {
    final confirmed = await showLogoutConfirmDialog(context);
    if (!confirmed || !mounted) return;
    await ref.read(sessionControllerProvider.notifier).signOut();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<SessionState>(sessionControllerProvider, (_, next) {
      _syncLockedCodeText(next.profile);
    });

    final session = ref.watch(sessionControllerProvider);
    final aiQuotaAsync = ref.watch(aiQuotaProvider);
    final classesAsync = ref.watch(classesProvider);

    final profile = session.profile;
    final authUser = session.authUser;
    final isLocked = session.isClassLocked;
    final isBusy = _isSavingClass || session.isBusy;

    final matchedClass = isLocked
        ? null
        : classesAsync.maybeWhen(
            data: _findMatchingClass,
            orElse: () => null,
          );

    return Scaffold(
      backgroundColor: PlasColors.bgCanvas,
      body: SafeArea(
        child: RefreshIndicator(
          color: PlasColors.brandPrimary,
          onRefresh: _handleRefresh,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(PlasSpacing.space4),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _ProfileHeaderCard(),
                    const SizedBox(height: PlasSpacing.space4),
                    _StudentIdentityCard(
                      profile: profile,
                      authUser: authUser,
                    ),
                    const SizedBox(height: PlasSpacing.space4),
                    _AiQuotaWitaCard(
                      aiQuotaAsync: aiQuotaAsync,
                      onRetry: () => ref.invalidate(aiQuotaProvider),
                    ),
                    const SizedBox(height: PlasSpacing.space5),
                    _ClassManagementSection(
                      session: session,
                      classesAsync: classesAsync,
                      isLocked: isLocked,
                      isBusy: isBusy,
                      codeController: _codeController,
                      lockedCodeController: _lockedCodeController,
                      matchedClass: matchedClass,
                      classActionError: _classActionError,
                      classActionSuccess: _classActionSuccess,
                      onCodeChanged: () {
                        setState(() {
                          _classActionError = null;
                          _classActionSuccess = null;
                        });
                      },
                      onClearCode: () {
                        _codeController.clear();
                        setState(() {
                          _classActionError = null;
                          _classActionSuccess = null;
                        });
                      },
                      onPickClass: (item) {
                        _codeController.text = item.kode;
                        _codeController.selection = TextSelection.collapsed(
                          offset: item.kode.length,
                        );
                        setState(() {
                          _classActionError = null;
                          _classActionSuccess = null;
                        });
                      },
                      onRetryClasses: () => ref.invalidate(classesProvider),
                      onSaveClass: matchedClass != null && !isBusy && !isLocked
                          ? () => _saveClass(matchedClass)
                          : null,
                    ),
                    const SizedBox(height: PlasSpacing.space5),
                    OutlinedButton(
                      key: const ValueKey('profile_logout_button'),
                      style: _logoutButtonStyle(),
                      onPressed: isBusy ? null : _handleLogout,
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Symbols.logout, size: 20),
                          SizedBox(width: PlasSpacing.space2),
                          Flexible(
                            child: Text(
                              'Keluar Akun',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: PlasSpacing.space4),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileHeaderCard extends StatelessWidget {
  const _ProfileHeaderCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('profile_header_card'),
      padding: const EdgeInsets.all(PlasSpacing.space4),
      decoration: BoxDecoration(
        color: PlasColors.bgSurface,
        borderRadius: BorderRadius.circular(PlasRadii.lg),
        border: Border.all(color: PlasColors.borderDivider),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CS LAB ENV // PROFIL',
            style: PlasTypography.codeMeta,
          ),
          SizedBox(height: PlasSpacing.space1),
          Text(
            'Profil & Kelas Mahasiswa',
            style: PlasTypography.display,
          ),
        ],
      ),
    );
  }
}

class _StudentIdentityCard extends StatelessWidget {
  const _StudentIdentityCard({
    required this.profile,
    required this.authUser,
  });

  final StudentProfileDto? profile;
  final AuthSessionUser? authUser;

  @override
  Widget build(BuildContext context) {
    final displayName = profile?.nama.trim().isNotEmpty == true
        ? profile!.nama.trim()
        : (authUser?.displayName?.trim().isNotEmpty == true
            ? authUser!.displayName!.trim()
            : 'Mahasiswa');
    final initials = _computeInitials(displayName);
    final nim = profile?.nim.trim() ?? '';
    final email = authUser?.email.trim() ?? '';
    final kelas = profile?.kelas;

    return Container(
      key: const ValueKey('profile_identity_card'),
      padding: const EdgeInsets.all(PlasSpacing.space4),
      decoration: BoxDecoration(
        color: PlasColors.bgSurface,
        borderRadius: BorderRadius.circular(PlasRadii.lg),
        border: Border.all(color: PlasColors.borderDivider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            key: const ValueKey('profile_avatar_initials'),
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: PlasColors.brandTint,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              initials,
              style: PlasTypography.title.copyWith(
                color: PlasColors.brandPrimary,
              ),
            ),
          ),
          const SizedBox(width: PlasSpacing.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(displayName, style: PlasTypography.heading),
                if (nim.isNotEmpty) ...[
                  const SizedBox(height: PlasSpacing.space1),
                  Wrap(
                    spacing: PlasSpacing.space2,
                    runSpacing: PlasSpacing.space1,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text('NIM', style: PlasTypography.caption),
                      Text(nim, style: PlasTypography.codeMeta),
                    ],
                  ),
                ],
                if (email.isNotEmpty) ...[
                  const SizedBox(height: PlasSpacing.space2),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Symbols.mail,
                        size: 16,
                        color: PlasColors.textMuted,
                      ),
                      const SizedBox(width: PlasSpacing.space1),
                      Expanded(
                        child: Text(email, style: PlasTypography.body),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: PlasSpacing.space3),
                Wrap(
                  spacing: PlasSpacing.space2,
                  runSpacing: PlasSpacing.space2,
                  children: [
                    if (kelas != null)
                      PlasStatusBadge(
                        key: const ValueKey('profile_class_status_badge'),
                        label: kelas.kode,
                        variant: PlasBadgeVariant.brand,
                        icon: Symbols.school,
                      )
                    else
                      const PlasStatusBadge(
                        key: ValueKey('profile_class_status_badge'),
                        label: 'Pengguna Umum (Tanpa Kelas)',
                        variant: PlasBadgeVariant.neutral,
                        icon: Symbols.person,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AiQuotaWitaCard extends StatelessWidget {
  const _AiQuotaWitaCard({
    required this.aiQuotaAsync,
    required this.onRetry,
  });

  final AsyncValue<AiQuotaDto> aiQuotaAsync;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('profile_ai_quota_card'),
      padding: const EdgeInsets.all(PlasSpacing.space4),
      decoration: BoxDecoration(
        color: PlasColors.bgSurface,
        borderRadius: BorderRadius.circular(PlasRadii.lg),
        border: Border.all(color: PlasColors.borderDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Kuota AI Harian (WITA)',
            style: PlasTypography.heading,
          ),
          const SizedBox(height: PlasSpacing.space3),
          aiQuotaAsync.when(
            loading: () => const PlasLoadingSkeleton(
              message: 'Memuat kuota AI WITA...',
              cardCount: 1,
            ),
            error: (error, _) => PlasErrorView(
              title: 'Gagal Memuat Kuota AI',
              message: _errorMessage(error),
              onRetry: onRetry,
            ),
            data: (quota) {
              final variant = quota.remainingQuota <= 0
                  ? PlasBadgeVariant.error
                  : (quota.remainingQuota <= 3
                      ? PlasBadgeVariant.warning
                      : PlasBadgeVariant.brand);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: PlasSpacing.space2,
                    runSpacing: PlasSpacing.space2,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      PlasStatusBadge(
                        key: const ValueKey('profile_ai_quota_badge'),
                        label:
                            '${quota.remainingQuota}/${quota.dailyLimit} WITA',
                        variant: variant,
                        icon: quota.remainingQuota <= 0
                            ? Symbols.error
                            : Symbols.schedule,
                      ),
                      Text(
                        'Tanggal aktif: ${quota.usageDate}',
                        style: PlasTypography.caption,
                      ),
                    ],
                  ),
                  const SizedBox(height: PlasSpacing.space2),
                  const Text(
                    'Reset otomatis pukul 00:00 WITA',
                    style: PlasTypography.body,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ClassManagementSection extends StatelessWidget {
  const _ClassManagementSection({
    required this.session,
    required this.classesAsync,
    required this.isLocked,
    required this.isBusy,
    required this.codeController,
    required this.lockedCodeController,
    required this.matchedClass,
    required this.classActionError,
    required this.classActionSuccess,
    required this.onCodeChanged,
    required this.onClearCode,
    required this.onPickClass,
    required this.onRetryClasses,
    required this.onSaveClass,
  });

  final SessionState session;
  final AsyncValue<List<ClassInfoDto>> classesAsync;
  final bool isLocked;
  final bool isBusy;
  final TextEditingController codeController;
  final TextEditingController lockedCodeController;
  final ClassInfoDto? matchedClass;
  final String? classActionError;
  final String? classActionSuccess;
  final VoidCallback onCodeChanged;
  final VoidCallback onClearCode;
  final ValueChanged<ClassInfoDto> onPickClass;
  final VoidCallback onRetryClasses;
  final VoidCallback? onSaveClass;

  @override
  Widget build(BuildContext context) {
    final currentClass = session.profile?.kelas;
    final preTestSubmitted = session.profile?.preTestSubmitted ?? false;

    return Container(
      key: const ValueKey('profile_class_section'),
      padding: const EdgeInsets.all(PlasSpacing.space4),
      decoration: BoxDecoration(
        color: PlasColors.bgSurface,
        borderRadius: BorderRadius.circular(PlasRadii.lg),
        border: Border.all(color: PlasColors.borderDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Kelas Pembelajaran',
            style: PlasTypography.heading,
          ),
          const SizedBox(height: PlasSpacing.space3),
          _CurrentClassCard(
            kelas: currentClass,
            preTestSubmitted: preTestSubmitted,
          ),
          const SizedBox(height: PlasSpacing.space4),
          if (isLocked) ...[
            Container(
              key: const ValueKey('profile_class_locked_banner'),
              padding: const EdgeInsets.all(PlasSpacing.space3),
              decoration: BoxDecoration(
                color: PlasColors.warningBg,
                borderRadius: BorderRadius.circular(PlasRadii.md),
                border: Border.all(color: PlasColors.warningBorder),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Symbols.lock,
                    size: 20,
                    color: PlasColors.warningText,
                  ),
                  const SizedBox(width: PlasSpacing.space2),
                  Expanded(
                    child: Text(
                      plasErrorMessage(ApiErrorCodes.classLocked),
                      style: PlasTypography.body.copyWith(
                        color: PlasColors.warningText,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: PlasSpacing.space4),
            TextField(
              key: const ValueKey('profile_class_code_field'),
              controller: lockedCodeController,
              enabled: false,
              style: PlasTypography.code.copyWith(
                color: PlasColors.disabledText,
              ),
              decoration: InputDecoration(
                labelText: 'Kode Kelas',
                labelStyle: PlasTypography.body.copyWith(
                  color: PlasColors.disabledText,
                ),
                filled: true,
                fillColor: PlasColors.disabledBg,
                prefixIcon: const Icon(
                  Symbols.lock,
                  size: 20,
                  color: PlasColors.disabledText,
                ),
                disabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(PlasRadii.md),
                  borderSide: const BorderSide(
                    color: PlasColors.disabledBorder,
                  ),
                ),
              ),
            ),
            if (classActionSuccess != null) ...[
              const SizedBox(height: PlasSpacing.space4),
              _ClassSuccessBanner(message: classActionSuccess!),
            ],
            if (classActionError != null) ...[
              const SizedBox(height: PlasSpacing.space4),
              PlasErrorView(
                key: const ValueKey('profile_class_error_banner'),
                message: classActionError!,
              ),
            ],
            const SizedBox(height: PlasSpacing.space4),
            ElevatedButton(
              key: const ValueKey('profile_save_class_button'),
              style: _classSaveButtonStyle(),
              onPressed: null,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Symbols.lock, size: 18),
                  SizedBox(width: PlasSpacing.space2),
                  Flexible(
                    child: Text(
                      'Simpan Kelas (Terkunci)',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            TextField(
              key: const ValueKey('profile_class_code_field'),
              controller: codeController,
              enabled: !isBusy,
              style: PlasTypography.code.copyWith(
                color: PlasColors.textPrimary,
              ),
              textCapitalization: TextCapitalization.characters,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: 'Kode Kelas',
                hintText: 'Contoh: TI-2A-2026',
                prefixIcon: const Icon(Symbols.key, size: 20),
                suffixIcon: codeController.text.isEmpty
                    ? null
                    : IconButton(
                        constraints: const BoxConstraints(
                          minWidth: 48,
                          minHeight: 48,
                        ),
                        tooltip: 'Hapus kode kelas',
                        onPressed: isBusy ? null : onClearCode,
                        icon: const Icon(Symbols.close, size: 20),
                      ),
              ),
              onChanged: (_) => onCodeChanged(),
            ),
            const SizedBox(height: PlasSpacing.space4),
            classesAsync.when(
              loading: () => const PlasLoadingSkeleton(
                message: 'Memuat daftar kelas tersedia...',
                cardCount: 2,
              ),
              error: (error, _) => PlasErrorView(
                title: 'Gagal Memuat Daftar Kelas',
                message: _errorMessage(error),
                onRetry: onRetryClasses,
              ),
              data: (classes) => _ProfileClassLookup(
                classes: classes,
                query: codeController.text.trim().toUpperCase(),
                matchedClass: matchedClass,
                enabled: !isBusy,
                onPickClass: onPickClass,
              ),
            ),
            if (classActionSuccess != null) ...[
              const SizedBox(height: PlasSpacing.space4),
              _ClassSuccessBanner(message: classActionSuccess!),
            ],
            if (classActionError != null) ...[
              const SizedBox(height: PlasSpacing.space4),
              PlasErrorView(
                key: const ValueKey('profile_class_error_banner'),
                message: classActionError!,
              ),
            ],
            const SizedBox(height: PlasSpacing.space4),
            ElevatedButton(
              key: const ValueKey('profile_save_class_button'),
              style: _classSaveButtonStyle(),
              onPressed: onSaveClass,
              child: Text(
                isBusy ? 'Menyimpan Kelas...' : 'Simpan Kelas',
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ClassSuccessBanner extends StatelessWidget {
  const _ClassSuccessBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('profile_class_success_banner'),
      padding: const EdgeInsets.all(PlasSpacing.space3),
      decoration: BoxDecoration(
        color: PlasColors.successBg,
        borderRadius: BorderRadius.circular(PlasRadii.md),
        border: Border.all(color: PlasColors.successBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Symbols.check_circle,
            size: 20,
            color: PlasColors.successText,
          ),
          const SizedBox(width: PlasSpacing.space2),
          Expanded(
            child: Text(
              message,
              style: PlasTypography.body.copyWith(
                color: PlasColors.successText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CurrentClassCard extends StatelessWidget {
  const _CurrentClassCard({
    required this.kelas,
    required this.preTestSubmitted,
  });

  final ClassInfoDto? kelas;
  final bool preTestSubmitted;

  @override
  Widget build(BuildContext context) {
    final current = kelas;
    if (current == null) {
      return Container(
        key: const ValueKey('profile_current_class_card'),
        padding: const EdgeInsets.all(PlasSpacing.space3),
        decoration: BoxDecoration(
          color: PlasColors.bgSubtle,
          borderRadius: BorderRadius.circular(PlasRadii.md),
          border: Border.all(color: PlasColors.borderDivider),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Symbols.person,
              size: 20,
              color: PlasColors.textMuted,
            ),
            const SizedBox(width: PlasSpacing.space2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Belum tergabung kelas (Pengguna Umum)',
                    style: PlasTypography.body,
                  ),
                  if (preTestSubmitted) ...[
                    const SizedBox(height: PlasSpacing.space1),
                    Text(
                      'Anda tetap dapat bergabung ke kelas baru dengan Kode Kelas. Riwayat Pre-Test, Post-Test, dan latihan Anda akan otomatis tersinkron ke kelas baru.',
                      key: const ValueKey('profile_rejoin_class_note'),
                      style: PlasTypography.caption.copyWith(
                        color: PlasColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    }

    final lecturer = current.dosenNama?.trim();

    return Container(
      key: const ValueKey('profile_current_class_card'),
      padding: const EdgeInsets.all(PlasSpacing.space4),
      decoration: BoxDecoration(
        color: PlasColors.bgSubtle,
        borderRadius: BorderRadius.circular(PlasRadii.md),
        border: Border.all(color: PlasColors.borderDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: PlasSpacing.space2,
            runSpacing: PlasSpacing.space2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const PlasStatusBadge(
                label: 'Kelas Saat Ini',
                variant: PlasBadgeVariant.brand,
                icon: Symbols.school,
              ),
              Text(current.kode, style: PlasTypography.codeMeta),
            ],
          ),
          const SizedBox(height: PlasSpacing.space3),
          const Text('Nama Kelas', style: PlasTypography.caption),
          const SizedBox(height: PlasSpacing.space1),
          Text(current.nama, style: PlasTypography.title),
          const SizedBox(height: PlasSpacing.space2),
          const Text('Kode', style: PlasTypography.caption),
          const SizedBox(height: PlasSpacing.space1),
          Text(current.kode, style: PlasTypography.codeMeta),
          const SizedBox(height: PlasSpacing.space2),
          const Text('Tahun Akademik / Semester', style: PlasTypography.caption),
          const SizedBox(height: PlasSpacing.space1),
          Text(
            '${current.tahunAkademik} / Semester ${current.semester}',
            style: PlasTypography.body,
          ),
          const SizedBox(height: PlasSpacing.space2),
          const Text('Dosen Pengampu', style: PlasTypography.caption),
          const SizedBox(height: PlasSpacing.space1),
          Text(
            (lecturer != null && lecturer.isNotEmpty)
                ? lecturer
                : 'Belum ditentukan',
            style: PlasTypography.body,
          ),
        ],
      ),
    );
  }
}

class _ProfileClassLookup extends StatelessWidget {
  const _ProfileClassLookup({
    required this.classes,
    required this.query,
    required this.matchedClass,
    required this.enabled,
    required this.onPickClass,
  });

  final List<ClassInfoDto> classes;
  final String query;
  final ClassInfoDto? matchedClass;
  final bool enabled;
  final ValueChanged<ClassInfoDto> onPickClass;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (matchedClass != null) ...[
          _MatchedClassPreviewCard(
            key: const ValueKey('profile_class_preview_card'),
            classInfo: matchedClass!,
          ),
          const SizedBox(height: PlasSpacing.space4),
        ] else if (query.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(PlasSpacing.space3),
            decoration: BoxDecoration(
              color: PlasColors.warningBg,
              borderRadius: BorderRadius.circular(PlasRadii.md),
              border: Border.all(color: PlasColors.warningBorder),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Symbols.info,
                  size: 20,
                  color: PlasColors.warningText,
                ),
                const SizedBox(width: PlasSpacing.space2),
                Expanded(
                  child: Text(
                    'Kode kelas "$query" tidak ditemukan. Periksa kembali kode dari dosen atau pilih kode kelas di bawah.',
                    style: PlasTypography.body.copyWith(
                      color: PlasColors.warningText,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: PlasSpacing.space4),
        ],
        if (classes.isEmpty)
          Container(
            padding: const EdgeInsets.all(PlasSpacing.space3),
            decoration: BoxDecoration(
              color: PlasColors.bgSubtle,
              borderRadius: BorderRadius.circular(PlasRadii.md),
              border: Border.all(color: PlasColors.borderSubtle),
            ),
            child: const Text(
              'Belum ada daftar kelas tersedia saat ini.',
              style: PlasTypography.body,
            ),
          )
        else ...[
          const Text(
            'Pilih Cepat Kode Kelas',
            style: PlasTypography.label,
          ),
          const SizedBox(height: PlasSpacing.space2),
          Wrap(
            spacing: PlasSpacing.space2,
            runSpacing: PlasSpacing.space2,
            children: [
              for (final item in classes)
                _ProfileQuickPickChip(
                  key: ValueKey('profile_class_quick_pick_${item.kelasId}'),
                  kode: item.kode,
                  selected: matchedClass?.kelasId == item.kelasId,
                  enabled: enabled,
                  onTap: () => onPickClass(item),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _MatchedClassPreviewCard extends StatelessWidget {
  const _MatchedClassPreviewCard({super.key, required this.classInfo});

  final ClassInfoDto classInfo;

  @override
  Widget build(BuildContext context) {
    final lecturer = classInfo.dosenNama?.trim();

    return Container(
      padding: const EdgeInsets.all(PlasSpacing.space4),
      decoration: BoxDecoration(
        color: PlasColors.successBg,
        borderRadius: BorderRadius.circular(PlasRadii.lg),
        border: Border.all(color: PlasColors.successBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: PlasSpacing.space2,
            runSpacing: PlasSpacing.space2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const PlasStatusBadge(
                label: 'Pratinjau Kelas',
                variant: PlasBadgeVariant.success,
                icon: Symbols.check_circle,
              ),
              Text(
                classInfo.kode,
                style: PlasTypography.codeMeta.copyWith(
                  color: PlasColors.successText,
                ),
              ),
            ],
          ),
          const SizedBox(height: PlasSpacing.space3),
          Text(
            classInfo.nama,
            style: PlasTypography.title.copyWith(color: PlasColors.textPrimary),
          ),
          const SizedBox(height: PlasSpacing.space1),
          Text(
            '${classInfo.tahunAkademik} / Semester ${classInfo.semester}',
            style: PlasTypography.body,
          ),
          if (lecturer != null && lecturer.isNotEmpty) ...[
            const SizedBox(height: PlasSpacing.space2),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Symbols.person,
                  size: 16,
                  color: PlasColors.successText,
                ),
                const SizedBox(width: PlasSpacing.space1),
                Expanded(
                  child: Text(
                    lecturer,
                    style: PlasTypography.body.copyWith(
                      color: PlasColors.successText,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ProfileQuickPickChip extends StatelessWidget {
  const _ProfileQuickPickChip({
    super.key,
    required this.kode,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String kode;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? PlasColors.brandTint : PlasColors.bgSurface,
      borderRadius: BorderRadius.circular(PlasRadii.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(PlasRadii.md),
        onTap: enabled ? onTap : null,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: PlasSpacing.space3,
              vertical: PlasSpacing.space3,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(PlasRadii.md),
              border: Border.all(
                color: selected
                    ? PlasColors.brandPrimary
                    : PlasColors.borderInteractive,
                width: selected ? 2 : 1,
              ),
            ),
            child: Center(
              widthFactor: 1.0,
              heightFactor: 1.0,
              child: Text(
                kode,
                style: PlasTypography.codeMeta.copyWith(
                  color: selected
                      ? PlasColors.brandPrimary
                      : PlasColors.textPrimary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

ButtonStyle _classSaveButtonStyle() {
  return ButtonStyle(
    minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
    padding: const WidgetStatePropertyAll(
      EdgeInsets.symmetric(
        horizontal: PlasSpacing.space4,
        vertical: PlasSpacing.space3,
      ),
    ),
    shape: WidgetStatePropertyAll(
      RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(PlasRadii.md),
      ),
    ),
    textStyle: const WidgetStatePropertyAll(PlasTypography.label),
    elevation: const WidgetStatePropertyAll(0),
    backgroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) {
        return PlasColors.disabledBg;
      }
      if (states.contains(WidgetState.pressed) ||
          states.contains(WidgetState.hovered)) {
        return PlasColors.brandHover;
      }
      return PlasColors.brandPrimary;
    }),
    foregroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) {
        return PlasColors.disabledText;
      }
      return Colors.white;
    }),
    iconColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) {
        return PlasColors.disabledText;
      }
      return Colors.white;
    }),
    side: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.focused)) {
        return const BorderSide(color: PlasColors.focusLight, width: 2);
      }
      return BorderSide.none;
    }),
  );
}

ButtonStyle _logoutButtonStyle() {
  return ButtonStyle(
    minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
    padding: const WidgetStatePropertyAll(
      EdgeInsets.symmetric(
        horizontal: PlasSpacing.space4,
        vertical: PlasSpacing.space3,
      ),
    ),
    shape: WidgetStatePropertyAll(
      RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(PlasRadii.md),
      ),
    ),
    textStyle: const WidgetStatePropertyAll(PlasTypography.label),
    foregroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) {
        return PlasColors.disabledText;
      }
      return PlasColors.errorText;
    }),
    iconColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) {
        return PlasColors.disabledText;
      }
      return PlasColors.errorText;
    }),
    backgroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) {
        return PlasColors.disabledBg;
      }
      if (states.contains(WidgetState.pressed) ||
          states.contains(WidgetState.hovered)) {
        return PlasColors.errorBg;
      }
      return PlasColors.bgSurface;
    }),
    side: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) {
        return const BorderSide(color: PlasColors.disabledBorder);
      }
      if (states.contains(WidgetState.focused)) {
        return const BorderSide(color: PlasColors.focusLight, width: 2);
      }
      return const BorderSide(color: PlasColors.errorBorder);
    }),
  );
}

String _computeInitials(String? fullName) {
  final trimmed = fullName?.trim() ?? '';
  if (trimmed.isEmpty) return 'M';
  final parts =
      trimmed.split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();
  if (parts.length == 1) {
    return parts.first.substring(0, 1).toUpperCase();
  }
  return '${parts.first.substring(0, 1)}${parts[1].substring(0, 1)}'
      .toUpperCase();
}

String _errorMessage(Object error) {
  if (error is PlasApiException) {
    return error.message;
  }
  return plasErrorMessage(ApiErrorCodes.serverError, fallback: error.toString());
}
