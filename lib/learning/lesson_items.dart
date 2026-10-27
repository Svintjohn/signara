import '../data/vocab.dart';

/// One flashcard. Ids look like `sign:HELP`, `letter:A`, `number:3`.
class LessonItem {
  const LessonItem({
    required this.id,
    required this.title,
    required this.en,
    required this.fil,
    this.letter,
  });

  final String id;
  final String title;
  final String en;
  final String fil;

  /// Set for letters that can be practiced with the camera.
  final String? letter;

  static List<String> idsForCategory(Vocab v, String category) => [
        for (final s in v.signs)
          if (s.category == category) 'sign:${s.gloss}',
      ];

  static List<String> fingerspellingIds(Vocab v) => [
        for (final l in v.alphabet) 'letter:$l',
        for (final n in v.numbers) 'number:$n',
      ];

  static List<String> allIds(Vocab v) => [
        ...fingerspellingIds(v),
        for (final s in v.signs) 'sign:${s.gloss}',
      ];

  static LessonItem? fromId(Vocab v, String id) {
    final i = id.indexOf(':');
    if (i < 0) return null;
    final kind = id.substring(0, i);
    final value = id.substring(i + 1);

    switch (kind) {
      case 'letter':
        return LessonItem(
          id: id,
          title: value,
          en: 'The letter $value',
          fil: 'Ang letrang $value',
          letter: value,
        );
      case 'number':
        return LessonItem(
          id: id,
          title: value,
          en: 'The number $value',
          fil: 'Ang numerong $value',
        );
      case 'sign':
        for (final s in v.signs) {
          if (s.gloss == value) {
            return LessonItem(id: id, title: s.gloss, en: s.en, fil: s.fil);
          }
        }
        return null;
      default:
        return null;
    }
  }
}
