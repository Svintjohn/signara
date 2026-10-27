import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:signara_landmarks/signara_landmarks.dart';

import '../../core/app_services.dart';
import '../../core/camera_permission.dart';
import '../../recognition/landmark_features.dart';
import '../../recognition/sequence_features.dart';
import '../../recognition/sign_segmenter.dart';

enum _Kind { letters, signs }

/// Record hand samples with the camera. The recognizers (letters by nearest
/// sample, signs by dynamic time warping) learn from what is recorded here.
///
/// CONSENT: record yourself, or people who clearly agreed. Thesis data
/// collection with Deaf signers needs proper consent and, ideally, an ethics
/// review. Samples are only hand landmark numbers (no pictures), stored on
/// this device.
class CollectScreen extends StatefulWidget {
  const CollectScreen({super.key, required this.services});

  final AppServices services;

  @override
  State<CollectScreen> createState() => _CollectScreenState();
}

class _CollectScreenState extends State<CollectScreen> {
  static const int _staticPerRecording = 20;
  static const int _everyNthFrame = 3;

  _Kind _kind = _Kind.letters;
  String? _label;

  int? _textureId;
  String? _error;
  StreamSubscription<LandmarkFrame>? _sub;

  // Letters: collecting a burst of poses.
  bool _collecting = false;
  final List<List<double>> _burst = [];
  int _frameCounter = 0;

  // Signs: armed means "save every sign you make".
  bool _armed = false;
  final SignSegmenter _segmenter = SignSegmenter();
  String _status = 'Start the camera.';

  List<String> get _labels => _kind == _Kind.letters
      ? [
          ...widget.services.vocab.alphabet,
          ...widget.services.vocab.numbers,
        ]
      : [for (final s in widget.services.vocab.signs) s.gloss];

  Future<void> _start() async {
    if (!await ensureCameraPermission()) {
      setState(() => _error = 'Camera permission is required.');
      return;
    }
    try {
      final id = await SignaraLandmarks.start();
      _sub = SignaraLandmarks.frames.listen(_onFrame);
      if (!mounted) return;
      setState(() {
        _textureId = id;
        _error = null;
        _status = 'Camera ready.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not start the camera.\n\n$e');
    }
  }

  Future<void> _stopCamera() async {
    await _sub?.cancel();
    _sub = null;
    await SignaraLandmarks.stop();
    _segmenter.reset();
    if (!mounted) return;
    setState(() {
      _textureId = null;
      _collecting = false;
      _armed = false;
    });
  }

  void _onFrame(LandmarkFrame f) {
    if (!mounted) return;
    final hand = f.hands.isEmpty
        ? null
        : RawHand(f.hands.first.xyz, f.aspect ?? 3 / 4);

    if (_kind == _Kind.letters && _collecting && hand != null) {
      _frameCounter++;
      if (_frameCounter % _everyNthFrame == 0) {
        _burst.add(
          normalizeHand(hand.xyz, aspect: hand.aspect)
              .map((v) => v.toDouble())
              .toList(),
        );
        if (_burst.length >= _staticPerRecording) _finishBurst();
        setState(() {});
      }
    }

    if (_kind == _Kind.signs && _armed && _label != null) {
      final done = _segmenter.update(hand);
      if (done != null) {
        widget.services.samples.addSeq(_label!, buildSequence(done));
        setState(() => _status = 'Saved a sign for $_label.');
      } else if (_segmenter.isRecording) {
        setState(() => _status = 'Recording… ${_segmenter.length} frames');
      }
    }
  }

  void _beginBurst() {
    if (_label == null) return;
    _burst.clear();
    _frameCounter = 0;
    setState(() {
      _collecting = true;
      _status = 'Hold the pose for $_label. Move a little closer/farther…';
    });
  }

  Future<void> _finishBurst() async {
    final label = _label;
    final data = List<List<double>>.of(_burst);
    _burst.clear();
    _collecting = false;
    if (label != null && data.isNotEmpty) {
      await widget.services.samples.addStatic(label, data);
    }
    if (mounted) setState(() => _status = 'Saved ${data.length} poses for $label.');
  }

  Future<void> _export() async {
    await Clipboard.setData(
      ClipboardData(text: widget.services.samples.exportJson()),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied the samples to the clipboard.')),
    );
  }

  Future<void> _import() async {
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Paste exported samples'),
        content: TextField(
          controller: controller,
          maxLines: 6,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('Import'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (text == null || text.trim().isEmpty) return;
    try {
      final n = await widget.services.samples.importJson(text);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Imported $n samples.')));
    } on FormatException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    if (_textureId != null) SignaraLandmarks.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final samples = widget.services.samples;

    return Scaffold(
      appBar: AppBar(title: const Text('Collect samples')),
      body: AnimatedBuilder(
        animation: samples,
        builder: (context, _) {
          final counts = _kind == _Kind.letters
              ? samples.staticCounts
              : samples.seqCounts;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Record yourself, or people who clearly agreed. Only hand '
                  'landmark numbers are saved (no pictures), on this device. '
                  'The more varied the samples (distance, angle, speed), the '
                  'better the recognition.',
                ),
              ),
              const SizedBox(height: 12),
              SegmentedButton<_Kind>(
                segments: const [
                  ButtonSegment(value: _Kind.letters, label: Text('Letters')),
                  ButtonSegment(value: _Kind.signs, label: Text('Signs')),
                ],
                selected: {_kind},
                onSelectionChanged: (s) => setState(() {
                  _kind = s.first;
                  _label = null;
                  _collecting = false;
                  _armed = false;
                  _segmenter.reset();
                }),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _label,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'What are you recording?',
                ),
                items: [
                  for (final l in _labels)
                    DropdownMenuItem(
                      value: l,
                      child: Text('$l  (${counts[l] ?? 0} saved)'),
                    ),
                ],
                onChanged: (v) => setState(() => _label = v),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 260,
                child: Container(
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(_error!, textAlign: TextAlign.center),
                          ),
                        )
                      : _textureId == null
                          ? Center(
                              child: FilledButton.icon(
                                onPressed: _start,
                                icon: const Icon(Icons.videocam),
                                label: const Text('Start camera'),
                              ),
                            )
                          : SignaraLandmarks.buildPreview(_textureId!),
                ),
              ),
              const SizedBox(height: 8),
              Text(_status, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              if (_textureId != null)
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  children: [
                    if (_kind == _Kind.letters)
                      FilledButton(
                        onPressed:
                            _label == null || _collecting ? null : _beginBurst,
                        child: Text(
                          _collecting
                              ? 'Recording ${_burst.length}/$_staticPerRecording'
                              : 'Record $_staticPerRecording poses',
                        ),
                      )
                    else
                      FilledButton(
                        onPressed: _label == null
                            ? null
                            : () => setState(() {
                                  _armed = !_armed;
                                  _segmenter.reset();
                                  _status = _armed
                                      ? 'Armed. Sign, then lower your hand.'
                                      : 'Stopped.';
                                }),
                        child: Text(_armed ? 'Stop recording' : 'Record signs'),
                      ),
                    TextButton(
                      onPressed: _stopCamera,
                      child: const Text('Stop camera'),
                    ),
                  ],
                ),
              const Divider(height: 32),
              Text(
                'Saved (${_kind == _Kind.letters ? 'letters' : 'signs'})',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (counts.isEmpty) const Text('Nothing yet.'),
              for (final e in counts.entries)
                ListTile(
                  dense: true,
                  title: Text(e.key),
                  subtitle: Text('${e.value} samples'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => samples.removeLabel(e.key),
                  ),
                ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _export,
                    icon: const Icon(Icons.copy),
                    label: const Text('Export (copy)'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _import,
                    icon: const Icon(Icons.paste),
                    label: const Text('Import'),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Browser storage is small (a few MB). Export regularly and '
                'keep the file: training on a computer uses it.',
                style: TextStyle(fontSize: 12),
              ),
            ],
          );
        },
      ),
    );
  }
}
