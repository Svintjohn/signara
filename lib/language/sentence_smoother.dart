import '../data/vocab.dart';

enum OutputLanguage { en, fil }

class _Template {
  const _Template(this.glosses, this.en, this.fil);

  final List<String> glosses;
  final String en;
  final String fil;
}

/// Rule-based gloss -> sentence. This is the OFFLINE fallback. An LLM can
/// replace it when the phone is online; state both in the thesis.
///
/// Limits (be honest about them): only exact template matches get a natural
/// sentence. Everything else becomes a plain word-by-word line, which is
/// understandable but not grammatical. Wording needs review by Deaf signers
/// and Filipino speakers.
class SentenceSmoother {
  SentenceSmoother({required Map<String, VocabEntry> lexicon})
      : _lexicon = lexicon;

  final Map<String, VocabEntry> _lexicon;

  static const _questionGlosses = {
    'WHAT',
    'WHERE',
    'WHO',
    'WHEN',
    'WHY',
    'HOW',
    'HOW-MUCH',
  };

  static const List<_Template> _templates = [
    _Template(['HELP'], 'I need help.', 'Kailangan ko po ng tulong.'),
    _Template(['HELLO'], 'Hello.', 'Kumusta po.'),
    _Template(['THANK-YOU'], 'Thank you.', 'Salamat po.'),
    _Template(['SORRY'], 'I am sorry.', 'Pasensya na po.'),
    _Template(
      ['CALL', 'POLICE'],
      'Please call the police.',
      'Pakitawag po ang pulis.',
    ),
    _Template(
      ['CALL', 'DOCTOR'],
      'Please call a doctor.',
      'Pakitawag po ang doktor.',
    ),
    _Template(
      ['PAIN', 'HEAD'],
      'My head hurts.',
      'Masakit po ang ulo ko.',
    ),
    _Template(
      ['PAIN', 'STOMACH'],
      'My stomach hurts.',
      'Masakit po ang tiyan ko.',
    ),
    _Template(
      ['WHERE', 'HOSPITAL'],
      'Where is the hospital?',
      'Nasaan po ang ospital?',
    ),
    _Template(
      ['WHAT', 'NAME'],
      'What is your name?',
      'Ano po ang pangalan ninyo?',
    ),
    _Template(
      ['UNDERSTAND', 'NO'],
      'I do not understand.',
      'Hindi ko po naiintindihan.',
    ),
    _Template(
      ['REPEAT', 'PLEASE'],
      'Please repeat that.',
      'Pakiulit po.',
    ),
  ];

  String smooth(List<String> glosses, {OutputLanguage lang = OutputLanguage.en}) {
    if (glosses.isEmpty) return '';

    for (final t in _templates) {
      if (_sameList(t.glosses, glosses)) {
        return lang == OutputLanguage.en ? t.en : t.fil;
      }
    }

    final words = glosses.map((g) {
      final entry = _lexicon[g];
      if (entry != null) return lang == OutputLanguage.en ? entry.en : entry.fil;
      return g.toLowerCase().replaceAll('-', ' ');
    }).join(' ');

    final capitalized = words[0].toUpperCase() + words.substring(1);
    final ending = _questionGlosses.contains(glosses.first) ? '?' : '.';
    return '$capitalized$ending';
  }

  static bool _sameList(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
