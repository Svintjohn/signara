import 'package:shared_preferences/shared_preferences.dart';

/// Tiny storage interface so the streak logic can be unit-tested without
/// a real SharedPreferences instance.
abstract class KeyValueStore {
  Future<int?> getInt(String key);
  Future<String?> getString(String key);
  Future<void> setInt(String key, int value);
  Future<void> setString(String key, String value);
}

class PrefsStore implements KeyValueStore {
  PrefsStore(this._prefs);

  final SharedPreferences _prefs;

  @override
  Future<int?> getInt(String key) async => _prefs.getInt(key);

  @override
  Future<String?> getString(String key) async => _prefs.getString(key);

  @override
  Future<void> setInt(String key, int value) async {
    await _prefs.setInt(key, value);
  }

  @override
  Future<void> setString(String key, String value) async {
    await _prefs.setString(key, value);
  }
}

class StreakState {
  const StreakState({
    required this.streak,
    required this.bestStreak,
    required this.xp,
    required this.lastActiveDay,
    required this.practicedToday,
  });

  /// Current streak as it should be *shown* (already zero if it was broken).
  final int streak;
  final int bestStreak;
  final int xp;
  final String? lastActiveDay;
  final bool practicedToday;
}

/// Daily streak + XP, based on the device's local calendar day.
class StreakService {
  StreakService(this._store, {DateTime Function()? now})
      : _now = now ?? DateTime.now;

  final KeyValueStore _store;
  final DateTime Function() _now;

  static const _kStreak = 'streak';
  static const _kBest = 'best_streak';
  static const _kXp = 'xp';
  static const _kLast = 'last_active_day';

  static String dayKey(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  static DateTime parseDay(String key) => _parse(key);

  static DateTime _parse(String key) {
    final p = key.split('-').map(int.parse).toList();
    // UTC on purpose: avoids DST making a "day" 23 or 25 hours long.
    return DateTime.utc(p[0], p[1], p[2]);
  }

  Future<StreakState> load() async {
    final streak = await _store.getInt(_kStreak) ?? 0;
    final best = await _store.getInt(_kBest) ?? 0;
    final xp = await _store.getInt(_kXp) ?? 0;
    final last = await _store.getString(_kLast);
    final today = dayKey(_now());

    var effective = streak;
    var practicedToday = false;
    if (last != null) {
      final gap = _parse(today).difference(_parse(last)).inDays;
      if (gap <= 0) {
        // Same day (or the clock moved backwards): don't double count.
        practicedToday = true;
      } else if (gap > 1) {
        effective = 0; // missed at least one full day
      }
    }

    return StreakState(
      streak: effective,
      bestStreak: best,
      xp: xp,
      lastActiveDay: last,
      practicedToday: practicedToday,
    );
  }

  Future<StreakState> recordActivity({int xp = 10}) async {
    final current = await load();
    final today = dayKey(_now());

    final streak = current.practicedToday ? current.streak : current.streak + 1;
    final best = streak > current.bestStreak ? streak : current.bestStreak;
    final totalXp = current.xp + xp;

    await _store.setInt(_kStreak, streak);
    await _store.setInt(_kBest, best);
    await _store.setInt(_kXp, totalXp);
    await _store.setString(_kLast, today);

    return StreakState(
      streak: streak,
      bestStreak: best,
      xp: totalXp,
      lastActiveDay: today,
      practicedToday: true,
    );
  }
}
