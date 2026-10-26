import 'package:flutter_test/flutter_test.dart';
import 'package:signara/core/streak_service.dart';

class _FakeStore implements KeyValueStore {
  final Map<String, Object> _m = {};

  @override
  Future<int?> getInt(String key) async => _m[key] as int?;

  @override
  Future<String?> getString(String key) async => _m[key] as String?;

  @override
  Future<void> setInt(String key, int value) async => _m[key] = value;

  @override
  Future<void> setString(String key, String value) async => _m[key] = value;
}

void main() {
  late _FakeStore store;
  late DateTime clock;

  StreakService make() => StreakService(store, now: () => clock);

  setUp(() {
    store = _FakeStore();
    clock = DateTime(2026, 10, 26, 9);
  });

  test('first practice starts a streak of 1 and adds XP', () async {
    final s = await make().recordActivity(xp: 10);
    expect(s.streak, 1);
    expect(s.xp, 10);
    expect(s.practicedToday, isTrue);
  });

  test('practicing twice on the same day does not double count the streak',
      () async {
    final svc = make();
    await svc.recordActivity();
    final s = await svc.recordActivity();
    expect(s.streak, 1);
    expect(s.xp, 20);
  });

  test('consecutive days extend the streak', () async {
    final svc = make();
    await svc.recordActivity();
    clock = DateTime(2026, 10, 27, 20);
    final s = await svc.recordActivity();
    expect(s.streak, 2);
    expect(s.bestStreak, 2);
  });

  test('missing a day resets the streak but keeps the best', () async {
    final svc = make();
    await svc.recordActivity();
    clock = DateTime(2026, 10, 27);
    await svc.recordActivity();
    clock = DateTime(2026, 10, 30); // skipped two days
    expect((await svc.load()).streak, 0);
    final s = await svc.recordActivity();
    expect(s.streak, 1);
    expect(s.bestStreak, 2);
  });

  test('streak keeps counting across a month boundary', () async {
    final svc = make();
    clock = DateTime(2026, 10, 31);
    await svc.recordActivity();
    clock = DateTime(2026, 11, 1);
    final s = await svc.recordActivity();
    expect(s.streak, 2);
  });
}
