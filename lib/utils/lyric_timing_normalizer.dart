import 'dart:math';

import 'package:music_player/models/lyric_word.dart';

const int _clusterThresholdMs = 80;

const int _minStartGapMs = 110;

const int _minWordDurationMs = 180;

List<LyricWord> normalizeLyricWordTimings(
  List<LyricWord> words, {
  required int? nextLineStartMs,
}) {
  if (words.isEmpty) return words;
  final n = words.length;
  if (n == 1) return List<LyricWord>.from(words);

  final starts = List<int>.generate(n, (i) => words[i].start.inMilliseconds);
  final weights = List<double>.generate(n, (i) => _wordWeight(words[i].text));

  // 1) Phat hien va giai cac cluster.
  var i = 0;
  while (i < n) {
    var j = i + 1;
    while (j < n && starts[j] - starts[j - 1] <= _clusterThresholdMs) {
      j++;
    }

    if (j - i > 1) {
      _redistributeCluster(
        starts: starts,
        weights: weights,
        clusterStart: i,
        clusterEnd: j,
        nextRealStartMs: j < n ? starts[j] : nextLineStartMs,
      );
    }
    i = j;
  }

  // 2) Bao dam non-decreasing.
  for (var k = 1; k < n; k++) {
    if (starts[k] < starts[k - 1]) {
      starts[k] = starts[k - 1];
    }
  }

  // 3) Bao dam khoang cach toi thieu giua hai start lien tiep.
  for (var k = 1; k < n; k++) {
    final minNext = starts[k - 1] + _minStartGapMs;
    if (starts[k] < minNext) {
      starts[k] = minNext;
    }
  }

  // 4) Cap theo dau dong sau, day lui ve neu vuot.
  if (nextLineStartMs != null && starts[n - 1] >= nextLineStartMs) {
    starts[n - 1] = max(starts[0], nextLineStartMs - 1);
    for (var k = n - 2; k >= 0; k--) {
      final upperCap = starts[k + 1] - _minStartGapMs;
      if (starts[k] > upperCap) {
        starts[k] = max(0, upperCap);
      }
    }
    for (var k = 1; k < n; k++) {
      if (starts[k] < starts[k - 1]) {
        starts[k] = starts[k - 1];
      }
    }
  }

  return List<LyricWord>.generate(
    n,
    (k) => words[k].copyWith(start: Duration(milliseconds: starts[k])),
  );
}

void _redistributeCluster({
  required List<int> starts,
  required List<double> weights,
  required int clusterStart,
  required int clusterEnd,
  required int? nextRealStartMs,
}) {
  final size = clusterEnd - clusterStart;
  final clusterAnchor = starts[clusterStart];

  // Diem ket cum: hoac dau cua tu thuc su tiep theo,
  // hoac dau dong sau, hoac fallback theo so tu.
  final desiredEnd =
      nextRealStartMs ?? clusterAnchor + _minWordDurationMs * size;

  // Bao dam khoang du dai de chua het cum.
  final span = max(_minWordDurationMs * size, desiredEnd - clusterAnchor);

  var totalWeight = 0.0;
  for (var k = clusterStart; k < clusterEnd; k++) {
    totalWeight += weights[k];
  }

  var cursor = clusterAnchor;
  for (var k = clusterStart; k < clusterEnd; k++) {
    starts[k] = cursor;
    final share =
        totalWeight > 0
            ? (span * (weights[k] / totalWeight)).round()
            : (span / size).round();
    cursor += max(_minWordDurationMs, share);
  }
}

double _wordWeight(String text) {
  // Trong so dua tren so ky tu co nghia (loai khoang trang).
  // Tu dai hon -> giu thoi gian tu mau lau hon.
  var count = 0.0;
  for (final code in text.runes) {
    final ch = String.fromCharCode(code);
    if (RegExp(r'\s').hasMatch(ch)) continue;
    count += 1;
  }
  return max(1.0, count);
}
