import 'dart:io';
import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme.dart';
import '../../../models/message_model.dart';
import '../../../services/community_share_service.dart';
import '../../../widgets/progress/progress_section_card.dart';

class CommunityShareTab extends StatefulWidget {
  const CommunityShareTab({super.key});

  @override
  State<CommunityShareTab> createState() => _CommunityShareTabState();
}

class _CommunityShareTabState extends State<CommunityShareTab>
    with AutomaticKeepAliveClientMixin {
  final CommunityShareService _shareService = CommunityShareService();

  static const _kShareCacheVersion = 1;
  static const _kPublicStatsSyncTtl = Duration(minutes: 20);
  static Map<MessageType, List<CommunityShareOption>> _memoryCache =
      const <MessageType, List<CommunityShareOption>>{};
  static int _lastPublicStatsSyncAtMs = 0;

  static const List<_ShareCategory> _categories = <_ShareCategory>[
    _ShareCategory(
      type: MessageType.routine,
      title: 'Rutinas',
      subtitle: 'Entrenos listos para compartir.',
      icon: Icons.fitness_center_outlined,
      accent: Color(0xFF3763A6),
    ),
    _ShareCategory(
      type: MessageType.achievement,
      title: 'Logros',
      subtitle: 'Tus hitos, en corto y al grano.',
      icon: Icons.emoji_events_outlined,
      accent: Color(0xFFBE7A1A),
    ),
    _ShareCategory(
      type: MessageType.daySummary,
      title: 'Resumen',
      subtitle: 'CF, pasos, agua y comidas.',
      icon: Icons.auto_graph_outlined,
      accent: Color(0xFF29836B),
    ),
    _ShareCategory(
      type: MessageType.diet,
      title: 'Dieta',
      subtitle: 'Tu registro del día, más visual.',
      icon: Icons.restaurant_outlined,
      accent: Color(0xFF8F5A2A),
    ),
    _ShareCategory(
      type: MessageType.streaks,
      title: 'Rachas',
      subtitle: 'Constancia que se ve y se comparte.',
      icon: Icons.local_fire_department_outlined,
      accent: Color(0xFFC44B2C),
    ),
  ];

  Map<MessageType, List<CommunityShareOption>> _optionsByType =
      const <MessageType, List<CommunityShareOption>>{};
  Set<MessageType> _loadingTypes = <MessageType>{};
  bool _refreshing = false;
  MessageType? _activeType;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_bootstrap());
  }

  void _snack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _bootstrap() async {
    await _restoreCache();
    await _load();
  }

  String _cacheKey() {
    final uid = Firebase.apps.isNotEmpty
        ? FirebaseAuth.instance.currentUser?.uid.trim()
        : null;
    final safeUid = (uid == null || uid.isEmpty) ? 'guest' : uid;
    return 'cf_community_share_cache_v${_kShareCacheVersion}_$safeUid';
  }

  String _stringValue(Object? value) {
    if (value == null) return '';
    return value.toString().trim();
  }

  String? _stringOrNull(Object? value) {
    final text = _stringValue(value);
    return text.isEmpty ? null : text;
  }

  List<CommunityShareOption> _optionsFromJson(Object? rawOptions) {
    if (rawOptions is! List) return const <CommunityShareOption>[];

    final out = <CommunityShareOption>[];
    for (final raw in rawOptions) {
      if (raw is! Map) continue;

      final map = <String, Object?>{};
      for (final entry in raw.entries) {
        map[entry.key.toString()] = entry.value;
      }

      final id = _stringValue(map['id']);
      final payload = _stringValue(map['payload']);
      if (id.isEmpty || payload.isEmpty) continue;

      Map<String, Object?>? share;
      final rawShare = map['share'];
      if (rawShare is Map) {
        share = {
          for (final entry in rawShare.entries)
            entry.key.toString(): entry.value,
        };
      }

      out.add(
        CommunityShareOption(
          id: id,
          title: _stringValue(map['title']).isEmpty
              ? 'Compartir'
              : _stringValue(map['title']),
          subtitle: _stringOrNull(map['subtitle']),
          payload: payload,
          share: share,
        ),
      );
    }

    return out;
  }

  Future<void> _restoreCache() async {
    if (_memoryCache.isNotEmpty) {
      if (!mounted) return;
      setState(() {
        _optionsByType = _memoryCache;
      });
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey());
      if (raw == null || raw.trim().isEmpty) return;

      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      final types = decoded['types'];
      if (types is! Map) return;

      final restored = <MessageType, List<CommunityShareOption>>{};
      for (final category in _categories) {
        restored[category.type] = _optionsFromJson(types[category.type.name]);
      }

      _memoryCache = restored;
      if (!mounted) return;
      setState(() {
        _optionsByType = restored;
      });
    } catch (_) {
      // Ignore cache failures.
    }
  }

  Future<void> _persistCache(
    Map<MessageType, List<CommunityShareOption>> nextOptions,
  ) async {
    try {
      _memoryCache = nextOptions;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _cacheKey(),
        jsonEncode({
          'v': _kShareCacheVersion,
          'savedAtMs': DateTime.now().millisecondsSinceEpoch,
          'types': {
            for (final category in _categories)
              category.type.name: [
                for (final option in nextOptions[category.type] ?? const [])
                  {
                    'id': option.id,
                    'title': option.title,
                    'subtitle': option.subtitle,
                    'payload': option.payload,
                    'share': option.share,
                  },
              ],
          },
        }),
      );
    } catch (_) {
      // Ignore cache failures.
    }
  }

  Future<void> _syncPublicStatsIfStale({bool force = false}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (!force &&
        now - _lastPublicStatsSyncAtMs < _kPublicStatsSyncTtl.inMilliseconds) {
      return;
    }

    _lastPublicStatsSyncAtMs = now;
    try {
      await _shareService.syncMyPublicStatsBestEffort();
    } catch (_) {
      // Best-effort only.
    }
  }

  Future<void> _load({bool forcePublicSync = false}) async {
    final generation = ++_loadGeneration;
    final pending = {for (final category in _categories) category.type};

    if (mounted) {
      setState(() {
        _loadingTypes = pending;
        _refreshing = true;
      });
    }

    unawaited(_syncPublicStatsIfStale(force: forcePublicSync));

    for (final category in _categories) {
      unawaited(_loadCategory(type: category.type, generation: generation));
    }
  }

  Future<void> _loadCategory({
    required MessageType type,
    required int generation,
  }) async {
    List<CommunityShareOption> options;
    try {
      options = await _shareService.getShareOptions(type: type);
    } catch (_) {
      options = const <CommunityShareOption>[];
    }

    if (!mounted || generation != _loadGeneration) return;

    final nextOptions = <MessageType, List<CommunityShareOption>>{
      ..._optionsByType,
      type: options,
    };
    final nextLoadingTypes = <MessageType>{..._loadingTypes}..remove(type);
    final finished = nextLoadingTypes.isEmpty;

    setState(() {
      _optionsByType = nextOptions;
      _loadingTypes = nextLoadingTypes;
      _refreshing = nextLoadingTypes.isNotEmpty;
    });

    if (finished) {
      await _persistCache(nextOptions);
    }
  }

  String _emptyPreviewFor(_ShareCategory category) {
    switch (category.type) {
      case MessageType.achievement:
        return 'Todavía no tienes logros listos para compartir.';
      case MessageType.routine:
        return 'Todavía no hay rutinas recientes.';
      case MessageType.daySummary:
        return 'Todavía no hay resúmenes recientes.';
      case MessageType.diet:
        return 'Todavía no hay registros de comida recientes.';
      case MessageType.streaks:
        return 'Todavía no hay rachas suficientes.';
      case MessageType.text:
        return 'Todavía no hay datos suficientes.';
    }
  }

  Future<CommunityShareOption?> _pickOption(_ShareCategory category) async {
    final options =
        _optionsByType[category.type] ?? const <CommunityShareOption>[];
    if (options.isEmpty) return null;
    if (options.length == 1) return options.first;

    return showModalBottomSheet<CommunityShareOption>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
            child: ProgressSectionCard(
              padding: const EdgeInsets.all(8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
                    child: Text(
                      category.title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: options.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final option = options[index];
                        final subtitle = (option.subtitle ?? '').trim().isEmpty
                            ? option.payload.trim()
                            : option.subtitle!.trim();
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: category.accent.withValues(
                              alpha: 0.12,
                            ),
                            foregroundColor: category.accent,
                            child: Icon(category.icon),
                          ),
                          title: Text(option.title),
                          subtitle: Text(
                            subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => Navigator.of(context).pop(option),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _shareCategory(_ShareCategory category) async {
    if (_activeType != null) return;

    setState(() => _activeType = category.type);
    try {
      final selected = await _pickOption(category);
      if (!mounted || selected == null) return;

      final draft = await _shareService.composeExternalShareDraft(
        type: category.type,
        option: selected,
        target: CommunityExternalShareTarget.generic,
      );

      final text = draft.text.trim();
      if (text.isEmpty) {
        _snack('No se pudo generar el texto para compartir.');
        return;
      }

      final prepared = await _shareService.prepareExternalShare(
        type: category.type,
        option: selected,
        target: CommunityExternalShareTarget.generic,
        draft: draft,
      );

      if (_usesLocalPreviewFallback) {
        await _showLocalPhotoPreview(prepared: prepared, text: text);
        return;
      }

      final imageFile = await _createShareImageFile(prepared);

      await Share.shareXFiles(
        [
          XFile(
            imageFile.path,
            mimeType: 'image/png',
            name: prepared.imageName,
          ),
        ],
        text: text,
        subject: draft.subject,
      );
    } catch (_) {
      if (!mounted) return;
      _snack('No se pudo abrir el menú de compartir.');
    } finally {
      if (mounted) {
        setState(() => _activeType = null);
      }
    }
  }

  Future<void> _copyTextCategory(_ShareCategory category) async {
    if (_activeType != null) return;

    setState(() => _activeType = category.type);
    try {
      final selected = await _pickOption(category);
      if (!mounted || selected == null) return;

      final draft = await _shareService.composeExternalShareDraft(
        type: category.type,
        option: selected,
        target: CommunityExternalShareTarget.generic,
      );

      final text = draft.text.trim();
      if (text.isEmpty) {
        _snack('No se pudo generar el texto.');
        return;
      }

      await Clipboard.setData(ClipboardData(text: text));
      if (!mounted) return;
      _snack('Texto copiado.');
    } catch (_) {
      if (!mounted) return;
      _snack('No se pudo copiar el texto.');
    } finally {
      if (mounted) {
        setState(() => _activeType = null);
      }
    }
  }

  Future<File> _createShareImageFile(
    CommunityPreparedExternalShare prepared,
  ) async {
    final uri = Directory.systemTemp.uri.resolve(prepared.imageName);
    final file = File.fromUri(uri);
    await file.writeAsBytes(prepared.imageBytes, flush: true);
    return file;
  }

  bool get _usesLocalPreviewFallback {
    if (kIsWeb) return true;
    return !(Platform.isAndroid || Platform.isIOS);
  }

  Future<void> _showLocalPhotoPreview({
    required CommunityPreparedExternalShare prepared,
    required String text,
  }) async {
    final imageFile = await _createShareImageFile(prepared);
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
            child: ProgressSectionCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Compartir',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'En escritorio se muestra una vista previa local. En móvil se abre directamente el menú nativo de compartir.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: context.cfTextSecondary,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: const BorderRadius.all(Radius.circular(20)),
                    child: AspectRatio(
                      aspectRatio: 1080 / 1920,
                      child: Image.memory(
                        prepared.imageBytes,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: context.cfSoftSurface,
                      borderRadius: const BorderRadius.all(Radius.circular(18)),
                      border: Border.all(color: context.cfBorder),
                    ),
                    child: SelectableText(text, maxLines: 6),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () async {
                            await Clipboard.setData(ClipboardData(text: text));
                            if (!mounted) return;
                            _snack('Texto copiado para la prueba local.');
                          },
                          icon: const Icon(Icons.copy_all_outlined),
                          label: const Text('Copiar texto'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final opened = await launchUrl(imageFile.uri);
                            if (!mounted) return;
                            if (!opened) {
                              _snack('No se pudo abrir el PNG de prueba.');
                            }
                          },
                          icon: const Icon(Icons.open_in_new_outlined),
                          label: const Text('Abrir PNG'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _textActionLabel(MessageType type) {
    switch (type) {
      case MessageType.routine:
        return 'Enviar rutina por texto';
      case MessageType.achievement:
        return 'Enviar logro por texto';
      case MessageType.daySummary:
        return 'Enviar resumen por texto';
      case MessageType.diet:
        return 'Enviar dieta por texto';
      case MessageType.streaks:
        return 'Enviar racha por texto';
      case MessageType.text:
        return 'Enviar texto';
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: <Color>[
                  context.cfPrimary,
                  context.cfPrimary.withValues(alpha: 0.84),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.all(Radius.circular(28)),
              boxShadow: [
                BoxShadow(
                  color: context.cfPrimary.withValues(
                    alpha: context.cfIsDark ? 0.28 : 0.24,
                  ),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
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
                    borderRadius: const BorderRadius.all(Radius.circular(999)),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.16),
                    ),
                  ),
                  child: const Text(
                    'Comparte tu progreso',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Comparte en un toque.',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Imagen + texto corto, listo para WhatsApp, Instagram o TikTok.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.white.withValues(alpha: 0.92),
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 18),
                OutlinedButton.icon(
                  onPressed: _loadingTypes.isNotEmpty
                      ? null
                      : () => _load(forcePublicSync: true),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.28),
                    ),
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(14)),
                    ),
                  ),
                  icon: _refreshing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.refresh),
                  label: Text(
                    _refreshing ? 'Actualizando…' : 'Actualizar información',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          ProgressSectionCard(
            child: Row(
              children: [
                const Icon(
                  Icons.tips_and_updates_outlined,
                  color: CFColors.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _usesLocalPreviewFallback
                        ? 'Cada bloque genera imagen y texto. En escritorio verás una vista previa local.'
                        : 'Toca Compartir y se abrirá el menú nativo. Si prefieres, copia el texto.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: context.cfTextPrimary,
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          for (final category in _categories) ...[
            _ShareCategoryCard(
              category: category,
              options:
                  _optionsByType[category.type] ??
                  const <CommunityShareOption>[],
              busy:
                  _activeType == category.type ||
                  _loadingTypes.contains(category.type),
              emptyPreview: _emptyPreviewFor(category),
              onShare: () => _shareCategory(category),
              onCopyText: () => _copyTextCategory(category),
            ),
            const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}

class _ShareCategory {
  const _ShareCategory({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
  });

  final MessageType type;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
}

class _ShareCategoryCard extends StatelessWidget {
  const _ShareCategoryCard({
    required this.category,
    required this.options,
    required this.busy,
    required this.emptyPreview,
    required this.onShare,
    required this.onCopyText,
  });

  final _ShareCategory category;
  final List<CommunityShareOption> options;
  final bool busy;
  final String emptyPreview;
  final VoidCallback onShare;
  final VoidCallback onCopyText;

  Widget _buttonContent({required Widget leading, required String label}) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [leading, const SizedBox(width: 8), Text(label, maxLines: 1)],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pillColor = context.cfIsDark ? context.cfSoftSurface : Colors.white;
    final preview = options.isEmpty
        ? (busy ? 'Cargando información…' : emptyPreview)
        : ((options.first.subtitle ?? '').trim().isEmpty
              ? options.first.payload.trim()
              : options.first.subtitle!.trim());

    return ProgressSectionCard(
      padding: const EdgeInsets.all(0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              color: category.accent.withValues(alpha: 0.09),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: category.accent.withValues(alpha: 0.14),
                    borderRadius: const BorderRadius.all(Radius.circular(18)),
                  ),
                  child: Icon(category.icon, color: category.accent),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category.title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        category.subtitle,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: pillColor,
                    borderRadius: const BorderRadius.all(Radius.circular(999)),
                    border: Border.all(
                      color: category.accent.withValues(alpha: 0.24),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (busy) ...[
                        SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: category.accent,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        busy ? 'Actualizando' : '${options.length} opciones',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: category.accent,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  preview,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    height: 1.4,
                    color: context.cfTextPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      flex: 5,
                      child: SizedBox(
                        height: 48,
                        child: FilledButton(
                          onPressed: busy || options.isEmpty ? null : onShare,
                          child: _buttonContent(
                            leading: busy
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.ios_share_outlined),
                            label: busy ? 'Abriendo…' : 'Compartir',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 5,
                      child: SizedBox(
                        height: 48,
                        child: OutlinedButton(
                          onPressed: busy || options.isEmpty
                              ? null
                              : onCopyText,
                          child: _buttonContent(
                            leading: const Icon(Icons.copy_all_outlined),
                            label: 'Copiar texto',
                          ),
                        ),
                      ),
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
