import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Pairs of landmark indices that are joined by a "bone" (MediaPipe layout).
const List<List<int>> handBones = [
  [0, 1], [1, 2], [2, 3], [3, 4], // thumb
  [0, 5], [5, 6], [6, 7], [7, 8], // index
  [5, 9], [9, 10], [10, 11], [11, 12], // middle
  [9, 13], [13, 14], [14, 15], [15, 16], // ring
  [13, 17], [17, 18], [18, 19], [19, 20], // pinky
  [0, 17], // palm edge
];

/// 21 points for one frame. The frame is the 60 hand-shape features (wrist
/// is the origin) and optionally 2 more numbers: the wrist's movement since
/// the start of the sign. Image y goes down, so fingers point to negative y.
List<Offset> skeletonPoints(List<double> f) {
  final shiftX = f.length >= 62 ? f[60] : 0.0;
  final shiftY = f.length >= 62 ? f[61] : 0.0;
  return [
    Offset(shiftX, shiftY), // wrist
    for (var i = 1; i <= 20; i++)
      Offset(f[(i - 1) * 3] + shiftX, f[(i - 1) * 3 + 1] + shiftY),
  ];
}

/// Smallest rectangle that holds every point of every frame, so the picture
/// does not jump around while the sign plays.
Rect skeletonBounds(List<List<double>> frames) {
  var minX = double.infinity;
  var minY = double.infinity;
  var maxX = -double.infinity;
  var maxY = -double.infinity;
  for (final f in frames) {
    for (final p in skeletonPoints(f)) {
      minX = math.min(minX, p.dx);
      minY = math.min(minY, p.dy);
      maxX = math.max(maxX, p.dx);
      maxY = math.max(maxY, p.dy);
    }
  }
  if (minX.isInfinite) return const Rect.fromLTWH(-1, -1, 2, 2);
  return Rect.fromLTRB(minX, minY, maxX, maxY);
}

/// Plays a recorded sign as a moving hand skeleton: a stand-in for a video or
/// avatar until real reference clips exist. A single frame is shown as a still
/// pose.
class HandSkeletonPlayer extends StatefulWidget {
  const HandSkeletonPlayer({
    super.key,
    required this.frames,
    this.color,
    this.duration = const Duration(milliseconds: 1600),
  });

  final List<List<double>> frames;
  final Color? color;
  final Duration duration;

  @override
  State<HandSkeletonPlayer> createState() => _HandSkeletonPlayerState();
}

class _HandSkeletonPlayerState extends State<HandSkeletonPlayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late Rect _bounds;

  @override
  void initState() {
    super.initState();
    _bounds = skeletonBounds(widget.frames);
    _c = AnimationController(vsync: this, duration: widget.duration);
    if (widget.frames.length > 1) _c.repeat();
  }

  @override
  void didUpdateWidget(covariant HandSkeletonPlayer old) {
    super.didUpdateWidget(old);
    if (!identical(old.frames, widget.frames)) {
      _bounds = skeletonBounds(widget.frames);
      if (widget.frames.length > 1) {
        _c.repeat();
      } else {
        _c.stop();
      }
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? const Color(0xFFFFB300);
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final n = widget.frames.length;
        final index = n <= 1 ? 0 : math.min(n - 1, (_c.value * n).floor());
        return CustomPaint(
          size: Size.infinite,
          painter: _SkeletonPainter(widget.frames[index], _bounds, color),
        );
      },
    );
  }
}

class _SkeletonPainter extends CustomPainter {
  _SkeletonPainter(this.frame, this.bounds, this.color);

  final List<double> frame;
  final Rect bounds;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final bw = math.max(bounds.width, 0.01);
    final bh = math.max(bounds.height, 0.01);
    final scale = math.min(size.width / bw, size.height / bh) * 0.85;
    final cx = bounds.center.dx;
    final cy = bounds.center.dy;

    Offset map(Offset p) => Offset(
          size.width / 2 + (p.dx - cx) * scale,
          size.height / 2 + (p.dy - cy) * scale,
        );

    final pts = skeletonPoints(frame).map(map).toList();
    final bone = Paint()
      ..color = color
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (final b in handBones) {
      canvas.drawLine(pts[b[0]], pts[b[1]], bone);
    }
    final dot = Paint()..color = color;
    for (final p in pts) {
      canvas.drawCircle(p, 4, dot);
    }
  }

  @override
  bool shouldRepaint(covariant _SkeletonPainter old) =>
      old.frame != frame || old.bounds != bounds || old.color != color;
}
