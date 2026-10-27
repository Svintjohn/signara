import 'package:flutter_test/flutter_test.dart';
import 'package:signara/core/streak_service.dart';
import 'package:signara/data/vocab.dart';
import 'package:signara/language/text_to_sign.dart';
import 'package:signara/learning/spaced_repetition.dart';
import 'package:signara/recognition/finger_state.dart';

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

/// Builds 60 features with the given fingers extended or curled.
/// Wrist is the origin; tips/PIPs sit along +y so distances are easy to reason about.
List<double> makeFeatures(List<bool> ext) {
  final f = List<double>.filled(60, 0.0);
  void set(int lm, double x, double y, double z) {
    f[(lm - 1) * 3] = x;
    f[(lm - 1) * 3 + 1] = y;
    f[(lm - 1) * 3 + 2] = z;
  }

  // Base of the index finger (landmark 5), used as the thumb reference.
  set(5, 0.3, 1.0, 0.0);
  // Thumb tip (landmark 4): out to the side, or tucked next to the index base.
  if (ext[0]) {
    set(4, -0.8, 0.5, 0.0);
  } else {
    set(4, 0.3, 0.8, 0.0);
  }

  // [tip, pip] landmarks for index, middle, ring, pinky.
  const pairs = [
    [8, 6],
    [12, 10],
    [16, 14],
    [20, 18],
  ];
  for (var i = 0; i < 4; i++) {
    final x = 0.1 * i;
    set(pairs[i][1], x, 1.5, 0.0);
    set(pairs[i][0], x, ext[i + 1] ? 2.0 : 1.0, 0.0);
  }
  return f;
}

void main() {
  group('FingerStates and rule letters', () {
    test('reads extended and curled fingers', () {
      final s = FingerStates.fromFeatures(
        makeFeatures([true, true, false, false, true]),
      );
      expect(s.extended, [true, true, false, false, true]);
    });

    test('every rule letter is recognized from its own pattern', () {
      const clf = RuleLetterClassifier();
      for (final e in letterRules.entries) {
        final p = clf.classify(makeFeatures(e.value));
        expect(p?.letter, e.key, reason: 'letter ${e.key}');
      }
    });

    test('rule patterns are all different from each other', () {
      final seen = <String>{};
      for (final e in letterRules.entries) {
        final key = e.value.map((b) => b ? '1' : '0').join();
        expect(seen.add(key), isTrue, reason: 'duplicate pattern for ${e.key}');
      }
    });

    test('an unmapped pattern gives no prediction', () {
      const clf = RuleLetterClassifier();
      // Only the middle finger up: not a rule letter.
      expect(
        clf.classify(makeFeatures([false, false, true, false, false])),
        isNull,
      );
    });

    test('feedback says what to fix', () {
      // Target L (thumb + index), but the user shows a fist plus pinky.
      final actual = FingerStates.fromFeatures(
        makeFeatures([false, false, false, false, true]),
      );
      final fb = feedbackFor('L', actual);
      expect(fb.hasRule, isTrue);
      expect(fb.correct, isFalse);
      expect(fb.hints, contains('Extend your thumb'));
      expect(fb.hints, contains('Extend your index finger'));
      expect(fb.hints, contains('Curl your pinky'));
    });

    test('feedback is correct when the pattern matches', () {
      final actual = FingerStates.fromFeatures(
        makeFeatures(letterRules['Y']!),
      );
      final fb = feedbackFor('Y', actual);
      expect(fb.correct, isTrue);
    });

    test('letters without a rule say so', () {
      final actual = FingerStates.fromFeatures(makeFeatures(letterRules['A']!));
      final fb = feedbackFor('M', actual);
      expect(fb.hasRule, isFalse);
      expect(fb.correct, isFalse);
    });

    test('rejects the wrong number of features', () {
      expect(() => FingerStates.fromFeatures([0.0]), throwsArgumentError);
    });
  });

  group('SpacedRepetitionService', () {
    late _FakeStore store;
    late DateTime clock;
    SpacedRepetitionService make() =>
        SpacedRepetitionService(store, now: () => clock);

    setUp(() {
      store = _FakeStore();
      clock = DateTime(2026, 10, 26, 9);
    });

    test('unseen cards fill the session in order', () async {
      final s = await make().todaysSession(['a', 'b', 'c', 'd'], target: 3);
      expect(s, ['a', 'b', 'c']);
    });

    test('a correct answer waits longer; due again after the interval',
        () async {
      final svc = make();
      await svc.record('a', correct: true); // box 1 -> due in 1 day
      expect(await svc.dueCount(), 0);
      expect(await svc.todaysSession(['a'], target: 5), isEmpty);

      clock = DateTime(2026, 10, 27, 9);
      expect(await svc.dueCount(), 1);
      expect(await svc.todaysSession(['a'], target: 5), ['a']);
    });

    test('box grows with consecutive correct answers and is capped', () async {
      final svc = make();
      for (var i = 0; i < 10; i++) {
        await svc.record('a', correct: true);
      }
      expect(await svc.boxOf('a'), SpacedRepetitionService.intervalDays.length - 1);
    });

    test('a wrong answer resets the card and it is due today', () async {
      final svc = make();
      await svc.record('a', correct: true);
      await svc.record('a', correct: true);
      await svc.record('a', correct: false);
      expect(await svc.boxOf('a'), 0);
      expect(await svc.dueCount(), 1);
    });

    test('due cards come before unseen ones', () async {
      final svc = make();
      await svc.record('z', correct: false); // due today
      final s = await svc.todaysSession(['a', 'b', 'z'], target: 2);
      expect(s, ['z', 'a']);
    });

    test('intervals cross a month boundary correctly', () async {
      final svc = make();
      clock = DateTime(2026, 10, 31, 9);
      await svc.record('a', correct: true); // due 2026-11-01
      clock = DateTime(2026, 11, 1, 9);
      expect(await svc.dueCount(), 1);
    });
  });

  group('TextToSignPlanner', () {
    const vocab = Vocab(
      alphabet: ['A', 'B'],
      numbers: ['1'],
      signs: [
        VocabEntry(gloss: 'HELLO', category: 'basics', en: 'hello', fil: 'kumusta'),
        VocabEntry(
          gloss: 'THANK-YOU',
          category: 'basics',
          en: 'thank you',
          fil: 'salamat',
        ),
        VocabEntry(
          gloss: 'HOW-MUCH',
          category: 'questions',
          en: 'how much',
          fil: 'magkano',
        ),
      ],
    );
    final planner = TextToSignPlanner(vocab);

    test('known words become signs, ignoring case and punctuation', () {
      final items = planner.plan('Hello, THANK you!');
      expect(items.map((e) => e.gloss), ['HELLO', 'THANK-YOU']);
    });

    test('multi-word phrases win over single words', () {
      expect(planner.plan('how much').single.gloss, 'HOW-MUCH');
    });

    test('Filipino words work too', () {
      expect(planner.plan('salamat').single.gloss, 'THANK-YOU');
      expect(planner.plan('magkano').single.gloss, 'HOW-MUCH');
    });

    test('unknown words are fingerspelled', () {
      final items = planner.plan('Hello Juan');
      expect(items[0].isSign, isTrue);
      expect(items[1].isSign, isFalse);
      expect(items[1].letters, ['J', 'U', 'A', 'N']);
    });

    test('units flattens signs and letters in order', () {
      final units = TextToSignPlanner.units(planner.plan('hello Ana'));
      expect(units, ['HELLO', 'A', 'N', 'A']);
    });

    test('empty or symbol-only text gives nothing', () {
      expect(planner.plan(''), isEmpty);
      expect(planner.plan('  ?!  '), isEmpty);
    });
  });
}
