import 'dart:async';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:signara_landmarks/signara_landmarks.dart';

/// Week-1 spike: prove camera -> MediaPipe hand landmarks -> Flutter UI runs
/// fast enough on a cheap Android phone. Pass target: >= 15 fps.
class SpikeScreen extends StatefulWidget {
  const SpikeScreen({super.key});

  @override
  State<SpikeScreen> createState() => _SpikeScreenState();
}

class _SpikeScreenState extends State<SpikeScreen> {
  int? _textureId;
  String? _error;
  bool _front = false;

  StreamSubscription<LandmarkFrame>? _sub;
  LandmarkFrame? _last;

  // Rolling one-second window for fps and latency.
  final List<int> _arrivalsMs = [];
  final List<int> _latenciesMs = [];
  double _fps = 0;
  double _avgLatency = 0;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      setState(() => _error = 'Camera permission is required.');
      return;
    }
    try {
      final id = await SignaraLandmarks.start(front: _front);
      _sub = SignaraLandmarks.frames.listen(_onFrame);
      if (!mounted) return;
      setState(() {
        _textureId = id;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not start camera pipeline: $e');
    }
  }

  void _onFrame(LandmarkFrame f) {
    final now = DateTime.now().millisecondsSinceEpoch;
    _arrivalsMs.add(now);
    _latenciesMs.add(f.inferenceMs);
    _arrivalsMs.removeWhere((t) => now - t > 1000);
    while (_latenciesMs.length > _arrivalsMs.length) {
      _latenciesMs.removeAt(0);
    }
    if (!mounted) return;
    setState(() {
      _last = f;
      _fps = _arrivalsMs.length.toDouble();
      _avgLatency = _latenciesMs.isEmpty
          ? 0
          : _latenciesMs.reduce((a, b) => a + b) / _latenciesMs.length;
    });
  }

  Future<void> _stop() async {
    await _sub?.cancel();
    _sub = null;
    await SignaraLandmarks.stop();
  }

  Future<void> _toggleCamera() async {
    await _stop();
    setState(() {
      _front = !_front;
      _textureId = null;
    });
    await _start();
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pass = _fps >= 15;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Spike: camera → landmarks'),
        actions: [
          IconButton(
            onPressed: _toggleCamera,
            icon: const Icon(Icons.cameraswitch),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _error != null
                ? Center(child: Text(_error!))
                : _textureId == null
                    ? const Center(child: CircularProgressIndicator())
                    : Center(
                        child: AspectRatio(
                          // Portrait preview. Adjust if the plugin reports
                          // a different size.
                          aspectRatio: 3 / 4,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Texture(textureId: _textureId!),
                              CustomPaint(
                                painter: _HandsPainter(
                                  _last?.hands ?? const [],
                                  mirror: _front,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'FPS: ${_fps.toStringAsFixed(0)}   '
              'Latency: ${_avgLatency.toStringAsFixed(0)} ms   '
              'Hands: ${_last?.hands.length ?? 0}\n'
              '${pass ? "PASS (>= 15 fps)" : "Below target (15 fps)"}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _HandsPainter extends CustomPainter {
  _HandsPainter(this.hands, {required this.mirror});

  final List<HandLandmarks> hands;
  final bool mirror;

  @override
  void paint(Canvas canvas, Size size) {
    final dot = Paint()..color = const Color(0xFFFFB300);
    for (final h in hands) {
      for (var i = 0; i + 2 < h.xyz.length; i += 3) {
        var x = h.xyz[i];
        if (mirror) x = 1 - x;
        canvas.drawCircle(
          Offset(x * size.width, h.xyz[i + 1] * size.height),
          4,
          dot,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _HandsPainter old) => true;
}
