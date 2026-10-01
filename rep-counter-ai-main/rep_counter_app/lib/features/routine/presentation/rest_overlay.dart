import 'package:flutter/material.dart';

import '../../../theme/app_typography.dart';
import '../../../widgets/product_ui.dart';
import '../../workout/application/workout_ui_state.dart';

class RoutineRestOverlay extends StatelessWidget {
  const RoutineRestOverlay({
    super.key,
    required this.state,
    required this.onSkip,
    required this.onEnd,
  });

  final WorkoutUiState state;
  final VoidCallback onSkip;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    final routine = state.routine!;
    final p = context.palette;
    final seconds =
        state.routineRestRemainingSeconds ?? routine.restSeconds;
    final minutes = seconds ~/ 60;
    final remainder = seconds % 60;
    final timer =
        '${minutes.toString().padLeft(2, '0')}:${remainder.toString().padLeft(2, '0')}';

    return ColoredBox(
      color: p.bg,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 42, 24, 28),
          children: [
            Semantics(
              header: true,
              child: Text(
                context.tr(
                  'HOÀN THÀNH SET ${state.completedSets}',
                  'SET ${state.completedSets} COMPLETE',
                ),
                textAlign: TextAlign.center,
                style: AppTypography.caption12.copyWith(color: p.success),
              ),
            ),
            const SizedBox(height: 24),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '${state.routineCompletedSetReps}',
                style: AppTypography.hero.copyWith(color: p.accentInk),
              ),
            ),
            Text(
              'rep',
              textAlign: TextAlign.center,
              style: AppTypography.display40.copyWith(color: p.text2),
            ),
            const SizedBox(height: 38),
            Semantics(
              liveRegion: true,
              label: context.tr(
                'Set tiếp theo sau $seconds giây',
                'Next set in $seconds seconds',
              ),
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 26, 24, 28),
                decoration: BoxDecoration(
                  color: p.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: p.accent),
                ),
                child: Column(
                  children: [
                    Text(
                      context.tr('SET TIẾP THEO SAU', 'NEXT SET IN'),
                      style:
                          AppTypography.caption12.copyWith(color: p.text2),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      timer,
                      key: const Key('routine-rest-timer'),
                      style:
                          AppTypography.metric64.copyWith(color: p.accentInk),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      context.tr(
                        'Tiếp theo: ${routine.targetReps} rep',
                        'Next: ${routine.targetReps} reps',
                      ),
                      style: AppTypography.body16,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 52),
            FilledButton(
              key: const Key('routine-skip-rest'),
              onPressed: onSkip,
              child: Text(context.tr(
                'Bỏ qua thời gian nghỉ',
                'Skip rest',
              )),
            ),
            const SizedBox(height: 14),
            OutlinedButton(
              key: const Key('routine-end-workout'),
              onPressed: onEnd,
              child: Text(context.tr(
                'Kết thúc buổi tập',
                'End workout',
              )),
            ),
          ],
        ),
      ),
    );
  }
}
