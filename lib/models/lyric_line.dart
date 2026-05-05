import 'lyric_word.dart';

class LyricLine {
  LyricLine({required this.words});

  final List<LyricWord> words;
  late Duration start;
  late Duration end;

  void finalizeTimeline(LyricLine? nextLine) {
    start = words.first.start;
    for (var i = 0; i < words.length; i++) {
      final current = words[i];

      final nextStartInLine =
          i + 1 < words.length ? words[i + 1].start : null;
      final fallbackEnd = nextLine != null
          ? nextLine.words.first.start
          : current.start + const Duration(milliseconds: 900);
      final targetEnd = nextStartInLine ?? fallbackEnd;
      current.end = targetEnd > current.start
          ? targetEnd
          : current.start + const Duration(milliseconds: 180);
      current.finalizeCharacters();
    }
    end = words.last.end;
  }

  double progressAt(Duration now) {
    if (now <= start) return 0;
    if (now >= end) return 1;
    final span = end - start;
    if (span.inMilliseconds == 0) return 1;
    return (now - start).inMilliseconds / span.inMilliseconds;
  }
}
