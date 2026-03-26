import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../core/theme.dart';
import '../../services/auth_service.dart';
import '../../widgets/progress/progress_section_card.dart';
import 'reset_password_screen.dart';

enum _AuthMode { login, register }

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _auth = AuthService();

  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _pass2Ctrl = TextEditingController();

  _AuthMode _mode = _AuthMode.login;
  bool _busy = false;
  bool _obscurePassword = true;
  bool _obscurePasswordRepeat = true;

  _AuthModeMeta get _modeMeta {
    switch (_mode) {
      case _AuthMode.login:
        return const _AuthModeMeta(
          eyebrow: 'Sincroniza tu progreso',
          title: 'Vuelve a tu plan sin fricción.',
          subtitle:
              'Entra para recuperar tu progreso, tus rutinas y toda la configuración que ya dejaste afinada.',
          buttonLabel: 'Entrar',
        );
      case _AuthMode.register:
        return const _AuthModeMeta(
          eyebrow: 'Primer acceso',
          title: 'Crea tu cuenta y empieza con buen pie.',
          subtitle:
              'Regístrate y deja listo el acceso para que luego el onboarding se sienta rápido, claro y bien cuidado.',
          buttonLabel: 'Crear cuenta',
        );
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _pass2Ctrl.dispose();
    super.dispose();
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _friendlyError(Object e) {
    if (e is AuthCancelledException) return 'Acceso cancelado.';
    if (e is AuthLinkRequiredException) {
      return 'Tu email ya existe con contraseña. Vincula Google iniciando sesión.';
    }
    if (e is AuthGoogleConfigurationException) {
      return 'Google Sign-In no está configurado (SHA-1/SHA-256 y google-services.json).';
    }
    if (e is AuthGoogleTransientException) {
      return 'No se pudo contactar con Google. Revisa tu conexión e inténtalo de nuevo.';
    }
    if (e is AuthPasskeyException) {
      return 'Tu passkey falló en este dispositivo/emulador. Usa contraseña o prueba en un móvil real.';
    }

    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'operation-not-allowed':
          return 'El acceso con Google no está habilitado en Firebase Auth (Métodos de acceso).';
        case 'user-disabled':
          return 'Esta cuenta está deshabilitada.';
        case 'wrong-password':
        case 'invalid-credential':
          return 'Credenciales incorrectas.';
        case 'user-not-found':
          return 'No existe una cuenta con ese email.';
        case 'email-already-in-use':
          return 'Ese email ya está registrado.';
        case 'weak-password':
          return 'La contraseña es demasiado débil.';
        case 'invalid-email':
          return 'Email no válido.';
        case 'network-request-failed':
          return 'Sin conexión. Verifica internet e inténtalo otra vez.';
        case 'too-many-requests':
          return 'Demasiados intentos. Espera un momento y vuelve a intentarlo.';
      }
    }

    if (e is PlatformException) {
      final s = '${e.code} ${e.message ?? ''}'.toLowerCase();
      if (s.contains('apiexception: 10') ||
          s.contains('developer_error') ||
          s.contains('12500')) {
        return 'Google Sign-In no está configurado (SHA-1/SHA-256 y google-services.json).';
      }
      if (s.contains('network') ||
          s.contains('timeout') ||
          s.contains('network_error')) {
        return 'Error de red con Google. Inténtalo de nuevo.';
      }
      if (s.contains('canceled') ||
          s.contains('cancelled') ||
          s.contains('12501')) {
        return 'Acceso cancelado.';
      }
      if (s.contains('passkey') ||
          s.contains('webauthn') ||
          s.contains('publickeycredential')) {
        return 'Tu passkey falló en este dispositivo/emulador. Usa contraseña o prueba en un móvil real.';
      }
      if (s.contains('sign_in_failed') || s.contains('apiexception')) {
        return 'No se pudo iniciar sesión con Google. Revisa Google Play Services y la configuración (SHA-1/SHA-256 en Firebase).';
      }
    }

    final raw = e.toString().toLowerCase();
    if (raw.contains('apiexception: 10') ||
        raw.contains('developer_error') ||
        raw.contains('12500')) {
      return 'Google Sign-In no está configurado (SHA-1/SHA-256 y google-services.json).';
    }
    if (raw.contains('network_error') ||
        raw.contains('network request failed') ||
        raw.contains('timeout')) {
      return 'Error de red. Inténtalo de nuevo en unos segundos.';
    }
    if (raw.contains('passkey') ||
        raw.contains('webauthn') ||
        raw.contains('publickeycredential')) {
      return 'Tu passkey falló en este dispositivo/emulador. Usa contraseña o prueba en un móvil real.';
    }

    if (raw.contains('sign_in_failed') ||
        raw.contains('google') ||
        raw.contains('apiexception')) {
      return 'No se pudo iniciar sesión con Google. Revisa Google Play Services y la configuración (SHA-1/SHA-256 en Firebase).';
    }

    if (kDebugMode) {
      return 'Error: ${e.toString()}';
    }

    return 'Ha ocurrido un error. Inténtalo de nuevo.';
  }

  Future<void> _submit() async {
    if (_busy) return;

    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;
    final pass2 = _pass2Ctrl.text;

    if (email.isEmpty || !email.contains('@')) {
      _toast('Introduce un email válido.');
      return;
    }
    if (pass.length < 6) {
      _toast('La contraseña debe tener al menos 6 caracteres.');
      return;
    }
    if (_mode == _AuthMode.register && pass != pass2) {
      _toast('Las contraseñas no coinciden.');
      return;
    }

    setState(() => _busy = true);
    try {
      if (_mode == _AuthMode.login) {
        await _auth.signInWithEmailPassword(email: email, password: pass);
      } else {
        await _auth.registerWithEmailPassword(email: email, password: pass);
      }
    } catch (e) {
      _toast(_friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _google() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _auth.signInWithGoogle();
    } on AuthLinkRequiredException catch (e) {
      if (!mounted) return;
      final password = await _promptPasswordForLink(email: e.email);
      if (password == null || password.trim().isEmpty) {
        _toast('Vinculación cancelada.');
        return;
      }

      try {
        await _auth.signInWithPasswordForLink(
          email: e.email,
          password: password,
        );
        await _auth.linkWithCredential(e.pendingCredential);
        _toast('Cuenta vinculada con Google.');
      } catch (err) {
        _toast(_friendlyError(err));
      }
    } catch (e) {
      _toast(_friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _promptPasswordForLink({required String email}) {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Vincular Google'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'El email $email ya tiene contraseña. Inicia sesión para vincular Google.',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Contraseña'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(ctrl.text),
              child: const Text('Vincular'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _forgotPassword() async {
    if (_busy) return;
    final email = _emailCtrl.text.trim();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            ResetPasswordScreen(initialEmail: email.isEmpty ? null : email),
      ),
    );
  }

  InputDecoration _fieldDecoration(
    String label, {
    IconData? icon,
    String? hintText,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hintText,
      prefixIcon: icon == null ? null : Icon(icon),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: context.cfSoftSurface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(18)),
        borderSide: BorderSide(color: context.cfBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(18)),
        borderSide: BorderSide(color: context.cfBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(18)),
        borderSide: BorderSide(color: context.cfPrimary, width: 1.4),
      ),
    );
  }

  Widget _buildHeroCard(BuildContext context) {
    final meta = _modeMeta;
    final colors = _mode == _AuthMode.login
        ? const <Color>[Color(0xFF173255), Color(0xFF426C8E)]
        : const <Color>[Color(0xFF234A4E), Color(0xFF4C7E76)];

    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.all(Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: colors.first.withValues(alpha: 0.22),
            blurRadius: 26,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: const BorderRadius.all(Radius.circular(999)),
                ),
                child: const Text(
                  'CotidyFit',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const Spacer(),
              if (_busy)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: const BorderRadius.all(Radius.circular(999)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Procesando',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: Column(
              key: ValueKey(_mode),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  meta.eyebrow,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.86),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  meta.title,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    height: 1.08,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  meta.subtitle,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.white.withValues(alpha: 0.92),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              _AuthInfoPill(
                icon: Icons.cloud_done_outlined,
                label: 'Sincronizado',
              ),
              _AuthInfoPill(icon: Icons.lock_outline, label: 'Seguro'),
              _AuthInfoPill(icon: Icons.flash_on_outlined, label: 'Rápido'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModeToggle(BuildContext context) {
    Widget modeButton(_AuthMode mode, String label, IconData icon) {
      final selected = _mode == mode;
      return Expanded(
        child: InkWell(
          onTap: _busy ? null : () => setState(() => _mode = mode),
          borderRadius: const BorderRadius.all(Radius.circular(16)),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: selected ? context.cfPrimary : Colors.transparent,
              borderRadius: const BorderRadius.all(Radius.circular(16)),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: context.cfPrimary.withValues(alpha: 0.18),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : const [],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: selected ? Colors.white : context.cfTextSecondary,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: selected ? Colors.white : context.cfTextSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.cfSoftSurface,
        borderRadius: const BorderRadius.all(Radius.circular(20)),
        border: Border.all(color: context.cfBorder),
      ),
      child: Row(
        children: [
          modeButton(_AuthMode.login, 'Entrar', Icons.login_rounded),
          const SizedBox(width: 6),
          modeButton(_AuthMode.register, 'Registro', Icons.person_add_alt_1),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final meta = _modeMeta;
    final backgroundGradient = [context.cfBackground, context.cfSoftSurface];

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: backgroundGradient,
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            children: [
              _buildHeroCard(context),
              const SizedBox(height: 16),
              ProgressSectionCard(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildModeToggle(context),
                    const SizedBox(height: 18),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: Column(
                        key: ValueKey(_mode),
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _mode == _AuthMode.login
                                ? 'Accede a tu cuenta'
                                : 'Prepara tu cuenta',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _mode == _AuthMode.login
                                ? 'Todo tu historial y tu configuración volverán contigo al entrar.'
                                : 'Después del registro pasarás a las preguntas iniciales con un flujo ya más pulido.',
                            style: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.copyWith(height: 1.35),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      enabled: !_busy,
                      decoration: _fieldDecoration(
                        'Email',
                        icon: Icons.alternate_email,
                        hintText: 'tu@email.com',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _passCtrl,
                      obscureText: _obscurePassword,
                      textInputAction: _mode == _AuthMode.login
                          ? TextInputAction.done
                          : TextInputAction.next,
                      onSubmitted: (_) {
                        if (_mode == _AuthMode.login) _submit();
                      },
                      enabled: !_busy,
                      decoration: _fieldDecoration(
                        'Contraseña',
                        icon: Icons.lock_outline,
                        hintText: 'Mínimo 6 caracteres',
                        suffixIcon: IconButton(
                          onPressed: _busy
                              ? null
                              : () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                                ),
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                        ),
                      ),
                    ),
                    if (_mode == _AuthMode.login) ...[
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _busy ? null : _forgotPassword,
                          child: const Text('¿Olvidaste tu contraseña?'),
                        ),
                      ),
                    ],
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: _mode == _AuthMode.register
                          ? Padding(
                              key: const ValueKey('register-password-repeat'),
                              padding: const EdgeInsets.only(top: 12),
                              child: TextField(
                                controller: _pass2Ctrl,
                                obscureText: _obscurePasswordRepeat,
                                textInputAction: TextInputAction.done,
                                onSubmitted: (_) => _submit(),
                                enabled: !_busy,
                                decoration: _fieldDecoration(
                                  'Repetir contraseña',
                                  icon: Icons.verified_user_outlined,
                                  hintText: 'Repite la contraseña',
                                  suffixIcon: IconButton(
                                    onPressed: _busy
                                        ? null
                                        : () => setState(
                                            () => _obscurePasswordRepeat =
                                                !_obscurePasswordRepeat,
                                          ),
                                    icon: Icon(
                                      _obscurePasswordRepeat
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                    ),
                                  ),
                                ),
                              ),
                            )
                          : const SizedBox.shrink(key: ValueKey('no-repeat')),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _busy ? null : _submit,
                        child: _busy
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(meta.buttonLabel),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _busy ? null : _google,
                        icon: Container(
                          width: 22,
                          height: 22,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: const BorderRadius.all(
                              Radius.circular(999),
                            ),
                            border: Border.all(color: context.cfBorder),
                          ),
                          child: const Text(
                            'G',
                            style: TextStyle(
                              color: Color(0xFF4285F4),
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        label: const Text('Continuar con Google'),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: context.cfPrimaryTint,
                        borderRadius: const BorderRadius.all(
                          Radius.circular(18),
                        ),
                        border: Border.all(
                          color: context.cfPrimaryTintStrong,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.tips_and_updates_outlined,
                            color: context.cfPrimary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _mode == _AuthMode.login
                                  ? 'Entrar te devuelve tu progreso, tus ajustes y tu plan tal como lo dejaste.'
                                  : 'Crear cuenta solo es el primer paso. Después pasarás al onboarding para ajustar objetivo, racha y preferencias.',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: context.cfTextPrimary,
                                    fontWeight: FontWeight.w700,
                                    height: 1.35,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AuthModeMeta {
  const _AuthModeMeta({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final String buttonLabel;
}

class _AuthInfoPill extends StatelessWidget {
  const _AuthInfoPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: const BorderRadius.all(Radius.circular(999)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
