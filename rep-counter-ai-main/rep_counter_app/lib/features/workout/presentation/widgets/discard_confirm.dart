import 'package:flutter/material.dart';

import '../../../../core/i18n/locale_controller.dart';
import '../../../../theme/app_colors.dart';
import '../../../../widgets/product_ui.dart';

/// Whether leaving a workout with [reps] counted reps needs a second
/// confirmation before discarding (W-2): with 0 reps nothing is lost.
bool discardNeedsConfirmation(int reps) => reps > 0;

/// Second step of "Discard…" (FA-10). Returns true only on explicit confirm;
/// dismissing the dialog keeps the workout. Copy matches the ARB keys
/// `workoutDiscardTitle` / `workoutDiscardBody` (moves to ARB in L-1).
Future<bool> confirmDiscardWorkout(BuildContext context) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('Bỏ buổi tập này?', 'Discard this workout?')),
        content: Text(context.tr('Số rep của buổi này sẽ không được lưu.',
            'Reps from this session won’t be saved.')),
        actions: [
          TextButton(
            key: const Key('discard-cancel'),
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.s.finishContinue),
          ),
          TextButton(
            key: const Key('discard-confirm'),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.s.finishDiscard),
          ),
        ],
      ),
    ) ??
    false;
