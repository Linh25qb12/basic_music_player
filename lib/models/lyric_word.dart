import 'dart:math';

import 'package:flutter/material.dart';

import 'lyric_character.dart';

class LyricWord {
  LyricWord({required this.text, required this.start});

  final String text;
  final Duration start;
  late Duration end;
  final List<LyricCharacter> _chars = [];
  List<String> get characters =>
      _chars.map((char) => char.value).toList(growable: false);

  void finalizeCharacters() {
    _chars.clear();
    final characters = text.characters.toList(growable: false);
    if (characters.isEmpty) return;

    final totalMs = max(1, (end - start).inMilliseconds);
    final totalUnits = characters.fold<double>(
      0,
      (sum, char) => sum + _characterWeight(char),
    );
    var cursorMs = start.inMilliseconds;

    for (var i = 0; i < characters.length; i++) {
      final char = characters[i];
      final isLast = i == characters.length - 1;
      final unitRatio = totalUnits == 0
          ? 1 / characters.length
          : _characterWeight(char) / totalUnits;
      var charSliceMs =
          isLast ? (end.inMilliseconds - cursorMs) : (totalMs * unitRatio).round();
      charSliceMs = max(16, charSliceMs);
      final charStartMs = cursorMs;
      final charEndMs = isLast
          ? end.inMilliseconds
          : min(end.inMilliseconds, charStartMs + charSliceMs);
      _chars.add(
        LyricCharacter(
          value: char,
          start: Duration(milliseconds: charStartMs),
          end: Duration(milliseconds: max(charStartMs + 1, charEndMs)),
        ),
      );
      cursorMs = max(charStartMs + 1, charEndMs);
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

  double characterProgressByIndex(Duration now, int index, {required bool smooth}) {
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
    return Curves.easeInOutCubic.transform(raw.clamp(0.0, 1.0));
  }
}
