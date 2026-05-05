import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:music_player/constants/media_urls.dart';
import 'package:music_player/data/lyrics_repository.dart';
import 'package:music_player/models/lyric_line.dart';
import 'package:music_player/models/lyric_word.dart';
import 'package:music_player/widgets/vinyl_disc.dart';

class KaraokePlayerPage extends StatefulWidget {
  const KaraokePlayerPage({super.key});

  @override
  State<KaraokePlayerPage> createState() => _KaraokePlayerPageState();
}

class _KaraokePlayerPageState extends State<KaraokePlayerPage>
    with SingleTickerProviderStateMixin {
  static const double _lyricFontSize = 16;
  static const Color _lyricBaseCharColor = Color(0xFFB8C5D6);
  static const Duration _lyricLineSwitchDuration = Duration(milliseconds: 640);

  final AudioPlayer _player = AudioPlayer();
  final LyricsRepository _lyricsRepository = LyricsRepository();
  late final AnimationController _discRotationController;

  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration?>? _durationSub;
  StreamSubscription<PlayerState>? _stateSub;

  late final ValueNotifier<Duration> _positionNotifier;
  Duration _duration = Duration.zero;
  bool _isPlaying = false;
  bool _isLoading = true;
  bool _isSeeking = false;
  double _seekingSeconds = 0;
  String? _error;

  List<LyricLine> _lines = const [];

  @override
  void initState() {
    super.initState();
    _positionNotifier = ValueNotifier(Duration.zero);
    _discRotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    );
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      await _player.setUrl(MediaUrls.beatMp3);
      _duration = _player.duration ?? Duration.zero;
      _lines = await _lyricsRepository.fetchLyrics();

      _durationSub = _player.durationStream.listen((value) {
        if (!mounted || value == null) return;
        setState(() => _duration = value);
      });

      _positionSub = _player
          .createPositionStream(
            steps: 900,
            minPeriod: const Duration(milliseconds: 20),
            maxPeriod: const Duration(milliseconds: 40),
          )
          .listen((value) {
            if (!mounted) return;
            if (_isSeeking) return;
            _positionNotifier.value = value;
          });

      _stateSub = _player.playerStateStream.listen((value) {
        if (!mounted) return;
        setState(() => _isPlaying = value.playing);
        final spin =
            value.playing && value.processingState != ProcessingState.completed;
        if (spin) {
          _discRotationController.repeat();
        } else {
          _discRotationController.stop();
        }
      });
    } catch (e) {
      _error = 'Khong the tai du lieu: $e';
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  int _findCurrentLineIndex(Duration at) {
    for (var i = 0; i < _lines.length; i++) {
      final line = _lines[i];
      if (at >= line.start && at < line.end) {
        return i;
      }
    }
    return -1;
  }

  Future<void> _togglePlayStop() async {
    if (_isPlaying) {
      await _player.pause();
    } else {
      await _player.play();
    }
  }

  Future<void> _seekTo(double seconds) async {
    final position = Duration(milliseconds: (seconds * 1000).round());
    await _player.seek(position);
    _positionNotifier.value = position;
  }

  Future<void> _seekRelative(Duration delta) async {
    final durMs = _duration.inMilliseconds;
    final nextMs =
        _positionNotifier.value.inMilliseconds + delta.inMilliseconds;
    final ms = durMs > 0 ? nextMs.clamp(0, durMs) : max(0, nextMs);
    _positionNotifier.value = Duration(milliseconds: ms);
    await _seekTo(ms / 1000);
  }

  Future<void> _replayFromStart() async {
    await _player.seek(Duration.zero);
    _positionNotifier.value = Duration.zero;
    await _player.play();
  }

  void _onSeekStart(double value) {
    setState(() {
      _isSeeking = true;
      _seekingSeconds = value;
    });
  }

  void _onSeekChanged(double value) {
    if (!_isSeeking) return;
    setState(() => _seekingSeconds = value);
  }

  Future<void> _onSeekEnd(double value) async {
    final target = Duration(milliseconds: (value * 1000).round());
    setState(() {
      _isSeeking = false;
      _seekingSeconds = 0;
    });
    _positionNotifier.value = target;
    await _seekTo(value);
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _durationSub?.cancel();
    _stateSub?.cancel();
    _positionNotifier.dispose();
    _discRotationController.dispose();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child:
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_error!, textAlign: TextAlign.center),
                  ),
                )
                : LayoutBuilder(
                  builder: (context, constraints) {
                    final discVisualSize = min(
                      240.0,
                      constraints.maxWidth * 0.56,
                    );

                    return Container(
                      width: double.infinity,
                      height: double.infinity,
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF7E93F2), Color(0xFFE8B1D7)],
                        ),
                      ),
                      child: Column(
                        children: [
                          _buildSongHeader(),
                          const SizedBox(height: 16),
                          Expanded(
                            flex: 6,
                            child: Center(
                              child: VinylDisc(
                                rotationController: _discRotationController,
                                size: discVisualSize,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 4,
                            child: LayoutBuilder(
                              builder: (context, lc) {
                                return ValueListenableBuilder<Duration>(
                                  valueListenable: _positionNotifier,
                                  builder: (context, audioPos, _) {
                                    final lyricTime =
                                        _isSeeking
                                            ? Duration(
                                              milliseconds:
                                                  (_seekingSeconds * 1000)
                                                      .round(),
                                            )
                                            : audioPos;
                                    return Center(
                                      child: _buildLyricPreview(
                                        lyricTime,
                                        lc.maxWidth,
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                          ValueListenableBuilder<Duration>(
                            valueListenable: _positionNotifier,
                            builder: (context, audioPos, _) {
                              return _buildPlayerPanel(audioPos);
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
      ),
    );
  }

  Widget _buildSongHeader() {
    return const Align(
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Về đâu mái tóc người thương',
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF1F2937),
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 2),
          Text(
            'Quang Lê',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLyricPreview(Duration lyricTime, double maxWidth) {
    final active = _findCurrentLineIndex(lyricTime);
    final current =
        active >= 0 && active < _lines.length ? _lines[active] : null;
    final next =
        active + 1 >= 0 && active + 1 < _lines.length
            ? _lines[active + 1]
            : null;
    const currentLyricStyle = TextStyle(
      color: _lyricBaseCharColor,
      fontSize: _lyricFontSize,
      fontWeight: FontWeight.w700,
      height: 1.2,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _PushingLyricLineSwitcher(
          duration: _lyricLineSwitchDuration,
          lineKey: active,
          slidePixels: 22,
          verticalGap: _lyricFontSize * 0.9,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: _lyricFontSize * 1.35),
            child:
                current == null
                    ? SizedBox(
                      width: maxWidth,
                      child: Center(
                        child: Text('...', style: currentLyricStyle),
                      ),
                    )
                    : DefaultTextStyle(
                      style: currentLyricStyle,
                      child: SizedBox(
                        width: maxWidth,
                        child: Wrap(
                          alignment: WrapAlignment.center,
                          runAlignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 6,
                          runSpacing: 6,
                          children:
                              current.words
                                  .map(
                                    (word) => _buildWordByCharacter(
                                      word,
                                      currentLyricStyle,
                                      lyricTime,
                                    ),
                                  )
                                  .toList(),
                        ),
                      ),
                    ),
          ),
        ),
        const SizedBox(height: 4),
        _PushingLyricLineSwitcher(
          duration: _lyricLineSwitchDuration,
          lineKey: 'next_${active}_${next?.start.inMilliseconds ?? -1}',
          slidePixels: 18,
          verticalGap: _lyricFontSize * 0.75,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: _lyricFontSize * 1.35),
            child: SizedBox(
              width: maxWidth,
              child: Text(
                next == null ? '' : next.words.map((word) => word.text).join(),
                textAlign: TextAlign.center,
                softWrap: true,
                style: const TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: _lyricFontSize,
                  fontWeight: FontWeight.w500,
                  height: 1.2,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlayerPanel(Duration audioPosition) {
    final durationSeconds =
        _duration.inMilliseconds <= 0 ? 1.0 : _duration.inMilliseconds / 1000;
    final currentSeconds = ((_isSeeking
            ? _seekingSeconds
            : audioPosition.inMilliseconds / 1000))
        .clamp(0.0, durationSeconds);
    final sliderSeconds =
        _isSeeking
            ? _seekingSeconds.clamp(0.0, durationSeconds)
            : currentSeconds;
    final displayPosition = Duration(
      milliseconds: (sliderSeconds * 1000).round(),
    );

    const iconInk = Color(0xFF111827);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 46,
                child: Text(
                  _formatDuration(displayPosition),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              Expanded(
                child: Slider(
                  value: sliderSeconds,
                  min: 0,
                  max: durationSeconds,
                  onChangeStart: _onSeekStart,
                  onChanged: _onSeekChanged,
                  onChangeEnd: _onSeekEnd,
                ),
              ),
              SizedBox(
                width: 46,
                child: Text(
                  _formatDuration(_duration),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: () {},
                tooltip: 'Shuffle',
                icon: const Icon(
                  Icons.shuffle,
                  color: Colors.white54,
                  size: 18,
                ),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
              IconButton(
                onPressed: () => _seekRelative(const Duration(seconds: -10)),
                tooltip: 'Lui 10s',
                icon: const Icon(
                  Icons.replay_10_rounded,
                  color: iconInk,
                  size: 28,
                ),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              ),
              InkWell(
                onTap: _togglePlayStop,
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: iconInk,
                  ),
                  child: Icon(
                    _isPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => _seekRelative(const Duration(seconds: 10)),
                tooltip: 'Toi 10s',
                icon: const Icon(
                  Icons.forward_10_rounded,
                  color: iconInk,
                  size: 28,
                ),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              ),
              IconButton(
                onPressed: _replayFromStart,
                tooltip: 'Phat lai tu dau',
                icon: const Icon(Icons.replay, color: Colors.white70, size: 22),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWordByCharacter(
    LyricWord word,
    TextStyle textStyle,
    Duration now,
  ) {
    final fragments =
        word.characters
            .asMap()
            .entries
            .map(
              (entry) => _buildCharacterFragment(
                entry.key,
                entry.value,
                word,
                now,
                textStyle,
              ),
            )
            .toList();
    return Wrap(
      spacing: 0,
      runSpacing: 0,
      alignment: WrapAlignment.start,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: fragments,
    );
  }

  Widget _buildCharacterFragment(
    int charIndex,
    String char,
    LyricWord word,
    Duration now,
    TextStyle textStyle,
  ) {
    final progress = word.characterProgressByIndex(
      now,
      charIndex,
      smooth: true,
    );
    return _buildProgressText(
      content: char,
      progress: progress,
      textStyle: textStyle,
    );
  }

  Widget _buildProgressText({
    required String content,
    required double progress,
    required TextStyle textStyle,
  }) {
    return Stack(
      children: [
        Text(
          content,
          style: textStyle.copyWith(
            color: _lyricBaseCharColor,
            decoration: TextDecoration.none,
          ),
        ),
        ClipRect(
          child: Align(
            alignment: Alignment.centerLeft,
            widthFactor: progress.clamp(0.0, 1.0),
            child: Text(
              content,
              style: textStyle.copyWith(
                decoration: TextDecoration.none,
                shadows: const [
                  Shadow(
                    color: Color(0xE6FFFFFF),
                    blurRadius: 3,
                    offset: Offset(0, 0),
                  ),
                  Shadow(
                    color: Color(0x4D000000),
                    blurRadius: 0,
                    offset: Offset(0, 1),
                  ),
                ],
                foreground:
                    Paint()
                      ..shader = const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF0F172A), Color(0xFF0C4A6E)],
                      ).createShader(const Rect.fromLTWH(0, 0, 220, 40)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration value) {
    final totalSeconds = value.inSeconds;
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

class _PushingLyricLineSwitcher extends StatefulWidget {
  const _PushingLyricLineSwitcher({
    required this.duration,
    required this.lineKey,
    required this.child,
    this.slidePixels = 20,
    this.verticalGap = 14,
  });

  final Duration duration;
  final Object lineKey;
  final Widget child;
  final double slidePixels;

  final double verticalGap;

  @override
  State<_PushingLyricLineSwitcher> createState() =>
      _PushingLyricLineSwitcherState();
}

class _PushingLyricLineSwitcherState extends State<_PushingLyricLineSwitcher>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Widget? _incoming;
  Widget? _outgoing;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _incoming = widget.child;
    _controller.value = 1;
    _controller.addStatusListener(_onAnimStatus);
  }

  void _onAnimStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && mounted) {
      setState(() => _outgoing = null);
    }
  }

  @override
  void didUpdateWidget(_PushingLyricLineSwitcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.duration != oldWidget.duration) {
      _controller.duration = widget.duration;
    }
    if (widget.lineKey != oldWidget.lineKey) {
      _outgoing = _incoming;
      _incoming = widget.child;
      _controller.forward(from: 0);
    } else {
      _incoming = widget.child;
    }
  }

  @override
  void dispose() {
    _controller.removeStatusListener(_onAnimStatus);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = Curves.easeInOutCubic.transform(_controller.value);
        final outOpacity = pow(1.0 - t, 1.35).toDouble().clamp(0.0, 1.0);
        final inOpacity = t.clamp(0.0, 1.0);
        final travel = widget.verticalGap + widget.slidePixels;

        return Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            if (_outgoing != null && outOpacity > 0.001)
              Opacity(
                opacity: outOpacity,
                child: Transform.translate(
                  offset: Offset(0, -travel * t),
                  child: _outgoing!,
                ),
              ),
            Opacity(
              opacity: inOpacity,
              child: Transform.translate(
                offset: Offset(0, travel * (1.0 - t)),
                child: _incoming!,
              ),
            ),
          ],
        );
      },
    );
  }
}
