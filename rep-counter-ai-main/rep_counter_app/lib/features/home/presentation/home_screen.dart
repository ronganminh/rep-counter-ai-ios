import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/config/feature_flags.dart';
import '../../../core/i18n/locale_controller.dart';
import '../../../exercise.dart';
import '../../../local_video_test_page.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../widgets/product_ui.dart';
import '../../exercises/presentation/exercise_picker_screen.dart';
import '../../plan/presentation/plan_today_sheet.dart';
import '../../routine/presentation/routine_list_page.dart';
import '../../workout/data/workout_history_store.dart';
import '../../workout/data/workout_record.dart';
import '../../workout/presentation/exercise_icon.dart';
import '../../workout/presentation/goal_setup_page.dart';
import '../../workout/presentation/result_page.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<WorkoutRecord>> _records;
  @override
  void initState() {
    super.initState();
    _records = WorkoutHistoryStore().load();
  }

  Future<void> _reload() async {
    final next = WorkoutHistoryStore().load();
    setState(() {
      _records = next;
    });
    await next;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
        body: SafeArea(
            child: RefreshIndicator(
                onRefresh: _reload,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                  children: [
                    Row(children: [
                      Icon(LucideIcons.scan, color: p.accentInk, size: 28),
                      const SizedBox(width: 10),
                      Expanded(
                          child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('REPCOACH ',
                                        style: AppTypography.title20),
                                    Text('AI',
                                        style: AppTypography.title20
                                            .copyWith(color: p.accentInk)),
                                  ]))),
                    ]),
                    const SizedBox(height: 32),
                    Text(
                        context.tr('Hôm nay, mình tập nhé.',
                            'Ready for today’s workout?'),
                        style: AppTypography.headline28),
                    const SizedBox(height: 12),
                    Row(children: [
                      Icon(LucideIcons.shieldCheck, size: 16, color: p.success),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(
                              context.tr('Xử lý trên máy · không cần tài khoản',
                                  'On device · no account needed'),
                              style: TextStyle(color: p.text3, fontSize: 12)))
                    ]),
                    const SizedBox(height: 24),
                    Card(
                        child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      leading: ExerciseIcon(
                          exerciseId: pushUp.id, color: p.accentInk, size: 44),
                      title: Text(context.s.pushUpName,
                          style: AppTypography.title20),
                      subtitle: Text(
                          context.tr('Camera trước · máy dựng dọc',
                              'Front camera · portrait'),
                          style: TextStyle(color: p.text2, fontSize: 13)),
                      trailing: const Icon(LucideIcons.chevronDown),
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const ExercisePickerScreen())),
                    )),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                        style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(80)),
                        onPressed: () => showPlanTodaySheet(context, pushUp),
                        icon: const Icon(LucideIcons.play, size: 28),
                        label: Text(context.tr('TẬP NGAY', 'TRAIN NOW'),
                            style: AppTypography.display40
                                .copyWith(fontSize: 36))),
                    const SizedBox(height: 28),
                    const RoutineListSection(),
                    const SizedBox(height: 28),
                    FutureBuilder<List<WorkoutRecord>>(
                        future: _records,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                                child: CircularProgressIndicator());
                          }
                          if (snapshot.hasError) {
                            return TextButton(
                                onPressed: _reload,
                                child: Text(context.tr(
                                    'Tải lại lịch sử', 'Reload history')));
                          }
                          final records = snapshot.data ?? [];
                          if (records.isEmpty) {
                            return Card(
                                child: Padding(
                                    padding: const EdgeInsets.all(24),
                                    child: Column(children: [
                                      ExerciseIcon(
                                          exerciseId: pushUp.id,
                                          color: p.accentInk,
                                          size: 72),
                                      const SizedBox(height: 16),
                                      Text(
                                          context.tr('Bắt đầu từ rep đầu tiên.',
                                              'Start with your first rep.'),
                                          style: AppTypography.title20,
                                          textAlign: TextAlign.center),
                                      const SizedBox(height: 8),
                                      Text(
                                          context.tr(
                                              'Chọn mục tiêu, đặt điện thoại chắc chắn và để app đếm cùng bạn.',
                                              'Choose a goal, position your phone securely and let the app count with you.'),
                                          textAlign: TextAlign.center,
                                          style: TextStyle(color: p.text2)),
                                    ])));
                          }
                          final latest = records.first;
                          final now = DateTime.now();
                          final today = DateTime(now.year, now.month, now.day);
                          final monday =
                              today.subtract(Duration(days: today.weekday - 1));
                          final week = records
                              .where((r) =>
                                  !r.startedAt.isBefore(monday) &&
                                  r.startedAt.isBefore(
                                      today.add(const Duration(days: 1))))
                              .toList();
                          final reps = week.fold<int>(0, (n, r) => n + r.reps);
                          return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                SectionLabel(
                                    context.tr('Tuần này', 'This week')),
                                Card(
                                    child: Padding(
                                        padding: const EdgeInsets.all(20),
                                        child: Wrap(
                                            alignment:
                                                WrapAlignment.spaceBetween,
                                            crossAxisAlignment:
                                                WrapCrossAlignment.center,
                                            spacing: 16,
                                            runSpacing: 8,
                                            children: [
                                              Text('$reps rep',
                                                  style: AppTypography.metric64
                                                      .copyWith(
                                                          color: p.accentInk)),
                                              Text(
                                                  context.tr(
                                                      '${week.length} buổi tập',
                                                      '${week.length} sessions'),
                                                  style: TextStyle(
                                                      color: p.text2)),
                                            ]))),
                                const SizedBox(height: 24),
                                SectionLabel(context.tr(
                                    'Buổi gần nhất', 'Last session')),
                                Card(
                                    child: ListTile(
                                  contentPadding: const EdgeInsets.all(20),
                                  leading: ExerciseIcon(
                                      exerciseId: latest.exerciseId,
                                      color: p.accentInk),
                                  title: Text(
                                      '${latest.reps} rep · ${exerciseNameFor(latest.exerciseId, context.s)}',
                                      style: AppTypography.title20),
                                  subtitle: Text(
                                      '${latest.startedAt.day}/${latest.startedAt.month} · ${latest.durationSeconds ~/ 60}:${(latest.durationSeconds % 60).toString().padLeft(2, '0')}',
                                      style: TextStyle(color: p.text2)),
                                  trailing:
                                      const Icon(LucideIcons.chevronRight),
                                  onTap: () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                          builder: (_) => ResultPage(
                                              record: latest, readOnly: true))),
                                )),
                              ]);
                        }),
                    if (FeatureFlags.enableAllExercises ||
                        FeatureFlags.enablePullUp) ...[
                      const SizedBox(height: 24),
                      SectionLabel(context.tr(
                          'Bài thử nghiệm', 'Experimental exercises')),
                      for (final profile in allExercises.where((e) =>
                          e.id != 'push_up' &&
                          (FeatureFlags.enableAllExercises ||
                              FeatureFlags.visibleExerciseIds.contains(e.id))))
                        TextButton(
                            onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        GoalSetupPage(profile: profile))),
                            child: Text(profile.localizedName(context.s))),
                    ],
                    if (kDebugMode) ...[
                      const SizedBox(height: 24),
                      TextButton.icon(
                          onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) => const LocalVideoTestPage())),
                          icon: const Icon(LucideIcons.video),
                          label: Text(context.s.debugVideoTest)),
                    ],
                  ],
                ))));
  }
}
