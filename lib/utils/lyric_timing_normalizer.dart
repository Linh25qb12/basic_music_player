import 'dart:math';

import 'package:music_player/models/lyric_word.dart';

const int _minGapBetweenWordStartsMs = 48;

List<LyricWord> normalizeLyricWordTimings(
  List<LyricWord> words, {
  required int? nextLineStartMs,
}) {
  if (words.isEmpty) return words;

  final n = words.length;
  if (n == 1) {
    final t0 = words.first.start.inMilliseconds;
    return [words.first.copyWith(start: Duration(milliseconds: t0))];
  }

  final ms = List<int>.generate(n, (i) => words[i].start.inMilliseconds);

  _splitEqualTimestampRuns(ms, nextLineStartMs);
  _enforceNonDecreasing(ms);
  _enforceMinGap(ms, _minGapBetweenWordStartsMs);

  if (nextLineStartMs != null && ms.last >= nextLineStartMs) {
    _compressToUpperBound(ms, nextLineStartMs - 1);
    _enforceMinGap(ms, _minGapBetweenWordStartsMs);
    _enforceNonDecreasing(ms);
    if (ms.last >= nextLineStartMs) {
      ms[n - 1] = nextLineStartMs - 1;
      for (var k = n - 2; k >= 0; k--) {
        final cap = ms[k + 1] - _minGapBetweenWordStartsMs;
        if (ms[k] > cap) ms[k] = max(0, cap);
      }
      _enforceNonDecreasing(ms);
    }
  }

  return List<LyricWord>.generate(
    n,
    (i) => words[i].copyWith(start: Duration(milliseconds: ms[i])),
  );
}

void _splitEqualTimestampRuns(List<int> ms, int? nextLineStartMs) {
  var i = 0;
  while (i < ms.length) {
    var j = i + 1;
    while (j < ms.length && ms[j] == ms[i]) {
      j++;
    }
    if (j - i > 1) {
      final nextBoundary =
          j < ms.length ? ms[j] : (nextLineStartMs ?? ms[i] + 900);
      final span = max(1, nextBoundary - ms[i]);
      final count = j - i;
      for (var k = 0; k < count; k++) {
        ms[i + k] = ms[i] + ((span * k) / count).round();
      }
    }
    i = j;
  }
}

void _enforceNonDecreasing(List<int> ms) {
  for (var k = 1; k < ms.length; k++) {
    if (ms[k] < ms[k - 1]) {
      ms[k] = ms[k - 1];
    }
  }
}

void _enforceMinGap(List<int> ms, int minGapMs) {
  for (var k = 1; k < ms.length; k++) {
    final minNext = ms[k - 1] + minGapMs;
    if (ms[k] < minNext) {
      ms[k] = minNext;
    }
  }
}

void _compressToUpperBound(List<int> ms, int upperMs) {
  final lo = ms.first;
  final hi = ms.last;
  if (hi <= lo || upperMs <= lo) return;
  if (hi <= upperMs) return;

  final scale = (upperMs - lo) / (hi - lo);
  for (var k = 1; k < ms.length; k++) {
    ms[k] = lo + ((ms[k] - lo) * scale).round();
  }
}
