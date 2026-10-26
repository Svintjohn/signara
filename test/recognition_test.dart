import 'package:flutter_test/flutter_test.dart';
import 'package:signara/data/vocab.dart';
import 'package:signara/language/sentence_smoother.dart';
import 'package:signara/recognition/fingerspelling_controller.dart';
import 'package:signara/recognition/letter_classifier.dart';
import 'package:signara/recognition/letter_stabilizer.dart';
import 'package:signara/recognition/spelling_buffer.dart';
import 'package:signara_landmarks/signara_landmarks.dart';

class _FakeClassifier implements LetterClassifier {
  _FakeClassifier(this.next);

  LetterPrediction? next;

  @override
  bool get isReady => true;

  @override
  LetterPrediction? classify(List<double> features) => next;
}

LandmarkFrame handFrame() => LandmarkFrame(
      timestampMs: 0,
      inferenceMs: 10,
      hands: [
        HandLandmarks(
          handedness: 'Right',
          xyz: [
            for (var i = 0; i < 21; i++) ...[0.5 + 0.01 * i, 0.5, 0.0],
          ],
        ),
      ],
    );

const LandmarkFrame noHand =
    LandmarkFrame(timestampMs: 0, inferenceMs: 10, hands: []);

void main() {
  group('LetterStabilizer', () {
    LetterStabilizer make() => LetterStabilizer(holdFrames: 3, releaseFrames: 2);

    test('commits only after the letter is held long enough', () {
      final s = make();
      expect(s.update('A', 0.9), isNull);
      expect(s.update('A', 0.9), isNull);
      expect(s.update('A', 0.9), 'A');
    });

    test('does not repeat a held letter', () {
      final s = make();
      for (var i = 0; i < 3; i++) {
        s.update('A', 0.9);
      }
      for (var i = 0; i < 10; i++) {
        expect(s.update('A', 0.9), isNull);
      }
    });

    test('same letter commits again after the hand is released', () {
      final s = make();
      for (var i = 0; i < 3; i++) {
        s.update('L', 0.9);
      }
      s.update(null, 0);
      s.update(null, 0);
      s.update('L', 0.9);
      s.update('L', 0.9);
      expect(s.update('L', 0.9), 'L');
    });

    test('low confidence is ignored', () {
      final s = make();
      for (var i = 0; i < 10; i++) {
        expect(s.update('A', 0.3), isNull);
      }
    });

    test('a different letter restarts the count', () {
      final s = make();
      s.update('A', 0.9);
      s.update('A', 0.9);
      s.update('B', 0.9);
      s.update('B', 0.9);
      expect(s.update('B', 0.9), 'B');
    });
  });

  group('SpellingBuffer', () {
    test('builds words and text', () {
      final b = SpellingBuffer()
        ..addLetter('H')
        ..addLetter('I')
        ..endWord()
        ..addLetter('A');
      expect(b.text, 'HI A');
      expect(b.words, ['HI']);
      expect(b.currentWord, 'A');
    });

    test('backspace reopens the previous word', () {
      final b = SpellingBuffer()
        ..addLetter('H')
        ..addLetter('I')
        ..endWord()
        ..backspace();
      expect(b.currentWord, 'HI');
      expect(b.words, isEmpty);
    });

    test('endWord with no letters does nothing', () {
      final b = SpellingBuffer()..endWord();
      expect(b.isEmpty, isTrue);
    });
  });

  group('SentenceSmoother', () {
    final lexicon = {
      'WHERE': const VocabEntry(
        gloss: 'WHERE',
        category: 'questions',
        en: 'where',
        fil: 'saan',
      ),
      'STORE': const VocabEntry(
        gloss: 'STORE',
        category: 'x',
        en: 'store',
        fil: 'tindahan',
      ),
    };
    final smoother = SentenceSmoother(lexicon: lexicon);

    test('exact template gives a natural sentence in both languages', () {
      expect(smoother.smooth(['CALL', 'POLICE']), 'Please call the police.');
      expect(
        smoother.smooth(['CALL', 'POLICE'], lang: OutputLanguage.fil),
        'Pakitawag po ang pulis.',
      );
    });

    test('unknown sequences fall back to words with punctuation', () {
      expect(smoother.smooth(['WHERE', 'STORE']), 'Where store?');
      expect(
        smoother.smooth(['WHERE', 'STORE'], lang: OutputLanguage.fil),
        'Saan tindahan?',
      );
    });

    test('glosses missing from the lexicon are lowercased', () {
      expect(smoother.smooth(['THANK-YOU', 'FRIEND']), 'Thank you friend.');
    });

    test('empty input gives an empty string', () {
      expect(smoother.smooth([]), '');
    });
  });

  group('FingerspellingController', () {
    test('commits a letter after enough matching frames', () {
      final fake = _FakeClassifier(const LetterPrediction('H', 0.95));
      final c = FingerspellingController(
        classifier: fake,
        stabilizer: LetterStabilizer(holdFrames: 3),
      );
      for (var i = 0; i < 3; i++) {
        c.onFrame(handFrame());
      }
      expect(c.buffer.text, 'H');
    });

    test('ends the word after the hand is gone long enough', () {
      final fake = _FakeClassifier(const LetterPrediction('H', 0.95));
      final c = FingerspellingController(
        classifier: fake,
        stabilizer: LetterStabilizer(holdFrames: 2),
        wordGapFrames: 4,
      );
      c.onFrame(handFrame());
      c.onFrame(handFrame());
      for (var i = 0; i < 4; i++) {
        c.onFrame(noHand);
      }
      expect(c.buffer.words, ['H']);
      expect(c.buffer.currentWord, '');
    });

    test('with no model nothing is committed', () {
      final c = FingerspellingController(classifier: const NoModelClassifier());
      for (var i = 0; i < 20; i++) {
        c.onFrame(handFrame());
      }
      expect(c.buffer.isEmpty, isTrue);
    });
  });
}
