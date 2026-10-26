/// Turns noisy per-frame predictions into committed letters.
///
/// A letter is committed only after it is seen with enough confidence for
/// [holdFrames] frames in a row. After committing, the same letter will not
/// commit again until the hand is released (no hand or low confidence for
/// [releaseFrames] frames) or a different letter is committed. This is how
/// double letters such as the L L in "HELLO" work: drop the hand briefly
/// between them.
class LetterStabilizer {
  LetterStabilizer({
    this.holdFrames = 8,
    this.minConfidence = 0.7,
    this.releaseFrames = 3,
  });

  final int holdFrames;
  final double minConfidence;
  final int releaseFrames;

  String? _candidate;
  int _count = 0;
  String? _lastCommitted;
  int _invalidRun = 0;

  /// Call once per frame. [letter] is null when no hand was found.
  /// Returns the letter when it gets committed, otherwise null.
  String? update(String? letter, double confidence) {
    final valid = letter != null && confidence >= minConfidence;

    if (!valid) {
      _candidate = null;
      _count = 0;
      _invalidRun++;
      if (_invalidRun >= releaseFrames) _lastCommitted = null;
      return null;
    }

    _invalidRun = 0;

    if (letter == _lastCommitted) {
      // Still holding the letter that was just committed.
      _candidate = null;
      _count = 0;
      return null;
    }

    if (letter != _candidate) {
      _candidate = letter;
      _count = 1;
    } else {
      _count++;
    }

    if (_count >= holdFrames) {
      _lastCommitted = letter;
      _candidate = null;
      _count = 0;
      return letter;
    }
    return null;
  }

  /// The letter currently being held but not yet committed (for UI feedback).
  String? get candidate => _candidate;

  /// 0..1 progress towards committing [candidate].
  double get progress => _candidate == null ? 0 : _count / holdFrames;

  void reset() {
    _candidate = null;
    _count = 0;
    _lastCommitted = null;
    _invalidRun = 0;
  }
}
