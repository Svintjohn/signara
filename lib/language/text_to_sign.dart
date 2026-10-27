import '../data/vocab.dart';

/// One word from the typed text: either a known sign or something to spell.
class PlannedItem {
  const PlannedItem.sign(this.source, String this.gloss) : letters = const [];
  const PlannedItem.spell(this.source, this.letters) : gloss = null;

  final String source;
  final String? gloss;
  final List<String> letters;

  bool get isSign => gloss != null;
}

/// Text -> sequence of signs and fingerspelled words. Word-for-word on
/// purpose: real ASL grammar and word order are different, so this is a
/// vocabulary lookup, not a translation. Say so in the UI and the thesis.
class TextToSignPlanner {
  TextToSignPlanner(Vocab vocab) {
    for (final e in vocab.signs) {
      for (final key in {
        _clean(e.en),
        _clean(e.fil),
        _clean(e.gloss.replaceAll('-', ' ')),
      }) {
        if (key.isEmpty) continue;
        _map.putIfAbsent(key, () => e.gloss);
        final n = key.split(' ').length;
        if (n > _maxWords) _maxWords = n;
      }
    }
  }

  final Map<String, String> _map = {};
  int _maxWords = 1;

  static final RegExp _junk = RegExp(r"[^a-z0-9ñ' ]");

  static String _clean(String s) => s
      .toLowerCase()
      .replaceAll('-', ' ')
      .replaceAll(_junk, ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  List<PlannedItem> plan(String text) {
    final words = _clean(text).isEmpty ? <String>[] : _clean(text).split(' ');
    final out = <PlannedItem>[];

    var i = 0;
    while (i < words.length) {
      PlannedItem? found;
      var used = 1;

      final maxN = _maxWords < words.length - i ? _maxWords : words.length - i;
      for (var n = maxN; n >= 1; n--) {
        final phrase = words.sublist(i, i + n).join(' ');
        final gloss = _map[phrase];
        if (gloss != null) {
          found = PlannedItem.sign(phrase, gloss);
          used = n;
          break;
        }
      }

      if (found == null) {
        final letters = <String>[
          for (final ch in words[i].split(''))
            if (RegExp(r'[a-z0-9]').hasMatch(ch)) ch.toUpperCase()
            else if (ch == 'ñ') 'N',
        ];
        if (letters.isNotEmpty) found = PlannedItem.spell(words[i], letters);
      }

      if (found != null) out.add(found);
      i += used;
    }
    return out;
  }

  /// Flat list of things to show one after another: a gloss for a sign, or
  /// one letter at a time for fingerspelled words.
  static List<String> units(List<PlannedItem> items) => [
        for (final it in items)
          if (it.isSign) it.gloss! else ...it.letters,
      ];
}
