/// The letters spelled so far, plus finished words.
class SpellingBuffer {
  final List<String> _letters = [];
  final List<String> _words = [];

  String get currentWord => _letters.join();
  List<String> get words => List.unmodifiable(_words);

  /// Finished words plus the one in progress, e.g. "JOHN SMI".
  String get text {
    final parts = [..._words, if (_letters.isNotEmpty) currentWord];
    return parts.join(' ');
  }

  bool get isEmpty => _letters.isEmpty && _words.isEmpty;

  void addLetter(String letter) => _letters.add(letter);

  void backspace() {
    if (_letters.isNotEmpty) {
      _letters.removeLast();
    } else if (_words.isNotEmpty) {
      // Reopen the last finished word so it can be corrected.
      _letters.addAll(_words.removeLast().split(''));
    }
  }

  /// Ends the current word (a space). Does nothing if there is no word.
  void endWord() {
    if (_letters.isEmpty) return;
    _words.add(currentWord);
    _letters.clear();
  }

  void clear() {
    _letters.clear();
    _words.clear();
  }
}
