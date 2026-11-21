import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:plasmobile/core/constants/api_error_codes.dart';
import 'package:plasmobile/core/errors/plas_exception.dart';
import 'package:plasmobile/core/theme/plas_tokens.dart';
import 'package:plasmobile/data/dto/student_profile_dto.dart';
import 'package:plasmobile/features/auth/application/session_controller.dart';
import 'package:plasmobile/features/shared/providers/plas_providers.dart';
import 'package:plasmobile/shared/widgets/plas_state_views.dart';
import 'package:plasmobile/shared/widgets/plas_status_badge.dart';

class OnboardingClassScreen extends ConsumerStatefulWidget {
  const OnboardingClassScreen({super.key});

  @override
  ConsumerState<OnboardingClassScreen> createState() =>
      _OnboardingClassScreenState();
}

class _OnboardingClassScreenState extends ConsumerState<OnboardingClassScreen> {
  final TextEditingController _codeController = TextEditingController();
  String? _actionError;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
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

  Future<void> _joinClass(ClassInfoDto selected) async {
    setState(() {
      _actionError = null;
    });
    try {
      await ref
          .read(sessionControllerProvider.notifier)
          .joinClass(selected.kelasId);
    } on PlasApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _actionError = error.message;
      });
    }
  }

  Future<void> _skipClassOnboarding() async {
    setState(() {
      _actionError = null;
    });
    try {
      await ref
          .read(sessionControllerProvider.notifier)
          .skipClassOnboarding();
    } on PlasApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _actionError = error.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionControllerProvider);
    final classesAsync = ref.watch(classesProvider);
    final isBusy = session.isBusy;

    final matchedClass = classesAsync.maybeWhen(
      data: _findMatchingClass,
      orElse: () => null,
    );

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
                      'CS LAB ENV // KELAS',
                      style: PlasTypography.codeMeta,
                    ),
                    const SizedBox(height: PlasSpacing.space1),
                    const Text(
                      'Gabung Kelas',
                      style: PlasTypography.display,
                    ),
                    const SizedBox(height: PlasSpacing.space2),
                    const Text(
                      'Masukkan kode kelas dari dosen pengampu Anda, atau lewati untuk belajar sebagai pengguna umum.',
                      style: PlasTypography.body,
                    ),
                    const SizedBox(height: PlasSpacing.space5),
                    TextField(
                      key: const ValueKey('class_code_field'),
                      controller: _codeController,
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
                        suffixIcon: _codeController.text.isEmpty
                            ? null
                            : IconButton(
                                constraints: const BoxConstraints(
                                  minWidth: 48,
                                  minHeight: 48,
                                ),
                                tooltip: 'Hapus kode kelas',
                                onPressed: isBusy
                                    ? null
                                    : () {
                                        _codeController.clear();
                                        setState(() {
                                          _actionError = null;
                                        });
                                      },
                                icon: const Icon(Symbols.close, size: 20),
                              ),
                      ),
                      onChanged: (_) {
                        setState(() {
                          _actionError = null;
                        });
                      },
                    ),
                    const SizedBox(height: PlasSpacing.space4),
                    classesAsync.when(
                      loading: () => const PlasLoadingSkeleton(
                        message: 'Memuat daftar kelas tersedia...',
                        cardCount: 2,
                      ),
                      error: (error, _) {
                        final message = error is PlasApiException
                            ? error.message
                            : plasErrorMessage(ApiErrorCodes.serverError);
                        return PlasErrorView(
                          title: 'Gagal Memuat Daftar Kelas',
                          message: message,
                          actionLabel: 'Coba Lagi',
                          onRetry: () => ref.invalidate(classesProvider),
                        );
                      },
                      data: (classes) => _ClassLookupSection(
                        classes: classes,
                        query: _codeController.text.trim().toUpperCase(),
                        matchedClass: matchedClass,
                        enabled: !isBusy,
                        onPickClass: (item) {
                          _codeController.text = item.kode;
                          _codeController.selection = TextSelection.collapsed(
                            offset: item.kode.length,
                          );
                          setState(() {
                            _actionError = null;
                          });
                        },
                      ),
                    ),
                    if (_actionError != null) ...[
                      const SizedBox(height: PlasSpacing.space4),
                      PlasErrorView(
                        message: _actionError!,
                      ),
                    ],
                    const SizedBox(height: PlasSpacing.space5),
                    ElevatedButton(
                      key: const ValueKey('class_join_button'),
                      onPressed: (matchedClass != null && !isBusy)
                          ? () => _joinClass(matchedClass)
                          : null,
                      child: const Text(
                        'Gabung Kelas & Lanjut ->',
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: PlasSpacing.space3),
                    OutlinedButton(
                      key: const ValueKey('class_skip_button'),
                      onPressed: isBusy ? null : _skipClassOnboarding,
                      child: const Text(
                        'Lewati (Pengguna Umum)',
                        textAlign: TextAlign.center,
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

class _ClassLookupSection extends StatelessWidget {
  const _ClassLookupSection({
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
          _ClassPreviewCard(
            key: const ValueKey('class_preview_card'),
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
              'Belum ada kelas terdaftar saat ini. Anda dapat melanjutkan sebagai pengguna umum.',
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
                _QuickPickClassChip(
                  key: ValueKey('class_quick_pick_${item.kelasId}'),
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

class _ClassPreviewCard extends StatelessWidget {
  const _ClassPreviewCard({super.key, required this.classInfo});

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

class _QuickPickClassChip extends StatelessWidget {
  const _QuickPickClassChip({
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
    );
  }
}
