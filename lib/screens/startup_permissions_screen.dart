import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../services/app_permissions_service.dart';
import '../widgets/progress/progress_section_card.dart';
import 'splash_screen.dart';

class StartupPermissionsPromptGate extends StatefulWidget {
  const StartupPermissionsPromptGate({
    super.key,
    required this.child,
    this.onReady,
    this.permissionsService,
  });

  final Widget child;
  final VoidCallback? onReady;
  final AppPermissionsService? permissionsService;

  @override
  State<StartupPermissionsPromptGate> createState() =>
      _StartupPermissionsPromptGateState();
}

class _StartupPermissionsPromptGateState
    extends State<StartupPermissionsPromptGate> {
  late final AppPermissionsService _permissionsService;
  late final Future<bool> _shouldShowFuture;

  bool _promptResolved = false;
  bool _readyNotified = false;

  @override
  void initState() {
    super.initState();
    _permissionsService = widget.permissionsService ?? AppPermissionsService();
    _shouldShowFuture = _permissionsService.shouldShowStartupPrompt();
  }

  void _handlePromptResolved() {
    if (!mounted) return;
    setState(() => _promptResolved = true);
  }

  void _notifyReadyOnce() {
    if (_readyNotified) return;
    _readyNotified = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onReady?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _shouldShowFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SplashScreen();
        }

        final shouldShow = snapshot.data ?? false;
        if (shouldShow && !_promptResolved) {
          return StartupPermissionsScreen(
            permissionsService: _permissionsService,
            onResolved: _handlePromptResolved,
          );
        }

        _notifyReadyOnce();
        return widget.child;
      },
    );
  }
}

class StartupPermissionsScreen extends StatefulWidget {
  const StartupPermissionsScreen({
    super.key,
    required this.onResolved,
    this.permissionsService,
  });

  final VoidCallback onResolved;
  final AppPermissionsService? permissionsService;

  @override
  State<StartupPermissionsScreen> createState() =>
      _StartupPermissionsScreenState();
}

class _StartupPermissionsScreenState extends State<StartupPermissionsScreen> {
  late final AppPermissionsService _permissionsService;

  AppPermissionsSnapshot? _permissionSnapshot;
  bool _requestingPermissions = false;

  @override
  void initState() {
    super.initState();
    _permissionsService = widget.permissionsService ?? AppPermissionsService();
    _refreshPermissionSnapshot();
  }

  Future<void> _refreshPermissionSnapshot() async {
    final snapshot = await _permissionsService.getSnapshot();
    if (!mounted) return;
    setState(() => _permissionSnapshot = snapshot);
  }

  Future<void> _reviewStartupPermissions() async {
    if (_requestingPermissions) return;

    setState(() => _requestingPermissions = true);
    try {
      final snapshot = await _permissionsService.requestStartupPermissions();
      if (!mounted) return;
      setState(() {
        _permissionSnapshot = snapshot;
        _requestingPermissions = false;
      });
      widget.onResolved();
    } catch (_) {
      await _permissionsService.markStartupPromptHandled();
      if (!mounted) return;
      setState(() => _requestingPermissions = false);
      widget.onResolved();
    }
  }

  Future<void> _skipPermissionsPrompt() async {
    if (_requestingPermissions) return;
    await _permissionsService.markStartupPromptHandled();
    if (!mounted) return;
    widget.onResolved();
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _permissionSnapshot;
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
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ProgressSectionCard(
                  padding: const EdgeInsets.all(20),
                  backgroundColor: context.cfPrimaryTint,
                  borderColor: context.cfPrimaryTintStrong,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: context.cfPrimaryTint,
                          borderRadius: const BorderRadius.all(
                            Radius.circular(999),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.verified_user_rounded,
                              size: 16,
                              color: context.cfPrimary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Permisos · Primer acceso',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: context.cfPrimary,
                                    fontWeight: FontWeight.w900,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Permisos y acceso',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'CotidyFit ha detectado que todavía faltan permisos necesarios. Te los pedimos al entrar por primera vez para que recordatorios y funciones de inicio queden listos desde el principio.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView(
                    children: [
                      ProgressSectionCard(
                        backgroundColor: context.cfPrimaryTint,
                        borderColor: context.cfPrimaryTintStrong,
                        child: Text(
                          'CotidyFit solo usa permisos para funciones concretas: recordatorios, ubicación en Inicio y pasos si quieres sincronizarlos dentro de la app. Nada más.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: context.cfTextPrimary,
                            fontWeight: FontWeight.w700,
                            height: 1.35,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _permissionCard(
                        context,
                        title: 'Notificaciones',
                        subtitle:
                            'Para avisarte de tus recordatorios y ayudarte a mantener la rutina.',
                        icon: Icons.notifications_active_outlined,
                        status:
                            snapshot?.notifications ??
                            AppPermissionStatus.unavailable,
                      ),
                      const SizedBox(height: 12),
                      _permissionCard(
                        context,
                        title: 'Ubicación',
                        subtitle:
                            'Para mostrar ciudad, clima y hora local en la pantalla de inicio.',
                        icon: Icons.location_on_outlined,
                        status:
                            snapshot?.location ?? AppPermissionStatus.unavailable,
                      ),
                      const SizedBox(height: 12),
                      _permissionCard(
                        context,
                        title: 'Pasos y salud',
                        subtitle:
                          'Se revisa junto con notificaciones y ubicación cuando aceptas este paso. Después podrás volver a gestionarlo desde la sección de pasos.',
                        icon: Icons.monitor_heart_outlined,
                        status:
                            snapshot?.steps ?? AppPermissionStatus.unavailable,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ProgressSectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _requestingPermissions
                              ? null
                              : () => _reviewStartupPermissions(),
                          icon: _requestingPermissions
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.verified_user_outlined),
                          label: Text(
                            _requestingPermissions
                                ? 'Revisando permisos…'
                                : 'Aceptar y revisar ahora',
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _requestingPermissions
                              ? null
                              : () => _skipPermissionsPrompt(),
                          icon: const Icon(Icons.schedule_outlined),
                          label: const Text('Lo revisaré más tarde'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        kIsWeb
                            ? 'En web y escritorio no se muestran los permisos móviles. El flujo real salta en Android y iPhone.'
                            : 'Podrás cambiar estos permisos más tarde desde los ajustes del móvil.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _permissionCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required AppPermissionStatus status,
    String? statusLabel,
  }) {
    final label = statusLabel ?? _permissionStatusLabel(status);
    final color = _permissionStatusColor(status);

    return ProgressSectionCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: const BorderRadius.all(Radius.circular(14)),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.10),
                        borderRadius: const BorderRadius.all(
                          Radius.circular(999),
                        ),
                      ),
                      child: Text(
                        label,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _permissionStatusLabel(AppPermissionStatus status) {
    switch (status) {
      case AppPermissionStatus.granted:
        return 'Concedido';
      case AppPermissionStatus.notRequested:
        return 'Pendiente';
      case AppPermissionStatus.denied:
        return 'Bloqueado';
      case AppPermissionStatus.unavailable:
        return 'No aplica';
    }
  }

  Color _permissionStatusColor(AppPermissionStatus status) {
    switch (status) {
      case AppPermissionStatus.granted:
        return const Color(0xFF2E7D32);
      case AppPermissionStatus.notRequested:
        return const Color(0xFFC77800);
      case AppPermissionStatus.denied:
        return const Color(0xFFC62828);
      case AppPermissionStatus.unavailable:
        return context.cfTextSecondary;
    }
  }
}