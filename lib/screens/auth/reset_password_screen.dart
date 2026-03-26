import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../services/auth_service.dart';
import '../../widgets/progress/progress_section_card.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key, this.initialEmail});

  final String? initialEmail;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _auth = AuthService();
  late final TextEditingController _emailCtrl;

  bool _busy = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _emailCtrl = TextEditingController(text: widget.initialEmail ?? '');
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  void _setMessage(String msg) {
    setState(() => _message = msg);
  }

  bool _looksLikeEmail(String v) {
    final s = v.trim();
    if (s.isEmpty) return false;
    // Simple, pragmatic check (avoids over-strict regex).
    return s.contains('@') && s.contains('.') && !s.contains(' ');
  }

  Future<void> _send() async {
    if (_busy) return;

    final email = _emailCtrl.text.trim();

    if (email.isEmpty) {
      _setMessage('Introduce tu email.');
      return;
    }

    if (!_looksLikeEmail(email)) {
      _setMessage('Formato de email incorrecto.');
      return;
    }

    setState(() {
      _busy = true;
      _message = null;
    });

    try {
      await _auth.sendPasswordResetEmail(email: email);
      _setMessage('Enlace enviado. Revisa tu bandeja de entrada (y spam).');
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        _setMessage('No existe una cuenta con ese email.');
      } else if (e.code == 'invalid-email') {
        _setMessage('Email no válido.');
      } else if (e.code == 'too-many-requests') {
        _setMessage(
          'Demasiados intentos. Espera unos minutos y vuelve a probar.',
        );
      } else {
        _setMessage('No se pudo enviar el enlace. (${e.code})');
      }
    } catch (_) {
      _setMessage('No se pudo enviar el enlace. Inténtalo de nuevo.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  InputDecoration _fieldDecoration(BuildContext context) {
    return InputDecoration(
      labelText: 'Email',
      hintText: 'tu@email.com',
      prefixIcon: Icon(Icons.alternate_email),
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

  @override
  Widget build(BuildContext context) {
    final msg = _message;
    final backgroundGradient = [context.cfBackground, context.cfSoftSurface];

    return Scaffold(
      appBar: AppBar(title: const Text('Restablecer contraseña')),
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
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: <Color>[Color(0xFF173255), Color(0xFF426C8E)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.all(Radius.circular(28)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF173255).withValues(alpha: 0.20),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: const BorderRadius.all(
                          Radius.circular(999),
                        ),
                      ),
                      child: const Text(
                        'Recupera el acceso',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Te enviamos un enlace para volver a entrar.',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            height: 1.1,
                          ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Escribe tu email y te mandaremos el enlace para crear una nueva contraseña sin salirte del flujo.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.white.withValues(alpha: 0.92),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ProgressSectionCard(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Email de recuperación',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Usa el mismo email con el que creaste la cuenta.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: _fieldDecoration(context),
                      enabled: !_busy,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _busy ? null : _send,
                        child: _busy
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Enviar enlace'),
                      ),
                    ),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: msg == null
                          ? const SizedBox.shrink(
                              key: ValueKey('empty-message'),
                            )
                          : Padding(
                              key: ValueKey(msg),
                              padding: const EdgeInsets.only(top: 14),
                              child: Container(
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
                                child: Text(
                                  msg,
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: context.cfTextPrimary,
                                      ),
                                ),
                              ),
                            ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Nota: la personalización del contenido del email se configura en Firebase Console > Authentication > Templates.',
                      style: Theme.of(context).textTheme.bodySmall,
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
