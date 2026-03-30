import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

class HomeRemoteContentService {
  const HomeRemoteContentService();

  Stream<List<String>> watchStartQuotes({required List<String> fallback}) {
    if (Firebase.apps.isEmpty) {
      return Stream<List<String>>.value(fallback);
    }

    return FirebaseFirestore.instance
        .collection('app_config')
        .doc('home_content')
        .snapshots()
        .map((snap) => _readQuotes(snap.data(), fallback: fallback))
        .handleError((_) => fallback);
  }

  String quoteForToday(List<String> quotes, DateTime now) {
    final safeQuotes = quotes
        .where((quote) => quote.trim().isNotEmpty)
        .toList();
    if (safeQuotes.isEmpty) return '';
    final index = (now.year + now.month + now.day) % safeQuotes.length;
    return safeQuotes[index].trim();
  }

  List<String> _readQuotes(
    Map<String, dynamic>? data, {
    required List<String> fallback,
  }) {
    final raw = data?['startQuotes'] ?? data?['quotes'];
    if (raw is Iterable) {
      final parsed = raw
          .map((item) => item?.toString().trim() ?? '')
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
      if (parsed.isNotEmpty) return parsed;
    }
    return fallback;
  }
}
