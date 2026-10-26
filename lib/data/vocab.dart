import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

class VocabEntry {
  const VocabEntry({
    required this.gloss,
    required this.category,
    required this.en,
    required this.fil,
  });

  factory VocabEntry.fromJson(Map<String, dynamic> json) => VocabEntry(
        gloss: json['gloss'] as String,
        category: json['category'] as String,
        en: json['en'] as String,
        fil: json['fil'] as String,
      );

  final String gloss;
  final String category;
  final String en;
  final String fil;
}

class Vocab {
  const Vocab({
    required this.alphabet,
    required this.numbers,
    required this.signs,
  });

  final List<String> alphabet;
  final List<String> numbers;
  final List<VocabEntry> signs;

  Map<String, List<VocabEntry>> get byCategory {
    final map = <String, List<VocabEntry>>{};
    for (final s in signs) {
      map.putIfAbsent(s.category, () => []).add(s);
    }
    return map;
  }

  static Future<Vocab> load() async {
    final raw = await rootBundle.loadString('assets/vocab/vocab_v0.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return Vocab(
      alphabet: (json['alphabet'] as List).cast<String>(),
      numbers: (json['numbers'] as List).cast<String>(),
      signs: (json['signs'] as List)
          .map((e) => VocabEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
