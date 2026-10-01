import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/i18n/locale_controller.dart';
import '../../../../placement.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_typography.dart';
import '../../../../widgets/product_ui.dart';
import '../../application/workout_ui_state.dart';
import 'rep_feedback_pill.dart';

String workoutTime(Duration time) =>
    '${(time.inSeconds ~/ 60).toString().padLeft(2, '0')}:${(time.inSeconds % 60).toString().padLeft(2, '0')}';

class WorkoutHud extends StatelessWidget {
  const WorkoutHud(
      {super.key,
      required this.state,
      required this.exerciseName,
      required this.hint,
      required this.onExit,
      required this.onPause,
      required this.onResume,
      required this.onFinish,
      required this.onCalibrate,
      required this.onHelp,
      required this.goalBanner,
      required this.onDismissGoal,
      this.diagnosticAction,
      this.onStart,
      this.voiceEnabled = true,
      this.onToggleVoice,
      this.challengeBestReps});
  final WorkoutUiState state;
  final String exerciseName, hint;
  final VoidCallback onExit,
      onPause,
      onResume,
      onFinish,
      onCalibrate,
      onHelp,
      onDismissGoal;
  final bool goalBanner;
  final Widget? diagnosticAction;
  final VoidCallback? onStart, onToggleVoice;
  final bool voiceEnabled;
  final int? challengeBestReps;
  @override
  Widget build(BuildContext context) {
    final paused = state.phase == WorkoutUiPhase.paused;
    if (state.isTimedChallenge &&
        state.sessionStarted &&
        state.countdown == null &&
        !state.isCalibrating) {
      return _TimedChallengeHud(
        state: state,
        exerciseName: exerciseName,
        voiceEnabled: voiceEnabled,
        challengeBestReps: challengeBestReps,
        diagnosticAction: diagnosticAction,
        onToggleVoice: onToggleVoice,
        onExit: onExit,
        onPause: onPause,
        onResume: onResume,
        onFinish: onFinish,
      );
    }
    final positioning = !state.sessionStarted && !state.isCalibrating;
    final color = state.placementReady ? AppColors.success : AppColors.warning;
    return LayoutBuilder(
        builder: (context, box) => Column(children: [
              if (state.goal != null)
                Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                    child: LinearProgressIndicator(
                        value: state.goalProgress,
                        minHeight: 4,
                        color: state.goalReachedOnce
                            ? AppColors.success
                            : AppColors.accent,
                        borderRadius: BorderRadius.circular(4))),
              Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 8, 0),
                  child: Row(children: [
                    Flexible(
                        child: _Glass(
                            child:
                                Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(LucideIcons.shieldCheck,
                          size: 15, color: AppColors.success),
                      const SizedBox(width: 6),
                      Flexible(
                          child: Text(context.tr('Xử lý trên máy', 'On-device'),
                              style: const TextStyle(fontSize: 12))),
                    ]))),
                    const Spacer(),
                    IconButton(
                        key: const Key('toggle-workout-voice'),
                        tooltip: context.tr(
                            voiceEnabled ? 'Tắt giọng đọc' : 'Bật giọng đọc',
                            voiceEnabled ? 'Mute voice' : 'Enable voice'),
                        onPressed: onToggleVoice,
                        icon: Icon(voiceEnabled
                            ? LucideIcons.volume2
                            : LucideIcons.volumeX)),
                    if (diagnosticAction != null) diagnosticAction!,
                    if (!paused &&
                        !positioning &&
                        !state.isCalibrating &&
                        state.countdown == null)
                      IconButton(
                          tooltip: context.s.hudCalibrateShort,
                          onPressed: onCalibrate,
                          icon: const Icon(LucideIcons.slidersHorizontal)),
                    IconButton(
                        tooltip: context.s.hudHelp,
                        onPressed: onHelp,
                        icon: const Icon(LucideIcons.circleHelp)),
                    IconButton(
                        tooltip: context.tr('Đóng', 'Close'),
                        onPressed: onExit,
                        icon: const Icon(LucideIcons.x)),
                  ])),
              Expanded(
                  child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(children: [
                        const SizedBox(height: 12),
                        Text(
                            '${workoutTime(state.elapsed)} · ${context.tr('Set', 'Set')} ${state.completedSets + 1} · $exerciseName',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: AppColors.text2, fontSize: 14)),
                        if (paused) ...[
                          const SizedBox(height: 20),
                          _Glass(
                              child: Text(context.tr('Đã tạm dừng', 'Paused'))),
                        ],
                        if (state.countdown != null) ...[
                          const SizedBox(height: 32),
                          Semantics(
                              liveRegion: !voiceEnabled,
                              label: '${state.countdown}',
                              child: ExcludeSemantics(
                                  child: Text('${state.countdown}',
                                      key: const Key('countdown-number'),
                                      textScaler: TextScaler.noScaling,
                                      style: AppTypography.hero.copyWith(
                                          fontSize: 240,
                                          color: AppColors.accent)))),
                          const SizedBox(height: 24),
                          Text(context.tr('Giữ tư thế', 'Hold your position'),
                              style: AppTypography.title20),
                          const SizedBox(height: 12),
                          Text(
                              context.tr('Chưa tính rep và thời gian tập',
                                  'Reps and workout time have not started'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: AppColors.text2)),
                        ] else if (state.isCalibrating) ...[
                          const SizedBox(height: 20),
                          Text(
                              context.tr('Làm vài rep tự nhiên',
                                  'Move through a few natural reps'),
                              textAlign: TextAlign.center,
                              style: AppTypography.display40),
                          const SizedBox(height: 12),
                          Text(
                              context.tr(
                                  '${state.calibrationSamples} mẫu đã thu',
                                  '${state.calibrationSamples} samples collected'),
                              style: const TextStyle(color: AppColors.accent)),
                          const SizedBox(height: 12),
                          Text(
                              context.tr(
                                  'Khi đã lên xuống đủ biên độ, bấm hoàn tất hiệu chỉnh.',
                                  'After moving through your full range, finish calibration.'),
                              textAlign: TextAlign.center),
                          const SizedBox(height: 12),
                          FilledButton(
                              onPressed: onCalibrate,
                              child: Text(context.s.hudCalibrateStop)),
                          const SizedBox(height: 12),
                          Text(
                              context.tr(
                                  'Rep hiệu chỉnh không tính vào buổi tập.',
                                  'Calibration reps do not count toward the workout.'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: AppColors.text2)),
                        ] else if (positioning && !paused) ...[
                          const SizedBox(height: 24),
                          Text(context.tr('VÀO VỊ TRÍ', 'GET IN POSITION'),
                              textAlign: TextAlign.center,
                              style: AppTypography.display40),
                          const SizedBox(height: 16),
                          Text(
                              context.tr(
                                  'Đặt máy theo hướng dẫn. Khi tư thế ổn định, app đếm ngược 3–2–1.',
                                  'Position the camera as shown. Once your pose is stable, the app counts down 3–2–1.'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: AppColors.text2)),
                          const SizedBox(height: 20),
                          if (!state.startRequested)
                            FilledButton(
                                onPressed: onStart,
                                key: const Key('start-countdown'),
                                child: Text(context.tr('Vào vị trí & bắt đầu',
                                    'Get ready & start')))
                          else
                            Text(
                                context.tr('Đang chờ tư thế ổn định…',
                                    'Waiting for a stable pose…'),
                                style:
                                    const TextStyle(color: AppColors.accent)),
                        ] else ...[
                          Semantics(
                              label: '${state.reps} ${context.s.repsShort}',
                              liveRegion: !voiceEnabled,
                              child: ExcludeSemantics(
                                  child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.baseline,
                                          textBaseline: TextBaseline.alphabetic,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text('${state.reps}',
                                                textScaler:
                                                    TextScaler.noScaling,
                                                style: AppTypography.hero.copyWith(
                                                    fontSize:
                                                        paused ? 120 : 190,
                                                    color: paused ||
                                                            state.placementReady
                                                        ? AppColors.accent
                                                        : AppColors.text3)),
                                            if (state.goal != null)
                                              Text(' / ${state.goal}',
                                                  style: AppTypography.display40
                                                      .copyWith(
                                                          color:
                                                              AppColors.text2)),
                                          ])))),
                          const SizedBox(height: 12),
                          Text(
                              state.goal == null
                                  ? context.s.hudReps
                                  : state.reps > state.goal!
                                      ? context.tr(
                                          '+${state.reps - state.goal!} vượt mục tiêu',
                                          '+${state.reps - state.goal!} over goal')
                                      : context.tr(
                                          'Còn ${(state.goal! - state.reps).clamp(0, state.goal!)}',
                                          '${(state.goal! - state.reps).clamp(0, state.goal!)} remaining'),
                              style: const TextStyle(
                                  fontSize: 18, color: AppColors.text2)),
                        ],
                        if (!paused &&
                            !positioning &&
                            !state.isCalibrating &&
                            state.countdown == null) ...[
                          const SizedBox(height: 18),
                          RepFeedbackTransition(
                              feedback: state.repFeedback),
                        ],
                        const SizedBox(height: 20),
                        if (paused) ...[
                          FilledButton.icon(
                              key: const Key('resume-workout'),
                              onPressed: onResume,
                              icon: const Icon(LucideIcons.play),
                              label: Text(context.tr('TIẾP TỤC', 'RESUME'))),
                          const SizedBox(height: 12),
                          OutlinedButton(
                              onPressed: onFinish,
                              style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.dangerText),
                              child: Text(context.tr(
                                  'Kết thúc buổi tập', 'Finish workout'))),
                          const SizedBox(height: 16),
                          Text(
                              context.tr(
                                  'Đồng hồ và bộ đếm đã dừng. Tự lưu sau 5 phút.',
                                  'Timer and counting are paused. Saves after 5 minutes.'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: AppColors.text2, fontSize: 13)),
                        ] else if (state.countdown == null) ...[
                          _Glass(
                              color: color.withValues(alpha: .15),
                              child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                        state.placementReady
                                            ? LucideIcons.circleCheck
                                            : LucideIcons.scanLine,
                                        color: color,
                                        size: 20),
                                    const SizedBox(width: 8),
                                    Flexible(
                                        child: Text(
                                            state.placementStatus
                                                .message(context.s),
                                            style: TextStyle(
                                                color: color,
                                                fontWeight: FontWeight.w600))),
                                  ])),
                          if (!state.placementReady &&
                              state.placementMessage.isNotEmpty)
                            Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Text(state.placementMessage,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                        color: AppColors.text2))),
                          if (positioning) ...[
                            const SizedBox(height: 10),
                            Text(hint,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    fontSize: 13, color: AppColors.text2)),
                            TextButton.icon(
                                onPressed: onCalibrate,
                                icon: const Icon(LucideIcons.slidersHorizontal,
                                    size: 18),
                                label: Text(context.s.hudCalibrateShort)),
                          ],
                          if (goalBanner)
                            Padding(
                                padding: const EdgeInsets.only(top: 16),
                                child: _Glass(
                                    color: AppColors.surface,
                                    child: Column(children: [
                                      const Icon(LucideIcons.circleCheck,
                                          color: AppColors.success, size: 32),
                                      const SizedBox(height: 8),
                                      Text(context.s.goalReachedTitle,
                                          style: AppTypography.title20),
                                      const SizedBox(height: 12),
                                      FilledButton(
                                          onPressed: onDismissGoal,
                                          child: Text(context.s.goalKeepGoing)),
                                      const SizedBox(height: 8),
                                      TextButton(
                                          onPressed: onFinish,
                                          child:
                                              Text(context.s.finishSeeResult)),
                                    ]))),
                        ],
                      ]))),
              if (!paused)
                Padding(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Expanded(
                              child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                IconButton.filledTonal(
                                    key: const Key('pause-workout'),
                                    onPressed: onPause,
                                    icon: const Icon(LucideIcons.pause),
                                    iconSize: 26,
                                    style: IconButton.styleFrom(
                                        minimumSize: const Size(64, 64),
                                        backgroundColor: AppColors.surface2)),
                                const SizedBox(height: 8),
                                Text(context.tr('Tạm dừng', 'Pause'),
                                    style: const TextStyle(fontSize: 12)),
                              ])),
                          Expanded(child: HoldToFinish(onFinish: onFinish)),
                        ])),
            ]));
  }
}

class _TimedChallengeHud extends StatelessWidget {
  const _TimedChallengeHud({
    required this.state,
    required this.exerciseName,
    required this.voiceEnabled,
    required this.onExit,
    required this.onPause,
    required this.onResume,
    required this.onFinish,
    this.challengeBestReps,
    this.diagnosticAction,
    this.onToggleVoice,
  });

  final WorkoutUiState state;
  final String exerciseName;
  final bool voiceEnabled;
  final int? challengeBestReps;
  final Widget? diagnosticAction;
  final VoidCallback? onToggleVoice;
  final VoidCallback onExit, onPause, onResume, onFinish;

  String _remaining() {
    final seconds = state.challengeRemainingSeconds ?? 0;
    return '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final paused = state.phase == WorkoutUiPhase.paused;
    final finalTen = state.isFinalTenSeconds;
    final placementColor =
        state.placementReady ? AppColors.success : AppColors.warning;
    final compactHeader =
        MediaQuery.textScalerOf(context).scale(14) > 20 ||
            MediaQuery.sizeOf(context).width < 350;

    return Column(
      key: const Key('timed-challenge-hud'),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
          child: Column(
            children: [
              Row(
                children: [
                  Semantics(
                    label: context.tr('Xử lý trên máy', 'On-device'),
                    child: ExcludeSemantics(
                      child: Container(
                        constraints: const BoxConstraints(
                          minWidth: 38,
                          minHeight: 38,
                        ),
                        padding: EdgeInsets.symmetric(
                          horizontal: compactHeader ? 10 : 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(19),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: compactHeader
                            ? const Icon(
                                LucideIcons.shieldCheck,
                                size: 17,
                                color: AppColors.success,
                              )
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    LucideIcons.shieldCheck,
                                    size: 15,
                                    color: AppColors.success,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    context.tr(
                                      'Xử lý trên máy',
                                      'On-device',
                                    ),
                                    style: AppTypography.body14.copyWith(
                                      color: AppColors.success,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                  if (!compactHeader) ...[
                    const Spacer(),
                    Flexible(
                      child: Text(
                        exerciseName,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: AppTypography.body14,
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (diagnosticAction != null) diagnosticAction!,
                  IconButton(
                    key: const Key('toggle-timed-voice'),
                    tooltip: context.tr(
                      voiceEnabled ? 'Tắt giọng đọc' : 'Bật giọng đọc',
                      voiceEnabled ? 'Mute voice' : 'Enable voice',
                    ),
                    onPressed: onToggleVoice,
                    icon: Icon(
                      voiceEnabled
                          ? LucideIcons.volume2
                          : LucideIcons.volumeX,
                    ),
                  ),
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.asset(
                          'assets/vnext/time_challenge_close_ellipse.png',
                          fit: BoxFit.contain,
                        ),
                        IconButton(
                          key: const Key('close-timed-challenge'),
                          tooltip: context.tr('Đóng', 'Close'),
                          onPressed: onExit,
                          icon: const Icon(LucideIcons.x),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (compactHeader) ...[
                const SizedBox(height: 4),
                Text(
                  exerciseName,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: AppTypography.body14,
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
            child: Column(
              children: [
                AnimatedContainer(
                  key: const Key('timed-challenge-hero'),
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 160),
                  width: double.infinity,
                  constraints: const BoxConstraints(minHeight: 210),
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
                  decoration: BoxDecoration(
                    color: AppColors.bg,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color:
                          finalTen ? AppColors.accent : AppColors.borderStrong,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (finalTen) ...[
                        Text(
                          context.tr('10 GIÂY CUỐI', 'FINAL 10 SECONDS'),
                          key: const Key('timed-final-ten-label'),
                          style: AppTypography.caption12.copyWith(
                            color: AppColors.accent,
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      Semantics(
                        liveRegion: !voiceEnabled,
                        label: context.tr(
                          'Còn ${state.challengeRemainingSeconds ?? 0} giây',
                          '${state.challengeRemainingSeconds ?? 0} seconds remaining',
                        ),
                        child: ExcludeSemantics(
                          child: Text(
                            _remaining(),
                            key: const Key('timed-remaining'),
                            textScaler: TextScaler.noScaling,
                            style: AppTypography.display40.copyWith(
                              color:
                                  finalTen ? AppColors.accent : AppColors.text,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Semantics(
                        label: '${state.reps} ${context.s.repsShort}',
                        liveRegion: !voiceEnabled,
                        child: ExcludeSemantics(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              '${state.reps}',
                              key: const Key('timed-reps'),
                              textScaler: TextScaler.noScaling,
                              style: AppTypography.hero.copyWith(
                                fontSize: 180,
                                color: AppColors.accent,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Text(
                        'REPS',
                        style: AppTypography.caption12.copyWith(
                          color: AppColors.text2,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Expanded(
                      child: _TimedStatPill(
                        key: Key('timed-form-stat'),
                        label: 'FORM —',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _TimedStatPill(
                        key: const Key('timed-best-stat'),
                        label: challengeBestReps == null
                            ? 'BEST —'
                            : 'BEST $challengeBestReps',
                      ),
                    ),
                  ],
                ),
                if (paused) ...[
                  const SizedBox(height: 16),
                  _Glass(
                    child: Text(context.tr('Đã tạm dừng', 'Paused')),
                  ),
                ],
                const SizedBox(height: 16),
                _Glass(
                  color: placementColor.withValues(alpha: .15),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        state.placementReady
                            ? LucideIcons.circleCheck
                            : LucideIcons.scanLine,
                        size: 20,
                        color: placementColor,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          state.placementStatus.message(context.s),
                          style: TextStyle(
                            color: placementColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (!state.placementReady &&
                    state.placementMessage.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    state.placementMessage,
                    textAlign: TextAlign.center,
                    style: AppTypography.body14.copyWith(
                      color: AppColors.text2,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                RepFeedbackTransition(feedback: state.repFeedback),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 54,
                  child: FilledButton.tonalIcon(
                    key: Key(
                      paused
                          ? 'resume-timed-challenge'
                          : 'pause-timed-challenge',
                    ),
                    onPressed: paused ? onResume : onPause,
                    icon: Icon(
                      paused ? LucideIcons.play : LucideIcons.pause,
                      size: 20,
                    ),
                    label: Text(
                      paused
                          ? context.tr('Tiếp tục', 'Resume')
                          : context.tr('Tạm dừng', 'Pause'),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 17),
              Expanded(
                child: SizedBox(
                  height: 54,
                  child: FilledButton.tonalIcon(
                    key: const Key('finish-timed-challenge'),
                    onPressed: onFinish,
                    icon: const Icon(LucideIcons.square, size: 18),
                    label: Text(context.tr('Kết thúc', 'Finish')),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TimedStatPill extends StatelessWidget {
  const _TimedStatPill({
    super.key,
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minHeight: 54),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(27),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: AppTypography.body16,
          ),
        ),
      );
}

class _Glass extends StatelessWidget {
  const _Glass({required this.child, this.color});
  final Widget child;
  final Color? color;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
          color: color ?? AppColors.bg.withValues(alpha: .8),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderStrong)),
      child: child);
}

class HoldToFinish extends StatefulWidget {
  const HoldToFinish({super.key, required this.onFinish});
  final VoidCallback onFinish;
  @override
  State<HoldToFinish> createState() => _HoldToFinishState();
}

class _HoldToFinishState extends State<HoldToFinish>
    with SingleTickerProviderStateMixin {
  late final _progress =
      AnimationController(vsync: this, duration: const Duration(seconds: 1))
        ..addStatusListener((status) {
          if (status == AnimationStatus.completed) widget.onFinish();
        });
  bool _holding = false;
  void _cancel() {
    if (!mounted) return;
    _progress.reset();
    if (mounted) setState(() => _holding = false);
  }

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  Future<void> _accessibleFinish() async {
    final yes = await showDialog<bool>(
        context: context,
        builder: (context) =>
            AlertDialog(title: Text(context.s.finishTitle), actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(context.s.finishContinue)),
              FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(context.s.finishSave))
            ]));
    if (yes == true && mounted) widget.onFinish();
  }

  @override
  Widget build(BuildContext context) =>
      Column(mainAxisSize: MainAxisSize.min, children: [
        Semantics(
            button: true,
            label: context.tr('Kết thúc buổi tập', 'Finish workout'),
            onTap: _accessibleFinish,
            child: ExcludeSemantics(
                child: Listener(
                    onPointerDown: (_) {
                      setState(() => _holding = true);
                      _progress.forward(from: 0);
                    },
                    onPointerUp: (_) => _cancel(),
                    onPointerCancel: (_) => _cancel(),
                    child: SizedBox.square(
                        dimension: 64,
                        child: Stack(fit: StackFit.expand, children: [
                          const DecoratedBox(
                              decoration: BoxDecoration(
                                  color: AppColors.surface2,
                                  shape: BoxShape.circle),
                              child: Icon(LucideIcons.square,
                                  color: AppColors.danger)),
                          AnimatedBuilder(
                              animation: _progress,
                              builder: (context, _) =>
                                  CircularProgressIndicator(
                                      value: _progress.value,
                                      color: AppColors.danger,
                                      strokeWidth: 4)),
                        ]))))),
        const SizedBox(height: 8),
        Text(
            _holding
                ? context.tr('Đang giữ…', 'Keep holding…')
                : context.tr('Giữ để kết thúc', 'Hold to finish'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12)),
      ]);
}
