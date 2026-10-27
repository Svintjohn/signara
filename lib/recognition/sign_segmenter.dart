import 'sequence_features.dart';

/// Cuts the camera stream into signs: a sign starts when a hand appears and
/// ends when the hand has been gone for [endGapFrames] frames (or after
/// [maxFrames]). Blips shorter than [minFrames] are thrown away.
///
/// So the signer has to lower their hands between signs. That is a limit of
/// this prototype, not of sign language.
class SignSegmenter {
  SignSegmenter({
    this.minFrames = 10,
    this.maxFrames = 90,
    this.endGapFrames = 8,
  });

  final int minFrames;
  final int maxFrames;
  final int endGapFrames;

  final List<RawHand> _buffer = [];
  int _gap = 0;

  bool get isRecording => _buffer.isNotEmpty;
  int get length => _buffer.length;

  /// Call once per frame with the first hand, or null when none is visible.
  /// Returns a finished sign when one just ended, otherwise null.
  List<RawHand>? update(RawHand? hand) {
    if (hand != null) {
      _gap = 0;
      _buffer.add(hand);
      if (_buffer.length >= maxFrames) return _take();
      return null;
    }

    if (_buffer.isEmpty) return null;
    _gap++;
    if (_gap < endGapFrames) return null;

    final done = _take();
    return done.length >= minFrames ? done : null;
  }

  List<RawHand> _take() {
    final out = List<RawHand>.of(_buffer);
    _buffer.clear();
    _gap = 0;
    return out;
  }

  void reset() {
    _buffer.clear();
    _gap = 0;
  }
}
