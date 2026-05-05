import 'dart:math';

import 'package:characters/characters.dart';

import 'lyric_character.dart';

class LyricWord {
  LyricWord({required this.text, required this.start});

  final String text;
  final Duration start;
  late Duration end;

  LyricWord copyWith({String? text, Duration? start}) {
    return LyricWord(text: text ?? this.text, start: start ?? this.start);
  }

  final List<LyricCharacter> _chars = [];
  List<String> get characters =>
      _chars.map((char) => char.value).toList(growable: false);

  void finalizeCharacters() {
    _chars.clear();
    final characters = text.characters.toList(growable: false);
    if (characters.isEmpty) return;

    final startMs = start.inMilliseconds;
    final endMs = end.inMilliseconds;
    final totalMs = max(1, endMs - startMs);
    final n = characters.length;

    final weights = characters.map(_characterWeight).toList();
    final totalUnits = weights.fold<double>(0, (a, b) => a + b);

    final edge = List<int>.filled(n + 1, 0);
    if (totalUnits <= 0) {
      for (var i = 1; i <= n; i++) {
        edge[i] = ((totalMs * i) / n).round();
      }
    } else {
      for (var i = 1; i <= n; i++) {
        final cum = weights.sublist(0, i).fold<double>(0, (a, b) => a + b);
        edge[i] = (totalMs * cum / totalUnits).round();
      }
    }
    edge[n] = totalMs;

    for (var i = 1; i <= n; i++) {
      edge[i] = edge[i].clamp(0, totalMs);
      if (edge[i] < edge[i - 1]) {
        edge[i] = edge[i - 1];
      }
    }
    edge[n] = totalMs;

    for (var i = 0; i < n; i++) {
      final charStartMs = startMs + edge[i];
      final charEndMs = startMs + edge[i + 1];
      _chars.add(
        LyricCharacter(
          value: characters[i],
          start: Duration(milliseconds: charStartMs),
          end: Duration(milliseconds: max(charStartMs + 1, charEndMs)),
        ),
      );
    }
  }

  double _characterWeight(String char) {
    if (RegExp(r'\s').hasMatch(char)) return 0.35;
    if (RegExp("[.,!?;:()\\[\\]{}\"'`~-]").hasMatch(char)) return 0.45;
    return 1.0;
  }

  double progressAt(Duration now) {
    if (now <= start) return 0;
    if (now >= end) return 1;
    final span = end - start;
    if (span.inMilliseconds == 0) return 1;
    return (now - start).inMilliseconds / span.inMilliseconds;
  }

  double characterProgressByIndex(
    Duration now,
    int index, {
    required bool smooth,
  }) {
    if (index < 0 || index >= _chars.length) return 0;
    final item = _chars[index];
    if (!smooth) {
      return now >= item.start ? 1 : 0;
    }
    if (now <= item.start) return 0;
    if (now >= item.end) return 1;
    final span = item.end - item.start;
    if (span.inMilliseconds == 0) return 1;
    final raw = (now - item.start).inMilliseconds / span.inMilliseconds;

    return raw.clamp(0.0, 1.0);
  }
}
