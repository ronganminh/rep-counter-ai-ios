import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../theme/app_colors.dart';
import '../../../../widgets/product_ui.dart';
import '../../data/workout_record.dart';

/// Charts stored observations only; never classifies speed using UI thresholds.
class RepPaceChart extends StatefulWidget {
  const RepPaceChart({super.key, required this.record});
  final WorkoutRecord record;
  @override
  State<RepPaceChart> createState() => _RepPaceChartState();
}

class _RepPaceChartState extends State<RepPaceChart> {
  int? _selected;
  @override
  void didUpdateWidget(RepPaceChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.record != widget.record) _selected = null;
  }

  String _flags(BuildContext context, StoredRep rep) {
    if (rep.qualityFlags == null) {
      return rep.flagged
          ? context.tr('Có lưu ý chất lượng; bản ghi cũ chưa lưu loại lưu ý.',
              'Quality note recorded; this older workout has no note category.')
          : context.tr('Bản ghi cũ chưa lưu loại lưu ý chất lượng.',
              'Quality note categories were not saved for this older workout.');
    }
    if (rep.qualityFlags!.isEmpty) {
      return context.tr('Không có lưu ý chất lượng được ghi nhận.',
          'No quality notes were recorded.');
    }
    return rep.qualityFlags!
        .map((flag) => switch (flag) {
              'tooFast' => context.tr('Nhịp quá nhanh', 'Too fast'),
              'tooSlow' => context.tr('Nhịp chậm', 'Slow pace'),
              'shallow' => context.tr('Biên độ ngắn', 'Short range of motion'),
              'incompleteLockout' =>
                context.tr('Chưa duỗi đủ', 'Incomplete lockout'),
              'leftRightUneven' =>
                context.tr('Hai bên chưa đều', 'Uneven sides'),
              'bodyAlignmentLost' =>
                context.tr('Thân chưa thẳng', 'Body alignment note'),
              'poseUnreliable' => context.tr('Pose chưa rõ', 'Unreliable pose'),
              _ => context.tr('Lưu ý chất lượng khác', 'Other quality note'),
            })
        .join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.record;
    final reps = r.repDetails;
    if (reps == null ||
        reps.isEmpty ||
        reps.any((rep) =>
            !rep.seconds.isFinite || rep.seconds <= 0 || rep.setIndex < 1)) {
      return Text(
          context.tr('Buổi tập này chưa có dữ liệu nhịp từng rep.',
              'Per-rep timing is unavailable for this workout.'),
          key: const Key('pace-unavailable'),
          style: const TextStyle(color: AppColors.text3));
    }
    final groups = <int, List<int>>{};
    for (var i = 0; i < reps.length; i++) {
      groups.putIfAbsent(reps[i].setIndex, () => []).add(i);
    }
    final maxSeconds = reps.map((r) => r.seconds).reduce(math.max);
    final mean = maxSeconds *
        (reps.fold<double>(0, (sum, r) => sum + r.seconds / maxSeconds) /
                reps.length)
            .clamp(0.0, 1.0);
    final knownFlags = reps.where((r) => r.qualityFlags != null).length;
    final fast = reps.where((r) => r.tooFast).length;
    final selected = _selected;
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                      context.tr('Giây / rep · vuốt ngang, chạm cột để xem',
                          'Seconds / rep · swipe horizontally, tap for details'),
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.text2)),
                  const SizedBox(height: 12),
                  Text(
                      context.tr(
                          'Trung bình dữ liệu đã lưu: ${mean.toStringAsFixed(2)} s/rep',
                          'Recorded average: ${mean.toStringAsFixed(2)} s/rep'),
                      key: const Key('pace-average'),
                      style: const TextStyle(color: AppColors.text2)),
                  if (reps.length != r.reps) ...[
                    const SizedBox(height: 8),
                    Text(
                        context.tr(
                            'Có chi tiết ${reps.length}/${r.reps} rep. Tổng buổi tập giữ nguyên.',
                            'Details available for ${reps.length}/${r.reps} reps. Session totals are unchanged.'),
                        style: const TextStyle(color: AppColors.warningText)),
                  ],
                  const SizedBox(height: 16),
                  SingleChildScrollView(
                      key: const Key('pace-scroll'),
                      scrollDirection: Axis.horizontal,
                      child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final group in groups.entries)
                              Padding(
                                  padding: const EdgeInsets.only(right: 16),
                                  child: SizedBox(
                                      width: math.max(
                                          132, group.value.length * 44.0),
                                      child: Column(children: [
                                        SizedBox(
                                            height: 164,
                                            child: Stack(children: [
                                              Positioned(
                                                  left: 0,
                                                  right: 0,
                                                  bottom: 22 +
                                                      mean / maxSeconds * 120,
                                                  child: const Divider(
                                                      height: 1,
                                                      color: AppColors.text3)),
                                              Align(
                                                  alignment:
                                                      Alignment.bottomLeft,
                                                  child: Row(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .end,
                                                      children: [
                                                        for (final i
                                                            in group.value)
                                                          Semantics(
                                                              button: true,
                                                              selected:
                                                                  selected == i,
                                                              label:
                                                                  'Rep ${i + 1}, set ${group.key}, ${reps[i].seconds.toStringAsFixed(2)} s. ${_flags(context, reps[i])}',
                                                              child: InkWell(
                                                                  key: ValueKey(
                                                                      'pace-rep-${i + 1}'),
                                                                  onTap: () =>
                                                                      setState(() =>
                                                                          _selected =
                                                                              i),
                                                                  borderRadius:
                                                                      BorderRadius
                                                                          .circular(
                                                                              8),
                                                                  child: ExcludeSemantics(
                                                                      child: SizedBox(
                                                                          width: 44,
                                                                          height: 164,
                                                                          child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                                                                            if (reps[i].tooFast)
                                                                              const Icon(LucideIcons.circleAlert, size: 12, color: AppColors.warning),
                                                                            const SizedBox(height: 4),
                                                                            Container(
                                                                                width: selected == i ? 18 : 12,
                                                                                height: math.max(2, reps[i].seconds / maxSeconds * 120),
                                                                                decoration: BoxDecoration(color: reps[i].flagged || reps[i].tooFast ? AppColors.warning : AppColors.accent, borderRadius: BorderRadius.circular(3))),
                                                                            const SizedBox(height: 6),
                                                                            SizedBox(
                                                                                height: 16,
                                                                                child: FittedBox(fit: BoxFit.scaleDown, child: Text('${i + 1}', style: const TextStyle(fontSize: 11, color: AppColors.text2)))),
                                                                          ]))))),
                                                      ])),
                                            ])),
                                        const SizedBox(height: 10),
                                        Text(
                                            'Set ${group.key} · ${group.value.length} rep',
                                            key: ValueKey(
                                                'pace-set-${group.key}'),
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600)),
                                      ]))),
                          ])),
                  const SizedBox(height: 16),
                  Text(
                      context.tr(
                          'Cam: có lưu ý chất lượng · Đường ngang: nhịp trung bình đã lưu',
                          'Orange: quality note · Horizontal line: recorded average'),
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.text3)),
                  const SizedBox(height: 12),
                  if (knownFlags == reps.length)
                    Text(
                        fast == 0
                            ? context.tr(
                                'Không có rep quá nhanh trong dữ liệu nhịp đã lưu.',
                                'No fast reps in the recorded timing details.')
                            : context.tr(
                                '$fast rep quá nhanh trong dữ liệu nhịp đã lưu.',
                                '$fast fast reps in the recorded timing details.'),
                        key: const Key('pace-fast-summary'),
                        style: TextStyle(
                            color: fast > 0
                                ? AppColors.warningText
                                : AppColors.text2))
                  else
                    Text(
                        context.tr(
                            'Bản ghi chưa lưu đủ loại lưu ý để kết luận số rep quá nhanh.',
                            'Not enough note categories were saved to determine the fast-rep count.'),
                        key: const Key('pace-flags-unavailable'),
                        style: const TextStyle(color: AppColors.text3)),
                  if (selected != null) ...[
                    const SizedBox(height: 16),
                    Semantics(
                        liveRegion: true,
                        child: Container(
                            key: const Key('pace-selection'),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                                color: AppColors.surface2,
                                borderRadius: BorderRadius.circular(12)),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                      'Rep ${selected + 1} · Set ${reps[selected].setIndex} · ${reps[selected].seconds.toStringAsFixed(2)} s',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 8),
                                  Text(_flags(context, reps[selected]),
                                      style: const TextStyle(
                                          color: AppColors.text2, height: 1.4)),
                                ]))),
                  ],
                ])));
  }
}
