import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/i18n/locale_controller.dart';
import '../../../exercise.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../widgets/product_ui.dart';
import '../../history/history_statistics.dart';
import '../../plan/presentation/plan_today_sheet.dart';
import '../data/workout_history_store.dart';
import '../data/workout_record.dart';
import 'exercise_icon.dart';
import 'result_page.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key, this.onTrain});
  final VoidCallback? onTrain;
  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  late Future<List<WorkoutRecord>> _records;
  String? _filter;
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

  Future<void> _delete(WorkoutRecord record) async {
    try {
      final deleted = await WorkoutHistoryStore().delete(record.id);
      if (!mounted) return;
      await _reload();
      if (!mounted) return;
      if (deleted != null) _offerUndo(deleted);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(context.tr('Không thể xóa. Hãy thử lại.',
                'Could not delete. Please retry.'))));
      }
    }
  }

  void _offerUndo(DeletedWorkout deleted) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      duration: const Duration(seconds: 5),
      backgroundColor: context.palette.surface2,
      content: Text(context.s.historyDeleted,
          style: TextStyle(color: context.palette.text)),
      action: SnackBarAction(
          textColor: context.palette.accentInk,
          label: context.tr('Hoàn tác', 'Undo'),
          onPressed: () => _restore(deleted)),
    ));
  }

  Future<void> _restore(DeletedWorkout deleted) async {
    try {
      await WorkoutHistoryStore().restore(deleted);
      if (mounted) await _reload();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            backgroundColor: context.palette.surface2,
            content: Text(
                context.tr('Chưa khôi phục được buổi tập.',
                    'Could not restore workout.'),
                style: TextStyle(color: context.palette.text)),
            action: SnackBarAction(
                textColor: context.palette.accentInk,
                label: context.s.retry,
                onPressed: () => _restore(deleted))));
      }
    }
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
                  Text(context.s.historyTitle.toUpperCase(),
                      style: AppTypography.display40),
                  const SizedBox(height: 20),
                  SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(children: [
                        ChoiceChip(
                            label: Text(context.tr('Tất cả', 'All')),
                            selected: _filter == null,
                            onSelected: (_) => setState(() => _filter = null)),
                        for (final exercise in allExercises) ...[
                          const SizedBox(width: 8),
                          ChoiceChip(
                              label: Text(exercise.localizedName(context.s)),
                              selected: _filter == exercise.id,
                              onSelected: (_) =>
                                  setState(() => _filter = exercise.id)),
                        ],
                      ])),
                  const SizedBox(height: 20),
                  FutureBuilder<List<WorkoutRecord>>(
                      future: _records,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }
                        if (snapshot.hasError) {
                          return Column(children: [
                            Text(context.tr('Không đọc được lịch sử.',
                                'Could not load history.')),
                            TextButton(
                                onPressed: _reload,
                                child: Text(context.tr('Thử lại', 'Retry')))
                          ]);
                        }
                        final records = (snapshot.data ?? [])
                            .where((r) =>
                                _filter == null || r.exerciseId == _filter)
                            .toList();
                        if (records.isEmpty) {
                          return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 40),
                              child: Column(children: [
                                ExcludeSemantics(
                                    child: SizedBox(
                                        width: 184,
                                        child: Wrap(
                                            spacing: 5,
                                            runSpacing: 5,
                                            children: List.generate(
                                                28,
                                                (i) => Container(
                                                    width: 22,
                                                    height: 22,
                                                    decoration: BoxDecoration(
                                                        color: i == 10
                                                            ? p.accent
                                                            : p.surface2,
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(
                                                                    4))))))),
                                const SizedBox(height: 28),
                                Text(context.s.historyEmpty,
                                    style: AppTypography.title20,
                                    textAlign: TextAlign.center),
                                const SizedBox(height: 12),
                                Text(
                                    context.tr(
                                        'Mỗi buổi tập sẽ hiện ở đây, kèm số liệu và nhận xét. Bắt đầu buổi đầu tiên của bạn.',
                                        'Your sessions, statistics and feedback will appear here. Start your first workout.'),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: p.text2)),
                                const SizedBox(height: 24),
                                FilledButton.icon(
                                    onPressed: widget.onTrain ??
                                        () =>
                                            showPlanTodaySheet(context, pushUp),
                                    icon: const Icon(LucideIcons.play),
                                    label: Text(
                                        context.tr('Tập ngay', 'Train now'))),
                              ]));
                        }
                        final stats =
                            HistoryStatistics(records, DateTime.now());
                        final groups = <DateTime, List<WorkoutRecord>>{};
                        for (final r in records) {
                          groups
                              .putIfAbsent(
                                  HistoryStatistics.day(r.startedAt), () => [])
                              .add(r);
                        }
                        return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _MonthCard(stats),
                              const SizedBox(height: 16),
                              if (stats.recent.isNotEmpty) ...[
                                _HistoryChart(stats.recent),
                                const SizedBox(height: 24)
                              ],
                              for (final group in groups.entries) ...[
                                SectionLabel(
                                    '${group.key.day}/${group.key.month}/${group.key.year}'),
                                for (final record in group.value)
                                  Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 10),
                                      child: Dismissible(
                                        key: ValueKey(record.id),
                                        direction: DismissDirection.endToStart,
                                        // Deletion goes through the store before removing the row.
                                        confirmDismiss: (_) async {
                                          await _delete(record);
                                          return false;
                                        },
                                        background: Container(
                                            alignment: Alignment.centerRight,
                                            padding: const EdgeInsets.all(24),
                                            decoration: BoxDecoration(
                                                color: p.danger,
                                                borderRadius:
                                                    BorderRadius.circular(16)),
                                            child: Icon(LucideIcons.trash2,
                                                color: p.onAccent)),
                                        child: _SessionRow(
                                            record: record,
                                            best: stats.best,
                                            onDelete: () => _delete(record),
                                            onOpen: () async {
                                              final deleted = await Navigator.of(
                                                      context)
                                                  .push<DeletedWorkout>(
                                                      MaterialPageRoute<
                                                              DeletedWorkout>(
                                                          builder: (_) =>
                                                              ResultPage(
                                                                  record:
                                                                      record,
                                                                  readOnly:
                                                                      true)));
                                              if (mounted) {
                                                await _reload();
                                                if (mounted &&
                                                    deleted != null) {
                                                  _offerUndo(deleted);
                                                }
                                              }
                                            }),
                                      )),
                                const SizedBox(height: 12),
                              ],
                            ]);
                      }),
                ],
              ))),
    );
  }
}

class _MonthCard extends StatelessWidget {
  const _MonthCard(this.stats);
  final HistoryStatistics stats;
  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final first = DateTime(stats.now.year, stats.now.month);
    final days = DateTime(first.year, first.month + 1, 0).day;
    final start = first.subtract(Duration(days: first.weekday - 1));
    final cells = ((first.weekday - 1 + days) / 7).ceil() * 7;
    final daily = stats.dailyReps;
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(20),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SectionLabel(context.tr(
                  'Tháng ${stats.now.month} · ${stats.now.year}',
                  '${stats.now.month}/${stats.now.year}')),
              Wrap(
                  spacing: 24,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text('${stats.monthReps} rep',
                        style: AppTypography.metric64
                            .copyWith(color: p.accentInk)),
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(context.tr('${stats.month.length} buổi tập',
                              '${stats.month.length} sessions')),
                          const SizedBox(height: 6),
                          Text(
                              context.tr('${stats.streak} ngày liên tiếp',
                                  '${stats.streak} day streak'),
                              style: TextStyle(color: p.accentInk)),
                        ]),
                  ]),
              const SizedBox(height: 20),
              Semantics(
                  label: context.tr('Số rep mỗi ngày trong tháng',
                      'Daily repetitions this month'),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: cells,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 7,
                            crossAxisSpacing: 5,
                            mainAxisSpacing: 5),
                    itemBuilder: (_, i) {
                      final date =
                          DateTime(start.year, start.month, start.day + i);
                      final reps = daily[date] ?? 0;
                      final inMonth = date.month == first.month;
                      return Tooltip(
                          message: '${date.day}/${date.month}: $reps rep',
                          child: Container(
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                                color: !inMonth
                                    ? Colors.transparent
                                    : reps > 0
                                        ? p.accent
                                        : p.surface2,
                                borderRadius: BorderRadius.circular(6)),
                            child: inMonth
                                ? Text('${date.day}',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: reps > 0 ? p.onAccent : p.text3))
                                : null,
                          ));
                    },
                  )),
              const SizedBox(height: 10),
              Text(
                  context.tr(
                      'Ô xanh: có rep đã lưu', 'Green cell: saved repetitions'),
                  style: TextStyle(color: p.text3, fontSize: 12)),
            ])));
  }
}

class _SessionRow extends StatelessWidget {
  const _SessionRow(
      {required this.record,
      required this.best,
      required this.onOpen,
      required this.onDelete});
  final WorkoutRecord record;
  final int best;
  final VoidCallback onOpen, onDelete;
  @override
  Widget build(BuildContext context) {
    final r = record;
    final p = context.palette;
    final goal = r.targetReps;
    final status = goal == null
        ? context.tr('Tập tự do', 'Free workout')
        : r.goalReached
            ? context.tr('Đạt mục tiêu', 'Goal reached')
            : '${goal > 0 ? (r.reps / goal * 100).round() : 0}%';
    return Card(
        child: ListTile(
      contentPadding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      leading:
          ExerciseIcon(exerciseId: r.exerciseId, color: p.accentInk, size: 30),
      title: Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(goal == null ? '${r.reps} rep' : '${r.reps}/$goal',
                style: AppTypography.metric40.copyWith(fontSize: 28)),
            Text(status,
                style: TextStyle(
                    fontSize: 12, color: r.goalReached ? p.success : p.text2)),
            if (r.reps > 0 && r.reps == best)
              Icon(LucideIcons.trophy, size: 14, color: p.accentInk),
          ]),
      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
            '${exerciseNameFor(r.exerciseId, context.s)} · ${r.durationSeconds ~/ 60}:${(r.durationSeconds % 60).toString().padLeft(2, '0')} · ${r.startedAt.hour.toString().padLeft(2, '0')}:${r.startedAt.minute.toString().padLeft(2, '0')}',
            style: TextStyle(color: p.text2, fontSize: 12)),
        if (r.quality?.hasEnoughData == true)
          Text('Form ${r.quality!.qualityScore}/100',
              style: TextStyle(color: p.text2, fontSize: 12)),
        if (r.aiFeedback != null)
          Text(r.aiFeedback!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: p.text3, fontSize: 12)),
      ]),
      trailing: PopupMenuButton<String>(
          tooltip: context.s.historyOptions,
          onSelected: (_) => onDelete(),
          itemBuilder: (_) => [
                PopupMenuItem(
                    value: 'delete', child: Text(context.s.historyDeleteAction))
              ]),
      onTap: onOpen,
    ));
  }
}

class _HistoryChart extends StatelessWidget {
  const _HistoryChart(this.records);
  final List<WorkoutRecord> records;
  @override
  Widget build(BuildContext context) => Card(
      child: Padding(
          padding: const EdgeInsets.all(20),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SectionLabel(context.tr(
                'Rep mỗi buổi · 30 ngày', 'Reps per session · 30 days')),
            Semantics(
                label: records
                    .map((r) =>
                        '${r.startedAt.day}/${r.startedAt.month}: ${r.reps} rep')
                    .join(', '),
                child: SizedBox(
                    height: 100,
                    width: double.infinity,
                    child: CustomPaint(
                        painter: _TrendPainter(
                            records.map((r) => r.reps).toList(),
                            context.palette.accentInk,
                            context.palette.border)))),
            const SizedBox(height: 8),
            Text(
                context.tr(
                    '${records.length} buổi · từ ${records.first.startedAt.day}/${records.first.startedAt.month} đến ${records.last.startedAt.day}/${records.last.startedAt.month}',
                    '${records.length} sessions, in chronological order'),
                style: TextStyle(color: context.palette.text3, fontSize: 12)),
          ])));
}

class _TrendPainter extends CustomPainter {
  _TrendPainter(this.values, this.color, this.grid);
  final List<int> values;
  final Color color, grid;
  @override
  void paint(Canvas canvas, Size size) {
    final max = values.fold<int>(1, (a, b) => a > b ? a : b);
    for (var i = 0; i < 3; i++) {
      canvas.drawLine(
          Offset(0, 8 + i * (size.height - 16) / 2),
          Offset(size.width, 8 + i * (size.height - 16) / 2),
          Paint()..color = grid);
    }
    final points = List.generate(
        values.length,
        (i) => Offset(
            values.length == 1
                ? size.width / 2
                : 5 + i * (size.width - 10) / (values.length - 1),
            size.height - 8 - values[i] / max * (size.height - 16)));
    if (points.isEmpty) return;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke);
    for (final point in points) {
      canvas.drawCircle(point, 3, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant _TrendPainter old) => true;
}
