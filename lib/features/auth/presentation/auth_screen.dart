import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:plasmobile/core/errors/plas_exception.dart';
import 'package:plasmobile/core/theme/plas_tokens.dart';
import 'package:plasmobile/features/auth/application/session_controller.dart';
import 'package:plasmobile/shared/widgets/owl_bracket_mascot.dart';

enum _AuthMode { login, register }

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _displayNameController = TextEditingController();

  _AuthMode _mode = _AuthMode.login;
  bool _obscurePassword = true;
  String? _inlineError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  void _switchMode(_AuthMode nextMode) {
    if (_mode == nextMode) return;
    setState(() {
      _mode = nextMode;
      _inlineError = null;
    });
  }

  String _formatAuthError(PlasApiException error) {
    const knownAuthMessages = <String>{
      'Format email tidak valid.',
      'Password minimal 6 karakter.',
      'Login Google dibatalkan.',
      'Pendaftaran berhasil, tetapi sesi aktif belum tersedia.',
    };
    final serverMessage = error.serverMessage?.trim();
    if (serverMessage != null && knownAuthMessages.contains(serverMessage)) {
      return serverMessage;
    }
    return error.message;
  }

  Future<void> _submitEmailAuth() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _inlineError = 'Email dan kata sandi wajib diisi.';
      });
      return;
    }

    setState(() {
      _inlineError = null;
    });

    final controller = ref.read(sessionControllerProvider.notifier);
    try {
      if (_mode == _AuthMode.login) {
        await controller.signInWithEmail(email: email, password: password);
      } else {
        final displayName = _displayNameController.text.trim();
        await controller.signUpWithEmail(
          email: email,
          password: password,
          displayName: displayName.isEmpty ? null : displayName,
        );
      }
    } on PlasApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _inlineError = _formatAuthError(error);
      });
    }
  }

  Future<void> _submitGoogleAuth() async {
    setState(() {
      _inlineError = null;
    });

    try {
      await ref.read(sessionControllerProvider.notifier).signInWithGoogle();
    } on PlasApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _inlineError = _formatAuthError(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionControllerProvider);
    final isBusy = session.isBusy;
    final isRegister = _mode == _AuthMode.register;

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
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const PlasAppLogo(
                          size: 48,
                          semanticLabel: 'Logo PLAS-TypeScript',
                        ),
                        const SizedBox(width: PlasSpacing.space3),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'CS LAB ENV // AUTH',
                                style: PlasTypography.codeMeta,
                              ),
                              const SizedBox(height: PlasSpacing.space1),
                              Text(
                                isRegister
                                    ? 'Daftar Akun Mahasiswa'
                                    : 'Masuk ke PLAS-TypeScript',
                                style: PlasTypography.heading,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: PlasSpacing.space5),
                    _AuthModeTabBar(
                      mode: _mode,
                      enabled: !isBusy,
                      onChanged: _switchMode,
                    ),
                    const SizedBox(height: PlasSpacing.space4),
                    if (_inlineError != null) ...[
                      _AuthErrorBanner(
                        key: const ValueKey('auth_error_banner'),
                        message: _inlineError!,
                      ),
                      const SizedBox(height: PlasSpacing.space4),
                    ],
                    if (isRegister) ...[
                      TextField(
                        key: const ValueKey('auth_display_name_field'),
                        controller: _displayNameController,
                        enabled: !isBusy,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Nama Panggilan (Opsional)',
                          hintText: 'Contoh: Budi',
                          prefixIcon: Icon(Symbols.person, size: 20),
                        ),
                        onChanged: (_) {
                          if (_inlineError != null) {
                            setState(() => _inlineError = null);
                          }
                        },
                      ),
                      const SizedBox(height: PlasSpacing.space3),
                    ],
                    TextField(
                      key: const ValueKey('auth_email_field'),
                      controller: _emailController,
                      enabled: !isBusy,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        hintText: 'mahasiswa@plas.ac.id',
                        prefixIcon: Icon(Symbols.mail, size: 20),
                      ),
                      onChanged: (_) {
                        if (_inlineError != null) {
                          setState(() => _inlineError = null);
                        }
                      },
                    ),
                    const SizedBox(height: PlasSpacing.space3),
                    TextField(
                      key: const ValueKey('auth_password_field'),
                      controller: _passwordController,
                      enabled: !isBusy,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) {
                        if (!isBusy) _submitEmailAuth();
                      },
                      decoration: InputDecoration(
                        labelText: 'Kata Sandi',
                        hintText: 'Minimal 6 karakter',
                        prefixIcon: const Icon(Symbols.lock, size: 20),
                        suffixIcon: IconButton(
                          key: const ValueKey('auth_toggle_password_visibility'),
                          constraints: const BoxConstraints(
                            minWidth: 48,
                            minHeight: 48,
                          ),
                          tooltip: _obscurePassword
                              ? 'Tampilkan kata sandi'
                              : 'Sembunyikan kata sandi',
                          onPressed: isBusy
                              ? null
                              : () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                          icon: Icon(
                            _obscurePassword
                                ? Symbols.visibility
                                : Symbols.visibility_off,
                            size: 20,
                          ),
                        ),
                      ),
                      onChanged: (_) {
                        if (_inlineError != null) {
                          setState(() => _inlineError = null);
                        }
                      },
                    ),
                    const SizedBox(height: PlasSpacing.space4),
                    ElevatedButton(
                      key: const ValueKey('auth_submit_button'),
                      onPressed: isBusy ? null : _submitEmailAuth,
                      child: Text(
                        isRegister ? 'Buat Akun Mahasiswa' : 'Masuk',
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: PlasSpacing.space4),
                    Row(
                      children: [
                        const Expanded(
                          child: Divider(color: PlasColors.borderSubtle),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: PlasSpacing.space3,
                          ),
                          child: Text(
                            'atau',
                            style: PlasTypography.caption,
                          ),
                        ),
                        const Expanded(
                          child: Divider(color: PlasColors.borderSubtle),
                        ),
                      ],
                    ),
                    const SizedBox(height: PlasSpacing.space4),
                    OutlinedButton(
                      key: const ValueKey('auth_google_button'),
                      onPressed: isBusy ? null : _submitGoogleAuth,
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          PlasGoogleLogo(size: 20),
                          SizedBox(width: PlasSpacing.space3),
                          Flexible(
                            child: Text(
                              'Masuk dengan Google',
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

class _AuthModeTabBar extends StatelessWidget {
  const _AuthModeTabBar({
    required this.mode,
    required this.enabled,
    required this.onChanged,
  });

  final _AuthMode mode;
  final bool enabled;
  final ValueChanged<_AuthMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(PlasSpacing.space1),
      decoration: BoxDecoration(
        color: PlasColors.bgSubtle,
        borderRadius: BorderRadius.circular(PlasRadii.md),
        border: Border.all(color: PlasColors.borderSubtle),
      ),
      child: Row(
        children: [
          Expanded(
            child: _AuthTabItem(
              key: const ValueKey('auth_tab_login'),
              label: 'Masuk',
              selected: mode == _AuthMode.login,
              enabled: enabled,
              onTap: () => onChanged(_AuthMode.login),
            ),
          ),
          const SizedBox(width: PlasSpacing.space1),
          Expanded(
            child: _AuthTabItem(
              key: const ValueKey('auth_tab_register'),
              label: 'Daftar',
              selected: mode == _AuthMode.register,
              enabled: enabled,
              onTap: () => onChanged(_AuthMode.register),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthTabItem extends StatelessWidget {
  const _AuthTabItem({
    super.key,
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      onTap: enabled ? onTap : null,
      child: Material(
        color: selected ? PlasColors.bgSurface : Colors.transparent,
        borderRadius: BorderRadius.circular(PlasRadii.sm),
        child: InkWell(
          borderRadius: BorderRadius.circular(PlasRadii.sm),
          onTap: enabled ? onTap : null,
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(
              horizontal: PlasSpacing.space3,
              vertical: PlasSpacing.space2,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(PlasRadii.sm),
              border: Border.all(
                color: selected ? PlasColors.brandPrimary : Colors.transparent,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: PlasTypography.label.copyWith(
                color: selected
                    ? PlasColors.brandPrimary
                    : PlasColors.textMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthErrorBanner extends StatelessWidget {
  const _AuthErrorBanner({super.key, required this.message});

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
