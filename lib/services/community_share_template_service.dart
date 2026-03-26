import 'package:diacritic/diacritic.dart';
import 'package:flutter/services.dart';

import '../models/message_model.dart';

enum CommunityShareTemplateFlavor { storyChat, postReel }

class CommunityShareResolvedTemplate {
  const CommunityShareResolvedTemplate({
    required this.text,
    required this.shortPhrase,
  });

  final String text;
  final String shortPhrase;
}

class CommunityShareTemplateService {
  static const String templateAssetPath =
      'admin_panel/textos_y_fotos_para_compartir';

  Map<String, String>? _cache;

  Future<CommunityShareResolvedTemplate> resolve({
    required MessageType type,
    required CommunityShareTemplateFlavor flavor,
    required Map<String, String> replacements,
    required String promoUrl,
  }) async {
    final templates = await _loadTemplates();
    final key = _slotKey(type: type, flavor: flavor);
    final rawTemplate = templates[key];
    if (rawTemplate == null || rawTemplate.trim().isEmpty) {
      throw StateError('No hay plantilla para ${type.name}/${flavor.name}.');
    }

    final text = _formatTemplate(
      rawTemplate,
      replacements: replacements,
      promoUrl: promoUrl,
    );

    return CommunityShareResolvedTemplate(
      text: text,
      shortPhrase: _extractShortPhrase(text, promoUrl: promoUrl),
    );
  }

  Future<Map<String, String>> _loadTemplates() async {
    final cached = _cache;
    if (cached != null) return cached;

    final raw = await rootBundle.loadString(templateAssetPath);
    final lines = raw.replaceAll('\r\n', '\n').split('\n');

    final parsed = <String, String>{};
    _TemplateCategory? currentCategory;
    CommunityShareTemplateFlavor? currentFlavor;
    var buffer = StringBuffer();

    void flush() {
      if (currentCategory == null || currentFlavor == null) {
        buffer = StringBuffer();
        return;
      }

      final value = buffer.toString().trim();
      if (value.isEmpty) {
        buffer = StringBuffer();
        return;
      }

      parsed[_slotKey(
            type: _messageTypeFor(currentCategory),
            flavor: currentFlavor,
          )] =
          value;
      buffer = StringBuffer();
    }

    for (final rawLine in lines) {
      final line = rawLine.replaceFirst(RegExp(r'\s+$'), '');
      final trimmed = line.trim();

      if (trimmed.startsWith('### ')) {
        flush();
        currentCategory = _categoryFromHeading(trimmed.substring(4));
        currentFlavor = null;
        continue;
      }

      if (trimmed.startsWith('## ')) {
        flush();
        currentFlavor = _flavorFromHeading(trimmed.substring(3));
        continue;
      }

      if (currentCategory == null || currentFlavor == null) continue;

      if (buffer.isNotEmpty) buffer.writeln();
      buffer.write(line);
    }

    flush();
    _cache = parsed;
    return parsed;
  }

  String _formatTemplate(
    String rawTemplate, {
    required Map<String, String> replacements,
    required String promoUrl,
  }) {
    var text = rawTemplate;
    text = _replaceStructuredFragments(
      text,
      replacements: replacements,
      promoUrl: promoUrl,
    );

    final orderedKeys = replacements.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    for (final key in orderedKeys) {
      text = text.replaceAll(key, replacements[key] ?? '');
    }

    text = text.replaceAll('https://cotidyfit.com', promoUrl.trim());
    text = text.replaceAll('cotidyfit.com', _compactPromoUrl(promoUrl));
    text = text.replaceAll(RegExp(r'\[[^\]]+\]'), '');

    final cleanedLines = text
        .replaceAll('\r\n', '\n')
        .split('\n')
        .map((line) => line.replaceFirst(RegExp(r'\s+$'), ''))
        .where((line) {
          final trimmed = line.trim();
          if (trimmed.isEmpty) return true;
          if (RegExp(
            r'^[A-Za-zÁÉÍÓÚÜÑáéíóúüñ0-9 /"().,+-]+:\s*$',
          ).hasMatch(trimmed)) {
            return false;
          }
          if (RegExp(r'^[-*•]+\s*$').hasMatch(trimmed)) {
            return false;
          }
          return true;
        })
        .toList(growable: false);

    return cleanedLines.join('\n').replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
  }

  String _replaceStructuredFragments(
    String text, {
    required Map<String, String> replacements,
    required String promoUrl,
  }) {
    final routineName = replacements['[Nombre de la rutina]'] ?? 'Rutina';
    final durationIntensity = replacements['[Duración/Intensidad]'] ?? '—';
    final streakTitle = replacements['[Nombre de la racha]'] ?? 'Racha';
    final streakCurrent = replacements['[[RACHA_ACTUAL]]'] ?? '0';
    final streakBest = replacements['[[RACHA_MEJOR]]'] ?? streakCurrent;

    text = text.replaceAll(
      '[Nombre de la rutina]: # "- [Duración/Intensidad]"',
      '$routineName: - $durationIntensity',
    );
    text = text.replaceAll(
      '⚡ [Nombre de la racha]: [Número] días · Mejor: [Número] días',
      '⚡ $streakTitle: $streakCurrent días · Mejor: $streakBest días',
    );
    text = text.replaceAll(
      '[Nombre de la racha]: [Número] días · Mejor: [Número] días',
      '$streakTitle: $streakCurrent días · Mejor: $streakBest días',
    );
    text = text.replaceAll('👉 https://cotidyfit.com', '👉 ${promoUrl.trim()}');

    return text;
  }

  String _extractShortPhrase(String text, {required String promoUrl}) {
    final paragraphs = text
        .split(RegExp(r'\n\s*\n'))
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList(growable: false);

    final candidates = <String>[...paragraphs.skip(1), ...paragraphs.take(1)];

    for (final paragraph in candidates) {
      final filtered = paragraph
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .where(
            (line) =>
                !line.contains('http') &&
                !line.contains(_compactPromoUrl(promoUrl)) &&
                !line.startsWith('#'),
          )
          .join(' ')
          .trim();

      if (_isPhraseCandidate(filtered, promoUrl: promoUrl)) {
        return _firstSentence(filtered);
      }
    }

    return '';
  }

  bool _isPhraseCandidate(String paragraph, {required String promoUrl}) {
    final normalized = paragraph.trim();
    if (normalized.length < 35 || normalized.length > 220) return false;
    if (normalized.contains('http') ||
        normalized.contains(_compactPromoUrl(promoUrl))) {
      return false;
    }
    if (normalized.startsWith('#')) return false;
    if (normalized.contains('[') || normalized.contains(']')) return false;
    if (normalized.split('\n').length > 2) return false;
    if (normalized.contains('CF ') ||
        normalized.contains('Proteínas:') ||
        normalized.contains('Pasos:') ||
        normalized.contains('Racha actual')) {
      return false;
    }
    return normalized.contains('.') ||
        normalized.contains('!') ||
        normalized.contains('¿');
  }

  String _firstSentence(String paragraph) {
    final compact = paragraph
        .replaceAll('\n', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final match = RegExp(r'^.*?[.!?](?=\s|$)').firstMatch(compact);
    if (match != null) {
      return match.group(0)!.trim();
    }
    return compact;
  }

  String _compactPromoUrl(String promoUrl) {
    final uri = Uri.tryParse(promoUrl.trim());
    final host = (uri?.host ?? '').trim();
    if (host.isNotEmpty) {
      return host.startsWith('www.') ? host.substring(4) : host;
    }
    return promoUrl
        .trim()
        .replaceFirst(RegExp(r'^https?://'), '')
        .replaceFirst(RegExp(r'/$'), '');
  }

  _TemplateCategory? _categoryFromHeading(String heading) {
    final normalized = removeDiacritics(heading).toUpperCase();
    if (normalized.contains('RESUMEN')) return _TemplateCategory.daySummary;
    if (normalized.contains('RUTINAS')) return _TemplateCategory.routine;
    if (normalized.contains('LOGROS')) return _TemplateCategory.achievement;
    if (normalized.contains('DIETA')) return _TemplateCategory.diet;
    if (normalized.contains('RACHAS')) return _TemplateCategory.streaks;
    return null;
  }

  CommunityShareTemplateFlavor? _flavorFromHeading(String heading) {
    final normalized = removeDiacritics(heading).toUpperCase();
    if (normalized.contains('PUBLICACIONES/REELS')) {
      return CommunityShareTemplateFlavor.postReel;
    }
    if (normalized.contains('HISTORIAS/CHATS')) {
      return CommunityShareTemplateFlavor.storyChat;
    }
    return null;
  }

  MessageType _messageTypeFor(_TemplateCategory category) {
    switch (category) {
      case _TemplateCategory.daySummary:
        return MessageType.daySummary;
      case _TemplateCategory.routine:
        return MessageType.routine;
      case _TemplateCategory.achievement:
        return MessageType.achievement;
      case _TemplateCategory.diet:
        return MessageType.diet;
      case _TemplateCategory.streaks:
        return MessageType.streaks;
    }
  }

  String _slotKey({
    required MessageType type,
    required CommunityShareTemplateFlavor flavor,
  }) {
    return '${type.name}:${flavor.name}';
  }
}

enum _TemplateCategory { daySummary, routine, achievement, diet, streaks }
