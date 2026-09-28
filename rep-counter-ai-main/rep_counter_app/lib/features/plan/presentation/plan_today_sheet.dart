import 'package:flutter/material.dart';
import '../../../camera_page.dart';
import '../../../exercise.dart';
import '../../workout/presentation/goal_setup_page.dart';

Future<void> showPlanTodaySheet(
        BuildContext context, ExerciseProfile profile) =>
    showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (sheetContext) => SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                  24, 8, 24, 28 + MediaQuery.viewInsetsOf(sheetContext).bottom),
              child: GoalSetupContent(
                  profile: profile,
                  onStart: (goal) {
                    final navigator =
                        Navigator.of(context, rootNavigator: true);
                    Navigator.of(sheetContext).pop();
                    navigator.push(MaterialPageRoute(
                        builder: (_) =>
                            CameraPage(profile: profile, targetReps: goal)));
                  }),
            )));
