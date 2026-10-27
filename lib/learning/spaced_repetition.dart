import 'dart:convert';

import '../core/streak_service.dart';

class SrsCard {
  const SrsCard({required this.box, required this.dueDay});

  factory SrsCard.fromJson(Map<String, dynamic> j) => SrsCard(
        box: (j['box'] as num).toInt(),
        dueDay: j['due'] as String,
      );

  final int box;

  /// yyyy-mm-dd
  final String dueDay;

  Map<String, dynamic> toJson() => {'box': box, 'due': dueDay};
}

/// Leitner-style spaced repetition. Right answer: move up a box (longer wait).
/// Wrong answer: back to box 0 (due again today). Unseen cards are not stored.
class SpacedRepetitionService {
  SpacedRepetitionService(this._store, {DateTime Function()? now})
      : _now = now ?? DateTime.now;

  final KeyValueStore _store;
  final DateTime Function() _now;

  /// Days to wait for boxes 0..5.
  static const List<int> intervalDays = [0, 1, 2, 4, 8, 16];
  static const _key = 'srs_v1';

  String get _today => StreakService.dayKey(_now());

  Future<Map<String, SrsCard>> _load() async {
    final raw = await _store.getString(_key);
    if (raw == null) return {};
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      return m.map(
        (k, v) => MapEntry(k, SrsCard.fromJson(v as Map<String, dynamic>)),
      );
    } catch (_) {
      return {};
    }
  }

  Future<void> _save(Map<String, SrsCard> cards) => _store.setString(
        _key,
        jsonEncode(cards.map((k, v) => MapEntry(k, v.toJson()))),
      );

  Future<int> dueCount() async {
    final today = _today;
    return (await _load()).values.where((c) => c.dueDay.compareTo(today) <= 0).length;
  }

  Future<int?> boxOf(String id) async => (await _load())[id]?.box;

  /// Today's practice list: due cards first (oldest first), then unseen cards
  /// from [allIds] in order, up to [target] cards in total.
  Future<List<String>> todaysSession(
    List<String> allIds, {
    int target = 8,
  }) async {
    final cards = await _load();
    final today = _today;

    final due = cards.entries
        .where((e) => e.value.dueDay.compareTo(today) <= 0)
        .toList()
      ..sort((a, b) => a.value.dueDay.compareTo(b.value.dueDay));

    final session = <String>[for (final e in due) e.key];
    if (session.length > target) return session.sublist(0, target);

    for (final id in allIds) {
      if (session.length >= target) break;
      if (!cards.containsKey(id)) session.add(id);
    }
    return session;
  }

  Future<void> record(String id, {required bool correct}) async {
    final cards = await _load();
    final current = cards[id]?.box ?? 0;
    final topBox = intervalDays.length - 1;
    final int box = correct ? (current + 1 > topBox ? topBox : current + 1) : 0;
    final due = StreakService.parseDay(_today)
        .add(Duration(days: intervalDays[box]));
    cards[id] = SrsCard(box: box, dueDay: StreakService.dayKey(due));
    await _save(cards);
  }
}
