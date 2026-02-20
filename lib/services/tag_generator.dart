import 'dart:math';

import 'package:diacritic/diacritic.dart';

class TagGenerator {
  TagGenerator({Random? rng}) : _rng = rng ?? Random.secure();

  final Random _rng;

  /// Normalizes a visible username into a stable search key.
  ///
  /// Rules:
  /// - Lowercase
  /// - Remove diacritics (tildes)
  /// - Remove spaces
  /// - Keep only letters and numbers (a-z0-9)
  ///
  /// Never use this value for display.
  static String normalize(String input) {
    final lower = input.trim().toLowerCase();
    final noDiacritics = removeDiacritics(lower);
    final onlyAlnum = noDiacritics.replaceAll(RegExp(r'[^a-z0-9]'), '');
    return onlyAlnum.isEmpty ? 'user' : onlyAlnum;
  }

  /// Back-compat wrapper: prefer [normalize].
  static String normalizeUsername(String input) => normalize(input);

  /// Legacy normalization used by the previous identity system.
  ///
  /// - Lowercase
  /// - Replace non [a-z0-9_] with '_'
  /// - Squash underscores
  /// - Trim underscores
  /// - Truncate to 16 chars
  static String normalizeLegacyUnderscore16(String input) {
    final lower = input.trim().toLowerCase();
    final cleaned = lower.replaceAll(RegExp(r'[^a-z0-9_]'), '_');
    final squashed = cleaned.replaceAll(RegExp(r'_+'), '_');
    final trimmed = squashed.replaceAll(RegExp(r'^_+|_+$'), '');
    final out = trimmed.isEmpty ? 'user' : trimmed;
    return out.length > 16 ? out.substring(0, 16) : out;
  }

  static String buildLegacySearchableTag({required String usernamePart, required String tag}) {
    final u = normalizeLegacyUnderscore16(usernamePart);
    final t = tag.trim();
    return '$u#$t';
  }

  static bool isValidNumericTag6(String input) {
    return RegExp(r'^\d{6}$').hasMatch(input.trim());
  }

  static ({String usernamePart, String tag})? splitFullTagInput(String input) {
    final v = input.trim();
    final i = v.lastIndexOf('#');
    if (i <= 0 || i == v.length - 1) return null;
    final usernamePart = v.substring(0, i).trim();
    final tag = v.substring(i + 1).trim();
    if (usernamePart.isEmpty || !isValidNumericTag6(tag)) return null;
    return (usernamePart: usernamePart, tag: tag);
  }

  String generateNumericTag6() {
    final n = _rng.nextInt(1000000);
    return n.toString().padLeft(6, '0');
  }

  /// Builds the visible uniqueTag.
  ///
  /// IMPORTANT: does not normalize the username.
  static String buildUniqueTag({required String username, required String tag}) {
    final u = username.trim();
    final t = tag.trim();
    return '$u#$t';
  }

  static String buildSearchableTag({required String usernameNormalized, required String tag}) {
    final u = normalize(usernameNormalized);
    final t = tag.trim();
    return '$u#$t';
  }

  /// Back-compat wrapper.
  /// Old code used lowercase(uniqueTag). New code should use [buildSearchableTag].
  static String buildSearchableTagLegacy(String uniqueTag) => uniqueTag.trim().toLowerCase();

  static bool looksLikeFullTagInput(String input) {
    return splitFullTagInput(input) != null;
  }
}
