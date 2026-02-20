import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

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
        _setMessage('Demasiados intentos. Espera unos minutos y vuelve a probar.');
      } else {
        _setMessage('No se pudo enviar el enlace. (${e.code})');
      }
    } catch (_) {
      _setMessage('No se pudo enviar el enlace. Inténtalo de nuevo.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final msg = _message;

    return Scaffold(
      appBar: AppBar(title: const Text('Restablecer contraseña')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            ProgressSectionCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Te enviamos un enlace',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Introduce tu email y recibirás un enlace para crear una nueva contraseña.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email'),
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
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Enviar enlace'),
                    ),
                  ),
                  if (msg != null) ...[
                    const SizedBox(height: 12),
                    Text(msg),
                  ],
                  const SizedBox(height: 8),
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
    );
  }
}
