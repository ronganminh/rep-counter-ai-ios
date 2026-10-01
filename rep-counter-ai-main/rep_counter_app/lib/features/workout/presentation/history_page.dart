import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/i18n/locale_controller.dart';
import '../../../exercise.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../widgets/product_ui.dart';
import '../../history/progress_statistics.dart';
import '../../plan/presentation/plan_today_sheet.dart';
import '../data/workout_history_store.dart';
import '../data/workout_record.dart';
import '../domain/workout_mode.dart';
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
  String? _filter = pushUp.id;
  ProgressRange _range = ProgressRange.days7;
  ProgressTrendMetric _trend = ProgressTrendMetric.reps;

  @override
  void initState() {
    super.initState();
    _records = WorkoutHistoryStore().load();
  }

  Future<void> _reload() async {
    final next = WorkoutHistoryStore().load();
    setState(() => _records = next);
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.tr(
                'Không thể xóa. Hãy thử lại.',
                'Could not delete. Please retry.',
              ),
            ),
          ),
        );
      }
    }
  }

  void _offerUndo(DeletedWorkout deleted) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 5),
        backgroundColor: context.palette.surface2,
        content: Text(
          context.s.historyDeleted,
          style: TextStyle(color: context.palette.text),
        ),
        action: SnackBarAction(
          textColor: context.palette.accentInk,
          label: context.tr('Hoàn tác', 'Undo'),
          onPressed: () => _restore(deleted),
        ),
      ),
    );
  }

  Future<void> _restore(DeletedWorkout deleted) async {
    try {
      await WorkoutHistoryStore().restore(deleted);
      if (mounted) await _reload();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: context.palette.surface2,
            content: Text(
              context.tr(
                'Chưa khôi phục được buổi tập.',
                'Could not restore workout.',
              ),
              style: TextStyle(color: context.palette.text),
            ),
            action: SnackBarAction(
              textColor: context.palette.accentInk,
              label: context.s.retry,
              onPressed: () => _restore(deleted),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _reload,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Text(
                      context.s.historyTitle.toUpperCase(),
                      style: AppTypography.display40,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Text(
                      context.tr('Tiến bộ', 'Progress'),
                      style: AppTypography.body14.copyWith(
                        color: context.palette.accentInk,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _RangeSelector(
                selected: _range,
                onSelected: (value) => setState(() => _range = value),
              ),
              const SizedBox(height: 14),
              FutureBuilder<List<WorkoutRecord>>(
                future: _records,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.only(top: 80),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (snapshot.hasError) {
                    return _LoadError(onRetry: _reload);
                  }

                  final source = snapshot.data ?? const <WorkoutRecord>[];
                  if (source.isEmpty) {
                    return _ProgressEmptyState(onTrain: _startTraining);
                  }

                  return _buildProgress(context, source);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _startTraining() {
    final callback = widget.onTrain;
    if (callback != null) {
      callback();
    } else {
      showPlanTodaySheet(context, pushUp);
    }
  }

  Widget _buildProgress(BuildContext context, List<WorkoutRecord> source) {
    final stats = ProgressStatistics(
      records: source,
      now: DateTime.now(),
      range: _range,
      exerciseId: _filter,
    );
    final groups = <DateTime, List<WorkoutRecord>>{};
    for (final record in stats.records) {
      groups
          .putIfAbsent(ProgressStatistics.day(record.startedAt), () => [])
          .add(record);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ExerciseFilter(
          selected: _filter,
          onSelected: (value) => setState(() => _filter = value),
        ),
        const SizedBox(height: 18),
        _SummaryMetrics(stats: stats),
        const SizedBox(height: 22),
        _PersonalRecordsCard(stats: stats),
        const SizedBox(height: 16),
        _TrendCard(
          stats: stats,
          selected: _trend,
          onSelected: (value) => setState(() => _trend = value),
        ),
        const SizedBox(height: 16),
        _HeatmapCard(stats: stats),
        const SizedBox(height: 24),
        if (stats.records.isEmpty)
          _RangeEmptyMessage(onTrain: _startTraining)
        else ...[
          SectionLabel(context.tr('Buổi tập', 'Sessions')),
          for (final group in groups.entries) ...[
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 8),
              child: Text(
                '${group.key.day}/${group.key.month}/${group.key.year}',
                style: AppTypography.caption12.copyWith(
                  color: context.palette.text3,
                ),
              ),
            ),
            for (final record in group.value)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Dismissible(
                  key: ValueKey(record.id),
                  direction: DismissDirection.endToStart,
                  confirmDismiss: (_) async {
                    await _delete(record);
                    return false;
                  },
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: context.palette.danger,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      LucideIcons.trash2,
                      color: context.palette.onAccent,
                    ),
                  ),
                  child: _SessionRow(
                    record: record,
                    onDelete: () => _delete(record),
                    onOpen: () async {
                      final deleted =
                          await Navigator.of(context).push<DeletedWorkout>(
                        MaterialPageRoute<DeletedWorkout>(
                          builder: (_) => ResultPage(
                            record: record,
                            readOnly: true,
                          ),
                        ),
                      );
                      if (!mounted) return;
                      await _reload();
                      if (mounted && deleted != null) _offerUndo(deleted);
                    },
                  ),
                ),
              ),
            const SizedBox(height: 8),
          ],
        ],
      ],
    );
  }
}

class _RangeSelector extends StatelessWidget {
  const _RangeSelector({
    required this.selected,
    required this.onSelected,
  });

  final ProgressRange selected;
  final ValueChanged<ProgressRange> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < ProgressRange.values.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            SizedBox(
              width: 80,
              child: SegmentChip(
                key: Key('progress-range-${ProgressRange.values[i].label}'),
                label: ProgressRange.values[i].label,
                selected: selected == ProgressRange.values[i],
                onTap: () => onSelected(ProgressRange.values[i]),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ExerciseFilter extends StatelessWidget {
  const _ExerciseFilter({
    required this.selected,
    required this.onSelected,
  });

  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          SegmentChip(
            label: context.tr('Tất cả', 'All exercises'),
            selected: selected == null,
            onTap: () => onSelected(null),
          ),
          for (final exercise in allExercises) ...[
            const SizedBox(width: 8),
            SegmentChip(
              label: exercise.localizedName(context.s),
              selected: selected == exercise.id,
              onTap: () => onSelected(exercise.id),
            ),
          ],
        ],
      ),
    );
  }
}

class _SummaryMetrics extends StatelessWidget {
  const _SummaryMetrics({required this.stats});

  final ProgressStatistics stats;

  @override
  Widget build(BuildContext context) {
    final average = stats.averageForm;
    final cards = <Widget>[
      MetricCard(
        label: context.tr('Tổng rep', 'Total reps'),
        value: '${stats.totalReps}',
      ),
      MetricCard(
        label: context.tr('Buổi tập', 'Sessions'),
        value: '${stats.sessions}',
      ),
      MetricCard(
        label: context.tr('Form TB', 'Avg form'),
        value: average == null ? '—' : '${average.round()}',
      ),
      MetricCard(
        label: context.tr('Đạt mục tiêu', 'Goals reached'),
        value: '${stats.goalsReached}',
      ),
    ];

    final largeText = MediaQuery.textScalerOf(context).scale(14) >= 21;
    if (largeText) {
      return Column(
        children: [
          for (var i = 0; i < cards.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            SizedBox(width: double.infinity, child: cards[i]),
          ],
        ],
      );
    }

    return Column(
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: cards[0]),
              const SizedBox(width: 22),
              Expanded(child: cards[1]),
            ],
          ),
        ),
        const SizedBox(height: 12),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: cards[2]),
              const SizedBox(width: 22),
              Expanded(child: cards[3]),
            ],
          ),
        ),
      ],
    );
  }
}

class _PersonalRecordsCard extends StatelessWidget {
  const _PersonalRecordsCard({required this.stats});

  final ProgressStatistics stats;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final hasExercise = stats.exerciseId != null;
    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.borderStrong),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 4,
            decoration: BoxDecoration(
              color: p.accent,
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(16),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 16, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionLabel(context.tr(
                    'Kỷ lục cá nhân',
                    'Personal records',
                  )),
                  if (!hasExercise)
                    Text(
                      context.tr(
                        'Chọn một bài tập để xem kỷ lục theo đúng bài và chế độ.',
                        'Choose one exercise to view mode-specific records.',
                      ),
                      style: AppTypography.body14.copyWith(color: p.text2),
                    )
                  else ...[
                    _PersonalRecordRow(
                      label: context.tr('Tập tự do', 'Free workout'),
                      value: stats.personalBestFree,
                    ),
                    const SizedBox(height: 10),
                    _PersonalRecordRow(
                      label: context.tr('60 giây', '60 sec'),
                      value: stats.personalBestTimed(60),
                    ),
                    const SizedBox(height: 10),
                    _PersonalRecordRow(
                      label: context.tr('90 giây', '90 sec'),
                      value: stats.personalBestTimed(90),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PersonalRecordRow extends StatelessWidget {
  const _PersonalRecordRow({
    required this.label,
    required this.value,
  });

  final String label;
  final int? value;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: value == null ? '$label: unavailable' : '$label: $value reps',
      child: Row(
        children: [
          Expanded(child: Text(label)),
          const SizedBox(width: 16),
          Text(
            value == null ? '—' : '$value rep',
            style: TextStyle(
              color: context.palette.accentInk,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendCard extends StatelessWidget {
  const _TrendCard({
    required this.stats,
    required this.selected,
    required this.onSelected,
  });

  final ProgressStatistics stats;
  final ProgressTrendMetric selected;
  final ValueChanged<ProgressTrendMetric> onSelected;

  @override
  Widget build(BuildContext context) {
    const lightSurface = Color(0xFFF7F7F5);
    const lightText = Color(0xFF171719);
    const lightText2 = Color(0xFF7C7C82);
    final values = _values();
    final meaningful = values
            .where((value) =>
                value != null &&
                (selected == ProgressTrendMetric.form || value > 0))
            .length >=
        2;
    final latest = values.reversed
        .whereType<double>()
        .where((value) => selected == ProgressTrendMetric.form || value > 0)
        .firstOrNull;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
      decoration: BoxDecoration(
        color: lightSurface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: DefaultTextStyle.merge(
        style: const TextStyle(color: lightText),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('XU HƯỚNG', 'TREND'),
              style: AppTypography.caption12.copyWith(color: lightText2),
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var i = 0;
                      i < ProgressTrendMetric.values.length;
                      i++) ...[
                    if (i > 0) const SizedBox(width: 7),
                    SegmentChip(
                      label: _metricLabel(
                        context,
                        ProgressTrendMetric.values[i],
                      ),
                      selected: selected == ProgressTrendMetric.values[i],
                      onTap: () => onSelected(ProgressTrendMetric.values[i]),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (!meaningful)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Text(
                  context.tr(
                    'Cần thêm dữ liệu để hiển thị xu hướng.',
                    'More data is needed to show a trend.',
                  ),
                  style: AppTypography.body14.copyWith(color: lightText2),
                ),
              )
            else
              _TrendBars(values: values),
            const SizedBox(height: 8),
            Text(
              latest == null
                  ? context.tr(
                      '${stats.range.label} · chưa có dữ liệu',
                      '${stats.range.label} · no data yet',
                    )
                  : '${stats.range.label} · ${context.tr('mới nhất', 'latest')} ${_formatLatest(context, latest)}',
              style: AppTypography.caption12.copyWith(color: lightText2),
            ),
          ],
        ),
      ),
    );
  }

  List<double?> _values() {
    final days = stats.range.days;
    final reps = stats.dailyReps;
    final sessions = stats.dailySessions;
    final duration = stats.dailyDurationSeconds;
    final form = stats.dailyForm;

    double? valueFor(DateTime date) => switch (selected) {
          ProgressTrendMetric.reps => (reps[date] ?? 0).toDouble(),
          ProgressTrendMetric.sessions => (sessions[date] ?? 0).toDouble(),
          ProgressTrendMetric.duration =>
            (duration[date] ?? 0).toDouble() / 60,
          ProgressTrendMetric.form => form[date],
        };

    if (days != null) {
      final start = stats.startDay!;
      return [
        for (var i = 0; i < days; i++)
          valueFor(start.add(Duration(days: i))),
      ];
    }

    final keys = <DateTime>{
      ...reps.keys,
      ...sessions.keys,
      ...duration.keys,
      ...form.keys,
    }.toList()
      ..sort();
    return [for (final key in keys) valueFor(key)];
  }

  String _metricLabel(BuildContext context, ProgressTrendMetric metric) =>
      switch (metric) {
        ProgressTrendMetric.reps => context.tr('Rep', 'Reps'),
        ProgressTrendMetric.sessions => context.tr('Buổi', 'Sessions'),
        ProgressTrendMetric.duration => context.tr('Thời lượng', 'Duration'),
        ProgressTrendMetric.form => 'Form',
      };

  String _formatLatest(BuildContext context, double value) => switch (selected) {
        ProgressTrendMetric.reps => '${value.round()} rep',
        ProgressTrendMetric.sessions => context.tr(
            '${value.round()} buổi',
            '${value.round()} sessions',
          ),
        ProgressTrendMetric.duration => context.tr(
            '${value.round()} phút',
            '${value.round()} min',
          ),
        ProgressTrendMetric.form => '${value.round()}',
      };
}

class _TrendBars extends StatelessWidget {
  const _TrendBars({required this.values});

  final List<double?> values;

  @override
  Widget build(BuildContext context) {
    final numeric = values.whereType<double>().toList();
    final max = numeric.isEmpty
        ? 1.0
        : numeric.reduce((a, b) => a > b ? a : b).clamp(1.0, double.infinity);
    return Semantics(
      label: context.tr(
        'Biểu đồ xu hướng gồm ${numeric.length} điểm dữ liệu.',
        'Trend chart with ${numeric.length} data points.',
      ),
      child: SizedBox(
        height: 58,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < values.length; i++) ...[
              if (i > 0) const SizedBox(width: 5),
              Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: values[i] == null
                      ? const SizedBox.shrink()
                      : Container(
                          height: 4 + (values[i]! / max) * 50,
                          decoration: BoxDecoration(
                            color: context.palette.accent,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HeatmapCard extends StatelessWidget {
  const _HeatmapCard({required this.stats});

  final ProgressStatistics stats;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final now = stats.today;
    final first = DateTime(now.year, now.month);
    final days = DateTime(now.year, now.month + 1, 0).day;
    final start = first.subtract(Duration(days: first.weekday - 1));
    final cells = ((first.weekday - 1 + days) / 7).ceil() * 7;
    final daily = stats.dailyReps;
    final monthValues = [
      for (var day = 1; day <= days; day++)
        daily[DateTime(now.year, now.month, day)] ?? 0,
    ];
    final max = monthValues.fold<int>(0, (a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.borderStrong),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionLabel(context.tr('Tần suất tập', 'Training frequency')),
          Semantics(
            label: context.tr(
              'Lịch tập tháng ${now.month}. Dấu chấm đánh dấu ngày có cường độ cao.',
              'Training calendar for month ${now.month}. A dot marks high-intensity days.',
            ),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: cells,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                crossAxisSpacing: 12,
                mainAxisSpacing: 5,
                childAspectRatio: 2.1,
              ),
              itemBuilder: (context, index) {
                final date = DateTime(
                  start.year,
                  start.month,
                  start.day + index,
                );
                final inMonth = date.month == now.month;
                if (!inMonth) return const SizedBox.shrink();
                final reps = daily[date] ?? 0;
                final ratio = max == 0 ? 0.0 : reps / max;
                final high = reps > 0 && ratio >= .67;
                final color = reps == 0
                    ? p.surface2
                    : ratio < .34
                        ? p.accentTint
                        : ratio < .67
                            ? p.accentBorder
                            : p.accent;
                return Semantics(
                  label: context.tr(
                    '${date.day}/${date.month}: $reps rep',
                    '${date.month}/${date.day}: $reps reps',
                  ),
                  child: Tooltip(
                    message: '${date.day}/${date.month}: $reps rep',
                    child: Container(
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      alignment: Alignment.center,
                      child: high
                          ? Text(
                              '•',
                              style: TextStyle(
                                color: p.onAccent,
                                fontSize: 11,
                                height: 1,
                                fontWeight: FontWeight.w900,
                              ),
                            )
                          : null,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                context.tr('Ít', 'Less'),
                style: AppTypography.caption12.copyWith(color: p.text3),
              ),
              const SizedBox(width: 6),
              _LegendBox(color: p.surface2),
              const SizedBox(width: 4),
              _LegendBox(color: p.accentTint),
              const SizedBox(width: 4),
              _LegendBox(color: p.accentBorder),
              const SizedBox(width: 4),
              _LegendBox(color: p.accent, dot: true),
              const SizedBox(width: 6),
              Text(
                context.tr('Nhiều', 'More'),
                style: AppTypography.caption12.copyWith(color: p.text3),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendBox extends StatelessWidget {
  const _LegendBox({required this.color, this.dot = false});

  final Color color;
  final bool dot;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: 18,
        height: 10,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(3),
        ),
        alignment: Alignment.center,
        child: dot
            ? Text(
                '•',
                style: TextStyle(
                  color: context.palette.onAccent,
                  height: .7,
                  fontSize: 9,
                ),
              )
            : null,
      ),
    );
  }
}

class _ProgressEmptyState extends StatelessWidget {
  const _ProgressEmptyState({required this.onTrain});

  final VoidCallback onTrain;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(top: 74),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 30),
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border(
                top: BorderSide(color: p.accent, width: 4),
                left: BorderSide(color: p.borderStrong),
                right: BorderSide(color: p.borderStrong),
                bottom: BorderSide(color: p.borderStrong),
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    color: p.surface2,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    LucideIcons.trendingUp,
                    size: 58,
                    color: p.text,
                  ),
                ),
                const SizedBox(height: 30),
                Text(
                  context.tr(
                    'Tiến bộ của bạn bắt đầu từ buổi tập đầu tiên.',
                    'Your progress starts with your first workout.',
                  ),
                  textAlign: TextAlign.center,
                  style: AppTypography.title20,
                ),
                const SizedBox(height: 14),
                Text(
                  context.tr(
                    'Hoàn thành một buổi để mở khóa xu hướng, kỷ lục và streak.',
                    'Complete a workout to unlock trends, records and streaks.',
                  ),
                  textAlign: TextAlign.center,
                  style: AppTypography.body14.copyWith(color: p.text2),
                ),
              ],
            ),
          ),
          const SizedBox(height: 170),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onTrain,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(context.tr('Tập ngay', 'Train now')),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RangeEmptyMessage extends StatelessWidget {
  const _RangeEmptyMessage({required this.onTrain});

  final VoidCallback onTrain;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              context.tr(
                'Chưa có buổi tập trong bộ lọc này.',
                'No workouts match this filter yet.',
              ),
              textAlign: TextAlign.center,
              style: AppTypography.title20,
            ),
            const SizedBox(height: 8),
            Text(
              context.tr(
                'Kỷ lục phía trên vẫn dùng toàn bộ lịch sử của bài tập đã chọn.',
                'Records above still use the full history for the selected exercise.',
              ),
              textAlign: TextAlign.center,
              style: TextStyle(color: context.palette.text2),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: onTrain,
              child: Text(context.tr('Tập ngay', 'Train now')),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 48),
      child: Column(
        children: [
          Text(context.tr('Không đọc được lịch sử.', 'Could not load history.')),
          TextButton(
            onPressed: onRetry,
            child: Text(context.tr('Thử lại', 'Retry')),
          ),
        ],
      ),
    );
  }
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({
    required this.record,
    required this.onOpen,
    required this.onDelete,
  });

  final WorkoutRecord record;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final r = record;
    final p = context.palette;
    final status = switch (r.mode) {
      WorkoutMode.timed => context.tr(
          'Thử thách ${r.challengeSeconds ?? r.durationSeconds} giây',
          '${r.challengeSeconds ?? r.durationSeconds}s challenge',
        ),
      WorkoutMode.targetReps => r.goalReached
          ? context.tr('Đạt mục tiêu', 'Goal reached')
          : '${r.targetReps == null || r.targetReps == 0 ? 0 : (r.reps / r.targetReps! * 100).round()}%',
      WorkoutMode.free => context.tr('Tập tự do', 'Free workout'),
    };

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
        leading: ExerciseIcon(
          exerciseId: r.exerciseId,
          color: p.accentInk,
          size: 30,
        ),
        title: Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              r.targetReps == null
                  ? '${r.reps} rep'
                  : '${r.reps}/${r.targetReps}',
              style: AppTypography.metric40.copyWith(fontSize: 28),
            ),
            Text(
              status,
              style: TextStyle(
                fontSize: 12,
                color: r.goalReached ? p.success : p.text2,
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${exerciseNameFor(r.exerciseId, context.s)} · ${r.durationSeconds ~/ 60}:${(r.durationSeconds % 60).toString().padLeft(2, '0')} · ${r.startedAt.hour.toString().padLeft(2, '0')}:${r.startedAt.minute.toString().padLeft(2, '0')}',
              style: TextStyle(color: p.text2, fontSize: 12),
            ),
            if (r.quality?.hasEnoughData == true)
              Text(
                'Form ${r.quality!.qualityScore}/100',
                style: TextStyle(color: p.text2, fontSize: 12),
              ),
            if (r.aiFeedback != null)
              Text(
                r.aiFeedback!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: p.text3, fontSize: 12),
              ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          tooltip: context.s.historyOptions,
          onSelected: (_) => onDelete(),
          itemBuilder: (_) => [
            PopupMenuItem(
              value: 'delete',
              child: Text(context.s.historyDeleteAction),
            ),
          ],
        ),
        onTap: onOpen,
      ),
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
