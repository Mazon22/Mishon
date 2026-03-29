import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import 'package:mishon_app/core/localization/app_strings.dart';
import 'package:mishon_app/core/utils/voice_note_utils.dart';

class VoiceMessageBubble extends StatefulWidget {
  final String fileName;
  final int sizeBytes;
  final bool isMine;
  final Duration duration;
  final String? audioUrl;
  final Widget? footer;
  final bool isPending;
  final double? uploadProgress;
  final VoidCallback? onTap;

  const VoiceMessageBubble({
    super.key,
    required this.fileName,
    required this.sizeBytes,
    required this.isMine,
    required this.duration,
    this.audioUrl,
    this.footer,
    this.isPending = false,
    this.uploadProgress,
    this.onTap,
  });

  @override
  State<VoiceMessageBubble> createState() => _VoiceMessageBubbleState();
}

class _VoiceMessageBubbleState extends State<VoiceMessageBubble> {
  AudioPlayer? _player;
  StreamSubscription<PlayerState>? _playerStateSubscription;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration?>? _durationSubscription;

  bool _isPrepared = false;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _resolvedDuration = Duration.zero;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _resolvedDuration = widget.duration;
  }

  Future<AudioPlayer> _ensurePlayer() async {
    final existingPlayer = _player;
    if (existingPlayer != null) {
      return existingPlayer;
    }

    final player = AudioPlayer();
    _player = player;

    _playerStateSubscription = player.playerStateStream.listen((state) {
      if (!mounted) {
        return;
      }
      if (state.processingState == ProcessingState.completed) {
        unawaited(_resetAfterCompletion());
        return;
      }
      setState(() {
        _isPlaying = state.playing;
      });
    });

    _positionSubscription = player.positionStream.listen((position) {
      if (!mounted) {
        return;
      }
      setState(() {
        _position = position;
      });
    });

    _durationSubscription = player.durationStream.listen((duration) {
      if (!mounted || duration == null) {
        return;
      }
      setState(() {
        _resolvedDuration = duration;
      });
    });

    return player;
  }

  @override
  void didUpdateWidget(covariant VoiceMessageBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.audioUrl != widget.audioUrl ||
        oldWidget.fileName != widget.fileName ||
        oldWidget.sizeBytes != widget.sizeBytes) {
      _resetPlayer();
      _resolvedDuration = widget.duration;
    }
  }

  @override
  void dispose() {
    unawaited(_playerStateSubscription?.cancel());
    unawaited(_positionSubscription?.cancel());
    unawaited(_durationSubscription?.cancel());
    unawaited(_player?.dispose());
    super.dispose();
  }

  Future<void> _resetPlayer() async {
    final player = _player;
    if (player == null) {
      _isPrepared = false;
      _isPlaying = false;
      _position = Duration.zero;
      return;
    }

    _isPrepared = false;
    _isPlaying = false;
    _position = Duration.zero;
    await player.stop();
    await player.seek(Duration.zero);
  }

  Future<void> _resetAfterCompletion() async {
    if (!mounted) {
      return;
    }

    final player = _player;
    setState(() {
      _isPlaying = false;
      _position = Duration.zero;
    });

    try {
      if (player != null) {
        await player.stop();
        await player.seek(Duration.zero);
      }
      _isPrepared = true;
    } catch (_) {
      _isPrepared = false;
    }
  }

  Future<void> _togglePlayback() async {
    if (widget.audioUrl == null || widget.isPending) {
      widget.onTap?.call();
      return;
    }

    final player = await _ensurePlayer();

    if (!_isPrepared) {
      try {
        await player.setAudioSource(
          AudioSource.uri(Uri.parse(widget.audioUrl!)),
        );
        _isPrepared = true;
      } catch (_) {
        if (!mounted) {
          return;
        }
        setState(() {
          _errorMessage = 'Unable to load audio';
        });
        return;
      }
    }

    if (player.playing) {
      await player.pause();
    } else {
      await player.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final progress =
        widget.uploadProgress != null
            ? widget.uploadProgress!.clamp(0, 1).toDouble()
            : (_resolvedDuration.inMilliseconds <= 0
                ? 0.0
                : (_position.inMilliseconds / _resolvedDuration.inMilliseconds)
                    .clamp(0, 1)
                    .toDouble());

    final bubbleColor =
        widget.isMine
            ? const Color(0xFF2F67FF)
            : const Color(0xFFF5F8FE);
    final textColor =
        widget.isMine ? Colors.white : const Color(0xFF20304A);
    final secondaryColor =
        widget.isMine ? Colors.white70 : const Color(0xFF66758F);
    final accentColor =
        widget.isMine ? Colors.white : const Color(0xFF2F67FF);
    final bars = _buildBars(widget.fileName);
    final durationLabel = formatDurationLabel(_resolvedDuration);

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Material(
        color: bubbleColor,
        child: InkWell(
          onTap: widget.isPending ? null : _togglePlayback,
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildPlayButton(accentColor, textColor),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  strings.isRu
                                      ? 'Голосовое сообщение'
                                      : 'Voice message',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.bodyMedium?.copyWith(
                                    color: textColor,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                durationLabel,
                                style: Theme.of(
                                  context,
                                ).textTheme.bodySmall?.copyWith(
                                  color: secondaryColor,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 9),
                          SizedBox(
                            height: 26,
                            child: _VoiceBars(
                              bars: bars,
                              progress: progress,
                              isMine: widget.isMine,
                              isPlaying: _isPlaying,
                              pending: widget.isPending,
                            ),
                          ),
                          if (_errorMessage != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              _errorMessage!,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color:
                                        widget.isMine
                                            ? Colors.white70
                                            : const Color(0xFFD14E5B),
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.isPending && widget.uploadProgress != null)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(20),
                    ),
                    child: LinearProgressIndicator(
                      value: widget.uploadProgress!.clamp(0, 1).toDouble(),
                      minHeight: 3,
                      backgroundColor: Colors.white.withValues(alpha: 0.20),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        widget.isMine
                            ? Colors.white
                            : const Color(0xFF2F67FF),
                      ),
                    ),
                  ),
                ),
              if (widget.footer != null) widget.footer!,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlayButton(Color accentColor, Color iconColor) {
    final icon =
        widget.isPending
            ? Icons.mic_rounded
            : _isPlaying
            ? Icons.pause_rounded
            : Icons.play_arrow_rounded;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color:
            widget.isMine
                ? Colors.white.withValues(alpha: 0.14)
                : accentColor.withValues(alpha: 0.10),
        shape: BoxShape.circle,
        border: Border.all(
          color:
              widget.isMine
                  ? Colors.white.withValues(alpha: 0.12)
                  : accentColor.withValues(alpha: 0.14),
        ),
      ),
      child: Icon(icon, color: iconColor, size: 22),
    );
  }

  List<double> _buildBars(String seedSource) {
    final seed = seedSource.hashCode ^ widget.sizeBytes;
    final random = math.Random(seed);
    return List<double>.generate(
      24,
      (index) => 0.38 + (random.nextDouble() * 0.62),
    );
  }
}

class _VoiceBars extends StatelessWidget {
  final List<double> bars;
  final double progress;
  final bool isMine;
  final bool isPlaying;
  final bool pending;

  const _VoiceBars({
    required this.bars,
    required this.progress,
    required this.isMine,
    required this.isPlaying,
    required this.pending,
  });

  @override
  Widget build(BuildContext context) {
    final barColor =
        pending
            ? (isMine
                ? Colors.white.withValues(alpha: 0.55)
                : const Color(0xFF2F67FF).withValues(alpha: 0.42))
            : isMine
            ? Colors.white
            : const Color(0xFF2F67FF);
    final inactiveColor =
        pending
            ? (isMine
                ? Colors.white.withValues(alpha: 0.18)
                : const Color(0xFF2F67FF).withValues(alpha: 0.12))
            : isMine
            ? Colors.white.withValues(alpha: 0.28)
            : const Color(0xFF2F67FF).withValues(alpha: 0.16);

    return Row(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final availableWidth = constraints.maxWidth;
              final barCount = bars.length;
              final totalGap = 2.0 * (barCount - 1);
              final barWidth = math.max(
                2.4,
                (availableWidth - totalGap) / barCount,
              );
              return Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(barCount, (index) {
                  final fill = progress * barCount;
                  final active = isPlaying || pending ? index <= fill : false;
                  return Padding(
                    padding: EdgeInsets.only(right: index == barCount - 1 ? 0 : 2),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      width: barWidth,
                      height: 16 * bars[index],
                      decoration: BoxDecoration(
                        color: active ? barColor : inactiveColor,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  );
                }),
              );
            },
          ),
        ),
      ],
    );
  }
}
