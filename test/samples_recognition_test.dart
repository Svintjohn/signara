import 'package:flutter_test/flutter_test.dart';
import 'package:signara/core/streak_service.dart';
import 'package:signara/data/sample_store.dart';
import 'package:signara/recognition/dtw.dart';
import 'package:signara/recognition/letter_classifier.dart';
import 'package:signara/recognition/sample_letter_classifier.dart';
import 'package:signara/recognition/sequence_features.dart';
import 'package:signara/recognition/sign_segmenter.dart';
import 'package:signara/recognition/sign_template_classifier.dart';
import 'package:signara/widgets/hand_skeleton.dart';

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

/// 21 landmarks; [dx]/[dy] move the whole hand.
List<double> handXyz({double dx = 0, double dy = 0}) => [
      for (var i = 0; i < 21; i++) ...[
        0.50 + 0.010 * i + dx,
        0.40 + 0.02 * ((i * 7) % 5) + dy,
        -0.005 * i,
      ],
    ];

/// A 62-number frame with only one number set, so distances are easy to
/// reason about.
List<double> frameWith(int dim, double v) {
  final f = List<double>.filled(sequenceFrameLength, 0.0);
  f[dim] = v;
  return f;
}

/// A ramp from 0 to 1 in dimension [dim].
List<List<double>> ramp(int n, int dim, {double noise = 0}) => [
      for (var i = 0; i < n; i++)
        frameWith(dim, i / (n - 1) + (i.isEven ? noise : -noise)),
    ];

class _Fallback implements LetterClassifier {
  @override
  bool get isReady => true;

  @override
  LetterPrediction? classify(List<double> features) =>
      const LetterPrediction('F', 0.5);
}

void main() {
  group('buildSequence', () {
    test('gives one 62-number frame per input frame, starting at zero', () {
      final seq = buildSequence([
        RawHand(handXyz(), 1.0),
        RawHand(handXyz(dx: 0.1), 1.0),
        RawHand(handXyz(dx: 0.2), 1.0),
      ]);
      expect(seq.length, 3);
      expect(seq.first.length, sequenceFrameLength);
      expect(seq.first[60], closeTo(0, 1e-9));
      expect(seq.first[61], closeTo(0, 1e-9));
    });

    test('moving the hand right makes the path number positive', () {
      final seq = buildSequence([
        RawHand(handXyz(), 1.0),
        RawHand(handXyz(dx: 0.2), 1.0),
      ]);
      expect(seq[1][60], greaterThan(0));
      expect(seq[1][61], closeTo(0, 1e-9));
    });

    test('is the same wherever in the picture the sign starts', () {
      final a = buildSequence([
        RawHand(handXyz(), 1.0),
        RawHand(handXyz(dx: 0.1, dy: 0.05), 1.0),
      ]);
      final b = buildSequence([
        RawHand(handXyz(dx: 0.2, dy: -0.1), 1.0),
        RawHand(handXyz(dx: 0.3, dy: -0.05), 1.0),
      ]);
      for (var i = 0; i < a.length; i++) {
        for (var k = 0; k < a[i].length; k++) {
          expect(b[i][k], closeTo(a[i][k], 1e-6));
        }
      }
    });

    test('empty input gives an empty sequence', () {
      expect(buildSequence([]), isEmpty);
    });
  });

  group('dtw and resample', () {
    test('resample keeps the ends and interpolates', () {
      final out = resample([
        [0.0],
        [10.0],
      ], 5);
      expect(out.length, 5);
      expect(out.first, [0.0]);
      expect(out.last, [10.0]);
      expect(out[2][0], closeTo(5, 1e-9));
    });

    test('identical sequences have distance zero', () {
      final a = ramp(10, 0);
      expect(dtwDistance(a, a), closeTo(0, 1e-9));
    });

    test('a different sequence is farther than a similar one', () {
      final base = ramp(12, 0);
      final similar = ramp(12, 0, noise: 0.02);
      final other = ramp(12, 1);
      expect(
        dtwDistance(base, similar),
        lessThan(dtwDistance(base, other)),
      );
    });

    test('works for sequences of different length', () {
      final d = dtwDistance(ramp(10, 0), ramp(20, 0));
      expect(d.isFinite, isTrue);
      expect(d, lessThan(0.2));
    });
  });

  group('SignTemplateClassifier', () {
    final samples = [
      SeqSample('HELLO', ramp(12, 0)),
      SeqSample('HELLO', ramp(14, 0, noise: 0.02)),
      SeqSample('THANK-YOU', ramp(12, 1)),
    ];
    final clf = SignTemplateClassifier(samples);

    test('is not ready without samples', () {
      final empty = SignTemplateClassifier([]);
      expect(empty.isReady, isFalse);
      expect(empty.classify(ramp(10, 0)), isNull);
    });

    test('recognizes a noisy, different-speed version of a sign', () {
      final m = clf.classify(ramp(20, 0, noise: 0.03));
      expect(m?.gloss, 'HELLO');
      expect(m!.confidence, greaterThan(0.5));
    });

    test('tells two signs apart', () {
      expect(clf.classify(ramp(15, 1, noise: 0.02))?.gloss, 'THANK-YOU');
    });

    test('rejects something far from every example', () {
      final junk = [for (var i = 0; i < 12; i++) frameWith(5, 9.0)];
      expect(clf.classify(junk), isNull);
    });

    test('too-short input is rejected', () {
      expect(clf.classify([frameWith(0, 0.5)]), isNull);
    });
  });

  group('SignSegmenter', () {
    RawHand hand() => RawHand(handXyz(), 1.0);

    test('emits a sign after the hand has been gone long enough', () {
      final s = SignSegmenter(minFrames: 5, endGapFrames: 3);
      for (var i = 0; i < 6; i++) {
        expect(s.update(hand()), isNull);
      }
      expect(s.isRecording, isTrue);
      expect(s.update(null), isNull);
      expect(s.update(null), isNull);
      final done = s.update(null);
      expect(done?.length, 6);
      expect(s.isRecording, isFalse);
    });

    test('a short blip is thrown away', () {
      final s = SignSegmenter(minFrames: 5, endGapFrames: 2);
      for (var i = 0; i < 3; i++) {
        s.update(hand());
      }
      s.update(null);
      expect(s.update(null), isNull);
      expect(s.isRecording, isFalse);
    });

    test('a short gap inside a sign does not split it', () {
      final s = SignSegmenter(minFrames: 3, endGapFrames: 4);
      for (var i = 0; i < 4; i++) {
        s.update(hand());
      }
      s.update(null);
      s.update(null);
      for (var i = 0; i < 4; i++) {
        s.update(hand());
      }
      s.update(null);
      s.update(null);
      s.update(null);
      final done = s.update(null);
      expect(done?.length, 8);
    });

    test('a very long sign is cut at maxFrames', () {
      final s = SignSegmenter(maxFrames: 5, minFrames: 2);
      List<RawHand>? out;
      for (var i = 0; i < 5; i++) {
        out = s.update(hand());
      }
      expect(out?.length, 5);
    });
  });

  group('SampleStore', () {
    test('saves and loads', () async {
      final backing = _FakeStore();
      final a = SampleStore(backing);
      await a.addStatic('A', [List<double>.filled(60, 0.12345678)]);
      await a.addSeq('HELLO', ramp(5, 0));

      final b = SampleStore(backing);
      await b.load();
      expect(b.statics.single.label, 'A');
      expect(b.statics.single.features.first, closeTo(0.1235, 1e-9));
      expect(b.seqs.single.gloss, 'HELLO');
      expect(b.seqs.single.frames.length, 5);
    });

    test('export then import adds the samples again', () async {
      final a = SampleStore(_FakeStore());
      await a.addStatic('A', [List<double>.filled(60, 0.2)]);
      await a.addSeq('HELLO', ramp(4, 1));

      final b = SampleStore(_FakeStore());
      final added = await b.importJson(a.exportJson());
      expect(added, 2);
      expect(b.staticCounts, {'A': 1});
      expect(b.seqCounts, {'HELLO': 1});
    });

    test('importing garbage throws and changes nothing', () async {
      final s = SampleStore(_FakeStore());
      await s.addStatic('A', [List<double>.filled(60, 0.2)]);
      await expectLater(s.importJson('not json'), throwsFormatException);
      await expectLater(
        s.importJson('{"static":[{"l":"B","f":"oops"}]}'),
        throwsFormatException,
      );
      expect(s.statics.length, 1);
    });

    test('removeLabel and referenceFor', () async {
      final s = SampleStore(_FakeStore());
      await s.addStatic('A', [List<double>.filled(60, 0.2)]);
      await s.addSeq('HELLO', ramp(4, 1));
      expect(s.referenceFor('HELLO')?.length, 4);
      expect(s.referenceFor('A')?.length, 1);
      expect(s.referenceFor('Z'), isNull);

      await s.removeLabel('HELLO');
      expect(s.referenceFor('HELLO'), isNull);
      expect(s.seqs, isEmpty);
    });

    test('revision goes up when data changes', () async {
      final s = SampleStore(_FakeStore());
      final before = s.revision;
      await s.addSeq('HELLO', ramp(3, 0));
      expect(s.revision, greaterThan(before));
    });
  });

  group('SampleLetterClassifier', () {
    final samples = <StaticSample>[
      StaticSample('X', List<double>.filled(60, 0.1)),
      StaticSample('X', List<double>.filled(60, 0.12)),
      StaticSample('Y', List<double>.filled(60, 0.9)),
      StaticSample('Y', List<double>.filled(60, 0.88)),
    ];

    test('predicts the closest recorded letter', () {
      final c = SampleLetterClassifier(() => samples, fallback: _Fallback());
      final p = c.classify(List<double>.filled(60, 0.11));
      expect(p?.letter, 'X');
      expect(p!.confidence, greaterThan(0.5));
    });

    test('falls back when nothing is close', () {
      final c = SampleLetterClassifier(() => samples, fallback: _Fallback());
      expect(c.classify(List<double>.filled(60, 5.0))?.letter, 'F');
    });

    test('falls back when there are no samples', () {
      final c = SampleLetterClassifier(() => [], fallback: _Fallback());
      expect(c.classify(List<double>.filled(60, 0.1))?.letter, 'F');
    });

    test('uses samples added later', () {
      final live = <StaticSample>[];
      final c = SampleLetterClassifier(() => live, fallback: _Fallback());
      expect(c.classify(List<double>.filled(60, 0.1))?.letter, 'F');
      live.add(StaticSample('X', List<double>.filled(60, 0.1)));
      expect(c.classify(List<double>.filled(60, 0.1))?.letter, 'X');
    });
  });

  group('skeleton geometry', () {
    test('21 points with the wrist at the origin', () {
      final pts = skeletonPoints(List<double>.filled(60, 0.5));
      expect(pts.length, 21);
      expect(pts.first.dx, 0);
      expect(pts.first.dy, 0);
    });

    test('the path numbers shift the whole hand', () {
      final f = [...List<double>.filled(60, 0.0), 2.0, -1.0];
      final pts = skeletonPoints(f);
      expect(pts.first.dx, 2.0);
      expect(pts.first.dy, -1.0);
    });

    test('bounds hold every frame', () {
      final a = List<double>.filled(60, 0.0);
      final b = [...List<double>.filled(60, 0.0), 3.0, 0.0];
      final r = skeletonBounds([a, b]);
      expect(r.left, lessThanOrEqualTo(0));
      expect(r.right, greaterThanOrEqualTo(3.0));
    });
  });
}
