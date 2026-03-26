import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../../services/connectivity_service.dart';
import '../../services/offline_sync_queue_service.dart';

class OfflineSyncBanner extends StatelessWidget {
  const OfflineSyncBanner({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final firebaseReady = Firebase.apps.isNotEmpty;
    final mergedListenables = <Listenable>[
      ConnectivityService.instance,
      if (firebaseReady) OfflineSyncQueueService.instance,
    ];

    return AnimatedBuilder(
      animation: Listenable.merge(mergedListenables),
      builder: (context, _) {
        final isOnline = ConnectivityService.instance.isOnline;
        final pendingCount = firebaseReady
            ? OfflineSyncQueueService.instance.pendingCount
            : 0;
        final isSyncing = firebaseReady
            ? OfflineSyncQueueService.instance.isSyncing
            : false;

        String? message;
        Color? background;

        if (!isOnline) {
          message = 'Sin conexión. Guardando cambios en este dispositivo.';
          background = const Color(0xFF8F5A2A);
        } else if (isSyncing && pendingCount > 0) {
          message =
              'Conexión restaurada. Sincronizando $pendingCount cambios...';
          background = const Color(0xFF1F5D4E);
        } else if (pendingCount > 0) {
          message = '$pendingCount cambios pendientes de sincronizar.';
          background = const Color(0xFF36547E);
        }

        return Stack(
          children: [
            child,
            if (message != null)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                      child: Material(
                        color: background,
                        borderRadius: const BorderRadius.all(
                          Radius.circular(14),
                        ),
                        elevation: 0,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          child: Text(
                            message,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
