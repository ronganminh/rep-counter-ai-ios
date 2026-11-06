/// Movement demo (plan 07, PR A): a muted looping clip and three cues, on the
/// exercise detail page and in the Train sheet before a workout starts.
/// UI only; the camera, pose detection and rep engine are not involved.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:video_player/video_player.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../data/exercise_guide_clips.dart';

/// Title, clip, the "shown with a barbell" note when the clip only shows a
/// similar movement, and the three cues. Nothing for exercises without a
/// clip (push-up, overhead extension), so their pages stay as they were.
class ExerciseGuideCard extends StatelessWidget {
  const ExerciseGuideCard({super.key, required this.exerciseId});

  final String exerciseId;

  @override
  Widget build(BuildContext context) {
    final clip = ExerciseGuideClip.forExercise(exerciseId);
    if (clip == null) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);
    final cues = clip.cues(l);
    return Column(
      key: Key('guide-card-${clip.appId}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(l.guideClipTitle.toUpperCase(),
              style: AppTypography.caption12.copyWith(
                  color: AppColors.text2,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w800)),
        ),
        const SizedBox(height: 8),
        GuideClipPlayer(clip: clip),
        if (clip.fit == GuideClipFit.similar) ...[
          const SizedBox(height: 8),
          Row(key: const Key('guide-similar-note'), children: [
            const Icon(LucideIcons.info, size: 16, color: AppColors.text2),
            const SizedBox(width: 6),
            Expanded(
                child: Text(l.guideClipBarbellNote,
                    style:
                        AppTypography.body14.copyWith(color: AppColors.text2))),
          ]),
        ],
        const SizedBox(height: 12),
        for (var i = 0; i < cues.length; i++)
          Padding(
            key: Key('guide-cue-$i'),
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(
                width: 24,
                child: Text('${i + 1}',
                    style: AppTypography.label16
                        .copyWith(color: AppColors.accent)),
              ),
              Expanded(
                  child: Text(cues[i],
                      style: AppTypography.body14
                          .copyWith(color: AppColors.text))),
            ]),
          ),
      ],
    );
  }
}

/// Muted, looping clip that never interrupts the user's own audio.
///
/// - Plays by itself, except with reduced motion, where it shows the first
///   frame (poster) and a play button.
/// - Pauses while its route is covered (camera page on top), via
///   [TickerMode], so it never decodes under a live workout.
/// - Any player error leaves the poster: the cues still say everything.
class GuideClipPlayer extends StatefulWidget {
  const GuideClipPlayer({super.key, required this.clip});

  final ExerciseGuideClip clip;

  @override
  State<GuideClipPlayer> createState() => _GuideClipPlayerState();
}

class _GuideClipPlayerState extends State<GuideClipPlayer> {
  VideoPlayerController? _video;
  bool _ready = false;
  bool _failed = false;

  /// What the user (or the autoplay default) wants; the clip actually
  /// plays only while this is true and the route is visible.
  bool _wantsPlay = false;
  bool _decided = false;
  bool _visible = true;
  ValueListenable<TickerModeData>? _tickerMode;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final notifier = TickerMode.getValuesNotifier(context);
    if (notifier != _tickerMode) {
      _tickerMode?.removeListener(_onTickerMode);
      _tickerMode = notifier..addListener(_onTickerMode);
      _visible = notifier.value.enabled;
    }
    if (!_decided) {
      _decided = true;
      if (!MediaQuery.disableAnimationsOf(context)) {
        _wantsPlay = true;
        _open();
      }
    }
  }

  void _onTickerMode() {
    _visible = _tickerMode!.value.enabled;
    _apply();
  }

  void _setWantsPlay(bool value) {
    _wantsPlay = value;
    if (value && _video == null && !_failed) _open();
    _apply();
    setState(() {});
  }

  Future<void> _open() async {
    final video = VideoPlayerController.asset(widget.clip.videoAsset,
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true));
    _video = video;
    try {
      await video.initialize();
      await video.setLooping(true);
      await video.setVolume(0);
    } catch (_) {
      if (identical(_video, video)) _video = null;
      if (mounted) setState(() => _failed = true);
      return;
    }
    if (!mounted || !identical(_video, video)) return;
    setState(() => _ready = true);
    _apply();
  }

  void _apply() {
    final video = _video;
    if (video == null || !_ready) return;
    final play = _wantsPlay && _visible;
    if (play && !video.value.isPlaying) {
      video.play().ignore();
    } else if (!play && video.value.isPlaying) {
      video.pause().ignore();
    }
  }

  @override
  void dispose() {
    _tickerMode?.removeListener(_onTickerMode);
    final video = _video;
    _video = null;
    video?.dispose().ignore();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final clip = widget.clip;
    final video = _video;
    final playing = _wantsPlay && !_failed;
    return ClipRRect(
      key: Key('guide-clip-${clip.appId}'),
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(fit: StackFit.expand, children: [
          Semantics(
            label: clip.semanticLabel(l),
            image: true,
            child: ExcludeSemantics(
              child: Stack(fit: StackFit.expand, children: [
                Image.asset(clip.posterAsset,
                    key: const Key('guide-poster'),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        const ColoredBox(color: AppColors.surface2)),
                if (video != null && _ready)
                  FittedBox(
                    fit: BoxFit.cover,
                    clipBehavior: Clip.hardEdge,
                    child: SizedBox(
                      width: video.value.size.width,
                      height: video.value.size.height,
                      child: VideoPlayer(video),
                    ),
                  ),
              ]),
            ),
          ),
          if (!_failed)
            Positioned(
              right: 4,
              bottom: 4,
              child: IconButton(
                key: const Key('guide-play-toggle'),
                tooltip: playing ? l.guideClipPause : l.guideClipPlay,
                style: IconButton.styleFrom(
                    backgroundColor: AppColors.scrim,
                    foregroundColor: AppColors.text,
                    minimumSize: const Size(48, 48)),
                icon: Icon(playing ? LucideIcons.pause : LucideIcons.play),
                onPressed: () => _setWantsPlay(!_wantsPlay),
              ),
            ),
        ]),
      ),
    );
  }
}
