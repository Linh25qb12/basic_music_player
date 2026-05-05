import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:music_player/constants/media_urls.dart';
import 'package:music_player/models/lyric_line.dart';
import 'package:music_player/models/lyric_word.dart';
import 'package:music_player/utils/lyric_timing_normalizer.dart';
import 'package:xml/xml.dart';

class LyricsRepository {
  Future<List<LyricLine>> fetchLyrics() async {
    final response = await http.get(Uri.parse(MediaUrls.lyricsXml));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Loi tai lyrics: ${response.statusCode}');
    }

    final xmlText = _decodeLyricsXml(response.bodyBytes);
    final xml = XmlDocument.parse(xmlText);
    final params = xml.findAllElements('param');
    final parsed = <LyricLine>[];

    for (final param in params) {
      final words = <LyricWord>[];
      for (final item in param.findElements('i')) {
        final startSeconds = double.tryParse(item.getAttribute('va') ?? '');
        if (startSeconds == null) continue;
        words.add(
          LyricWord(
            text: item.innerText,
            start: Duration(milliseconds: (startSeconds * 1000).round()),
          ),
        );
      }
      if (words.isNotEmpty) parsed.add(LyricLine(words: words));
    }

    for (var index = 0; index < parsed.length; index++) {
      final current = parsed[index];
      final nextLine = index + 1 < parsed.length ? parsed[index + 1] : null;
      final nextFirstMs =
          nextLine?.words.isNotEmpty == true
              ? nextLine!.words.first.start.inMilliseconds
              : null;
      final fixed = normalizeLyricWordTimings(
        List<LyricWord>.from(current.words),
        nextLineStartMs: nextFirstMs,
      );
      final updated = LyricLine(words: fixed);
      updated.finalizeTimeline(nextLine);
      parsed[index] = updated;
    }
    return parsed;
  }

  String _decodeLyricsXml(List<int> bodyBytes) {
    try {
      return utf8.decode(bodyBytes);
    } catch (_) {
      return utf8.decode(bodyBytes, allowMalformed: true);
    }
  }
}
