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
      if (s.contains('apiexception: 10') || s.contains('developer_error') || s.contains('12500')) {
        return 'Google Sign-In no está configurado (SHA-1/SHA-256 y google-services.json).';
      }
      if (s.contains('network') || s.contains('timeout') || s.contains('network_error')) {
        return 'Error de red con Google. Inténtalo de nuevo.';
      }
      if (s.contains('canceled') || s.contains('cancelled') || s.contains('12501')) {
        return 'Acceso cancelado.';
      }
      if (s.contains('passkey') || s.contains('webauthn') || s.contains('publickeycredential')) {
        return 'Tu passkey falló en este dispositivo/emulador. Usa contraseña o prueba en un móvil real.';
      }
      if (s.contains('sign_in_failed') || s.contains('apiexception')) {
        return 'No se pudo iniciar sesión con Google. Revisa Google Play Services y la configuración (SHA-1/SHA-256 en Firebase).';
      }
    }

    final raw = e.toString().toLowerCase();
    if (raw.contains('apiexception: 10') || raw.contains('developer_error') || raw.contains('12500')) {
      return 'Google Sign-In no está configurado (SHA-1/SHA-256 y google-services.json).';
    }
    if (raw.contains('network_error') || raw.contains('network request failed') || raw.contains('timeout')) {
      return 'Error de red. Inténtalo de nuevo en unos segundos.';
    }
    if (raw.contains('passkey') || raw.contains('webauthn') || raw.contains('publickeycredential')) {
      return 'Tu passkey falló en este dispositivo/emulador. Usa contraseña o prueba en un móvil real.';
    }

    if (raw.contains('sign_in_failed') || raw.contains('google') || raw.contains('apiexception')) {
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
        await _auth.signInWithPasswordForLink(email: e.email, password: password);
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
              Text('El email $email ya tiene contraseña. Inicia sesión para vincular Google.'),
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
        builder: (_) => ResetPasswordScreen(initialEmail: email.isEmpty ? null : email),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = _mode == _AuthMode.login ? 'Iniciar sesión' : 'Crear cuenta';

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const SizedBox(height: 16),
            Text('CotidyFit', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text('Accede para sincronizar tu progreso.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: CFColors.textSecondary)),
            const SizedBox(height: 18),
            ProgressSectionCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: SegmentedButton<_AuthMode>(
                          segments: const [
                            ButtonSegment(value: _AuthMode.login, label: Text('Login')),
                            ButtonSegment(value: _AuthMode.register, label: Text('Registro')),
                          ],
                          selected: {_mode},
                          onSelectionChanged: (v) => setState(() => _mode = v.first),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _passCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Contraseña'),
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
                  if (_mode == _AuthMode.register) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _pass2Ctrl,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Repetir contraseña'),
                    ),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(_mode == _AuthMode.login ? 'Entrar' : 'Crear cuenta'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : _google,
                      icon: const Icon(Icons.g_mobiledata),
                      label: const Text('Continuar con Google'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
