import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../core/streak_service.dart';

/// One recorded hand pose (60 features) for a letter or number.
class StaticSample {
  const StaticSample(this.label, this.features);

  final String label;
  final List<double> features;
}

/// One recorded sign: a sequence of frames (62 numbers each) for a gloss.
class SeqSample {
  const SeqSample(this.gloss, this.frames);

  final String gloss;
  final List<List<double>> frames;
}

double _r(double v) => (v * 10000).roundToDouble() / 10000;

/// Samples recorded with the camera on THIS device. They are the data the
/// recognizers learn from. Stored locally; export/import is manual.
///
/// Only record yourself, or people who agreed to it. A real data collection
/// for the thesis needs consent forms and Deaf signers.
class SampleStore extends ChangeNotifier {
  SampleStore(this._store);

  final KeyValueStore _store;
  static const _key = 'samples_v1';

  final List<StaticSample> statics = [];
  final List<SeqSample> seqs = [];

  /// Goes up on every change, so users of the data can tell when to rebuild.
  int revision = 0;

  Future<void> load() async {
    final raw = await _store.getString(_key);
    if (raw == null) return;
    try {
      _read(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      // Unreadable data: start empty rather than crash the app.
      statics.clear();
      seqs.clear();
    }
    revision++;
  }

  /// Adds the samples from a decoded export. Returns how many were added.
  int _read(Map<String, dynamic> m) {
    var added = 0;
    for (final e in (m['static'] as List? ?? const [])) {
      final map = e as Map<String, dynamic>;
      statics.add(StaticSample(
        map['l'] as String,
        (map['f'] as List).map((v) => (v as num).toDouble()).toList(),
      ));
      added++;
    }
    for (final e in (m['seq'] as List? ?? const [])) {
      final map = e as Map<String, dynamic>;
      seqs.add(SeqSample(
        map['g'] as String,
        (map['f'] as List)
            .map((fr) =>
                (fr as List).map((v) => (v as num).toDouble()).toList())
            .toList(),
      ));
      added++;
    }
    return added;
  }

  Map<String, dynamic> _toMap() => {
        'version': 1,
        'static': [
          for (final s in statics)
            {'l': s.label, 'f': s.features.map(_r).toList()},
        ],
        'seq': [
          for (final s in seqs)
            {
              'g': s.gloss,
              'f': [for (final fr in s.frames) fr.map(_r).toList()],
            },
        ],
      };

  Future<void> _changed() async {
    revision++;
    await _store.setString(_key, jsonEncode(_toMap()));
    notifyListeners();
  }

  Future<void> addStatic(String label, List<List<double>> features) async {
    for (final f in features) {
      statics.add(StaticSample(label, f));
    }
    await _changed();
  }

  Future<void> addSeq(String gloss, List<List<double>> frames) async {
    seqs.add(SeqSample(gloss, frames));
    await _changed();
  }

  Future<void> removeLabel(String label) async {
    statics.removeWhere((s) => s.label == label);
    seqs.removeWhere((s) => s.gloss == label);
    await _changed();
  }

  Future<void> clear() async {
    statics.clear();
    seqs.clear();
    await _changed();
  }

  Map<String, int> get staticCounts {
    final out = <String, int>{};
    for (final s in statics) {
      out[s.label] = (out[s.label] ?? 0) + 1;
    }
    return out;
  }

  Map<String, int> get seqCounts {
    final out = <String, int>{};
    for (final s in seqs) {
      out[s.gloss] = (out[s.gloss] ?? 0) + 1;
    }
    return out;
  }

  /// Frames to show as the reference for [label] (a sign gloss, letter or
  /// number), or null if nothing was recorded.
  List<List<double>>? referenceFor(String label) {
    for (final s in seqs) {
      if (s.gloss == label) return s.frames;
    }
    for (final s in statics) {
      if (s.label == label) return [s.features];
    }
    return null;
  }

  String exportJson() => jsonEncode(_toMap());

  /// Adds samples from text made by [exportJson]. Throws [FormatException]
  /// if the text is not a valid export.
  Future<int> importJson(String text) async {
    final Map<String, dynamic> m;
    try {
      m = jsonDecode(text) as Map<String, dynamic>;
    } catch (_) {
      throw const FormatException('Not a Signara samples export.');
    }
    final beforeS = statics.length;
    final beforeQ = seqs.length;
    try {
      final added = _read(m);
      await _changed();
      return added;
    } catch (_) {
      // Roll back a half-read import.
      statics.removeRange(beforeS, statics.length);
      seqs.removeRange(beforeQ, seqs.length);
      throw const FormatException('Samples export is damaged.');
    }
  }
}
