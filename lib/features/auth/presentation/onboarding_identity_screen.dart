import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:plasmobile/core/constants/api_error_codes.dart';
import 'package:plasmobile/core/errors/plas_exception.dart';
import 'package:plasmobile/core/theme/plas_tokens.dart';
import 'package:plasmobile/features/auth/application/session_controller.dart';
import 'package:plasmobile/shared/widgets/plas_status_badge.dart';

class OnboardingIdentityScreen extends ConsumerStatefulWidget {
  const OnboardingIdentityScreen({super.key});

  @override
  ConsumerState<OnboardingIdentityScreen> createState() =>
      _OnboardingIdentityScreenState();
}

class _OnboardingIdentityScreenState
    extends ConsumerState<OnboardingIdentityScreen> {
  final TextEditingController _namaController = TextEditingController();
  final TextEditingController _nimController = TextEditingController();

  String? _namaError;
  String? _nimError;
  String? _identityError;

  @override
  void dispose() {
    _namaController.dispose();
    _nimController.dispose();
    super.dispose();
  }

  bool get _isNamaValid {
    final trimmed = _namaController.text.trim();
    return trimmed.isNotEmpty && trimmed.length <= 100;
  }

  bool get _isNimValid {
    final trimmed = _nimController.text.trim();
    return trimmed.isNotEmpty && trimmed.length <= 30;
  }

  Future<void> _submit() async {
    final nama = _namaController.text.trim();
    final nim = _nimController.text.trim();

    String? nextNamaError;
    String? nextNimError;
    if (nama.isEmpty) {
      nextNamaError = 'Nama lengkap wajib diisi.';
    } else if (nama.length > 100) {
      nextNamaError = 'Nama lengkap maksimal 100 karakter.';
    }

    if (nim.isEmpty) {
      nextNimError = 'NIM wajib diisi.';
    } else if (nim.length > 30) {
      nextNimError = 'NIM maksimal 30 karakter.';
    }

    if (nextNamaError != null || nextNimError != null) {
      setState(() {
        _namaError = nextNamaError;
        _nimError = nextNimError;
        _identityError = null;
      });
      return;
    }

    setState(() {
      _namaError = null;
      _nimError = null;
      _identityError = null;
    });

    try {
      await ref
          .read(sessionControllerProvider.notifier)
          .completeIdentity(nama: nama, nim: nim);
    } on PlasApiException catch (error) {
      if (!mounted) return;
      setState(() {
        if (error.code == ApiErrorCodes.nimConflict) {
          _nimError = error.message;
        } else {
          _identityError = error.message;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionControllerProvider);
    final isBusy = session.isBusy;
    final userEmail = session.authUser?.email.trim() ?? '';

    return Scaffold(
      backgroundColor: PlasColors.bgCanvas,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(PlasSpacing.space4),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Container(
                padding: const EdgeInsets.all(PlasSpacing.space5),
                decoration: BoxDecoration(
                  color: PlasColors.bgSurface,
                  borderRadius: BorderRadius.circular(PlasRadii.lg),
                  border: Border.all(color: PlasColors.borderDivider),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'CS LAB ENV // AUTH',
                      style: PlasTypography.codeMeta,
                    ),
                    const SizedBox(height: PlasSpacing.space1),
                    const Text(
                      'Identitas Mahasiswa',
                      style: PlasTypography.display,
                    ),
                    const SizedBox(height: PlasSpacing.space2),
                    const Text(
                      'Lengkapi nama lengkap dan NIM Anda sebelum memilih kelas pembelajaran.',
                      style: PlasTypography.body,
                    ),
                    if (userEmail.isNotEmpty) ...[
                      const SizedBox(height: PlasSpacing.space3),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: PlasSpacing.space3,
                          vertical: PlasSpacing.space2,
                        ),
                        decoration: BoxDecoration(
                          color: PlasColors.bgSubtle,
                          borderRadius: BorderRadius.circular(PlasRadii.md),
                          border: Border.all(color: PlasColors.borderSubtle),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Symbols.mail,
                              size: 16,
                              color: PlasColors.textMuted,
                            ),
                            const SizedBox(width: PlasSpacing.space2),
                            Expanded(
                              child: Text(
                                userEmail,
                                style: PlasTypography.caption,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: PlasSpacing.space5),
                    TextField(
                      key: const ValueKey('identity_nama_field'),
                      controller: _namaController,
                      enabled: !isBusy,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Nama Lengkap',
                        hintText: 'Contoh: Andi Fajar',
                        prefixIcon: Icon(Symbols.badge, size: 20),
                      ),
                      onChanged: (_) {
                        setState(() {
                          _namaError = null;
                          _identityError = null;
                        });
                      },
                    ),
                    if (_namaError != null) ...[
                      const SizedBox(height: PlasSpacing.space2),
                      _InlineFieldError(
                        key: const ValueKey('identity_nama_error'),
                        message: _namaError!,
                      ),
                    ] else if (_isNamaValid) ...[
                      const SizedBox(height: PlasSpacing.space2),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: PlasStatusBadge(
                          label: 'Valid',
                          variant: PlasBadgeVariant.success,
                          icon: Symbols.check_circle,
                        ),
                      ),
                    ],
                    const SizedBox(height: PlasSpacing.space4),
                    TextField(
                      key: const ValueKey('identity_nim_field'),
                      controller: _nimController,
                      enabled: !isBusy,
                      style: PlasTypography.code.copyWith(
                        color: PlasColors.textPrimary,
                      ),
                      maxLength: 30,
                      buildCounter: (
                        _, {
                        required currentLength,
                        required isFocused,
                        maxLength,
                      }) =>
                          null,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) {
                        if (!isBusy) _submit();
                      },
                      decoration: const InputDecoration(
                        labelText: 'NIM',
                        hintText: 'Contoh: 2415091001',
                        helperText: 'Maksimal 30 karakter sesuai data akademik.',
                        prefixIcon: Icon(Symbols.id_card, size: 20),
                      ),
                      onChanged: (_) {
                        setState(() {
                          _nimError = null;
                          _identityError = null;
                        });
                      },
                    ),
                    if (_nimError != null) ...[
                      const SizedBox(height: PlasSpacing.space2),
                      _InlineFieldError(
                        key: const ValueKey('identity_nim_error'),
                        message: _nimError!,
                      ),
                    ] else if (_isNimValid && _identityError == null) ...[
                      const SizedBox(height: PlasSpacing.space2),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: PlasStatusBadge(
                          label: 'Valid',
                          variant: PlasBadgeVariant.success,
                          icon: Symbols.check_circle,
                        ),
                      ),
                    ],
                    if (_identityError != null) ...[
                      const SizedBox(height: PlasSpacing.space3),
                      _InlineFieldError(
                        key: const ValueKey('identity_general_error'),
                        message: _identityError!,
                      ),
                    ],
                    const SizedBox(height: PlasSpacing.space5),
                    ElevatedButton(
                      key: const ValueKey('identity_submit_button'),
                      onPressed: isBusy ? null : _submit,
                      child: const Text(
                        'Simpan & Lanjut ->',
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: PlasSpacing.space3),
                    OutlinedButton(
                      key: const ValueKey('identity_logout_button'),
                      onPressed: isBusy
                          ? null
                          : () => ref
                              .read(sessionControllerProvider.notifier)
                              .signOut(),
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

class _InlineFieldError extends StatelessWidget {
  const _InlineFieldError({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(PlasSpacing.space3),
      decoration: BoxDecoration(
        color: PlasColors.errorBg,
        borderRadius: BorderRadius.circular(PlasRadii.md),
        border: Border.all(color: PlasColors.errorBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Symbols.error,
            size: 20,
            color: PlasColors.errorText,
          ),
          const SizedBox(width: PlasSpacing.space2),
          Expanded(
            child: Text(
              message,
              style: PlasTypography.body.copyWith(color: PlasColors.errorText),
            ),
          ),
        ],
      ),
    );
  }
}
