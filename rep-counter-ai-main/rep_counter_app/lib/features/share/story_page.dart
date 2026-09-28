import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:share_plus/share_plus.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/i18n/locale_controller.dart';
import '../../exercise.dart';
import '../../widgets/product_ui.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../workout/data/workout_record.dart';
import '../workout/presentation/widgets/workout_hud.dart';

class StoryExporter {
  Future<ShareResultStatus> share(Uint8List bytes, Rect origin) async =>
      (await SharePlus.instance.share(ShareParams(
        files: [XFile.fromData(bytes, mimeType: 'image/png')],
        fileNameOverrides: ['repcoach-workout.png'],
        sharePositionOrigin: origin,
      )))
          .status;
  Future<void> save(Uint8List bytes) async {
    if (!await Gal.hasAccess() && !await Gal.requestAccess()) {
      throw GalException(
          type: GalExceptionType.accessDenied,
          platformException: PlatformException(code: 'accessDenied'),
          stackTrace: StackTrace.current);
    }
    await Gal.putImageBytes(bytes,
        name: 'RepCoach-${DateTime.now().millisecondsSinceEpoch}');
  }
}

/// The export is a fixed 360x640 layout rendered at 3x, independent of screen size.
class StoryPage extends StatefulWidget {
  const StoryPage({super.key, required this.record, this.exporter});
  final WorkoutRecord record;
  final StoryExporter? exporter;
  @override
  State<StoryPage> createState() => _StoryPageState();
}

class _StoryPageState extends State<StoryPage> {
  final _capture = GlobalKey();
  late final _exporter = widget.exporter ?? StoryExporter();
  bool _busy = false;
  Future<void> _export(bool save, BuildContext originContext) async {
    if (_busy) return;
    final box = originContext.findRenderObject()! as RenderBox;
    final origin = box.localToGlobal(Offset.zero) & box.size;
    setState(() => _busy = true);
    try {
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      final boundary =
          _capture.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3);
      late Uint8List bytes;
      try {
        bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!
            .buffer
            .asUint8List();
      } finally {
        image.dispose();
      }
      if (!mounted) return;
      if (save) {
        await _exporter.save(bytes);
        if (mounted) {
          _notice(
              context.tr('Đã lưu ảnh vào thư viện.', 'Image saved to Photos.'));
        }
      } else {
        // Even "success" only means an action was selected. An unavailable
        // result means the platform cannot report it, not that sharing failed.
        await _exporter.share(bytes, origin);
      }
    } on GalException catch (error) {
      if (mounted) {
        _notice(error.type == GalExceptionType.accessDenied
            ? context.tr(
                'Chưa có quyền thêm ảnh. Hãy cho phép trong Cài đặt của thiết bị rồi thử lại.',
                'Photo access was denied. Allow adding photos in device Settings and retry.')
            : context.tr('Chưa lưu được ảnh. Kiểm tra dung lượng rồi thử lại.',
                'Could not save the image. Check available storage and retry.'));
      }
    } catch (_) {
      if (mounted) {
        _notice(context.tr('Chưa xuất được ảnh. Hãy thử lại.',
            'Could not export the image. Please retry.'));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _notice(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            title: Text(context.tr('Chia sẻ buổi tập', 'Share workout'))),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          Center(
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: AspectRatio(
                      aspectRatio: 9 / 16,
                      child: FittedBox(
                          fit: BoxFit.contain,
                          child: RepaintBoundary(
                              key: _capture,
                              child: MediaQuery(
                                  data: MediaQuery.of(context).copyWith(
                                      textScaler: TextScaler.noScaling),
                                  child: SizedBox(
                                      width: 360,
                                      height: 640,
                                      child: StoryCard(
                                          record: widget.record)))))))),
          const SizedBox(height: 16),
          Text(
              context.tr(
                  'Ảnh 1080 × 1920 · chỉ số liệu buổi tập, không có ảnh camera. Nội dung nhận xét dài được rút gọn trên ảnh.',
                  '1080 × 1920 image · workout statistics only, no camera image. Long feedback is shortened on the image.'),
              style: const TextStyle(color: AppColors.text2, fontSize: 12)),
        ]),
        bottomNavigationBar: SafeArea(
            top: false,
            child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Builder(
                      builder: (origin) => FilledButton.icon(
                          key: const Key('share-story'),
                          onPressed:
                              _busy ? null : () => _export(false, origin),
                          icon: const Icon(LucideIcons.share2),
                          label: Text(context.tr('Chia sẻ', 'Share')))),
                  const SizedBox(height: 8),
                  Builder(
                      builder: (origin) => OutlinedButton.icon(
                          key: const Key('save-story'),
                          onPressed: _busy ? null : () => _export(true, origin),
                          icon: const Icon(LucideIcons.download),
                          label: Text(context.tr('Lưu ảnh', 'Save image')))),
                  if (_busy)
                    const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: LinearProgressIndicator()),
                ]))),
      );
}

class StoryCard extends StatelessWidget {
  const StoryCard({super.key, required this.record});
  final WorkoutRecord record;
  @override
  Widget build(BuildContext context) {
    final r = record;
    final goal =
        r.targetReps != null && r.targetReps! > 0 ? r.targetReps : null;
    final name = allExercises
            .where((e) => e.id == r.exerciseId)
            .firstOrNull
            ?.localizedName(context.s) ??
        r.exerciseName;
    return ColoredBox(
        color: AppColors.bg,
        child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                      '${r.startedAt.day}.${r.startedAt.month}.${r.startedAt.year}',
                      style: const TextStyle(
                          color: AppColors.text2, fontSize: 14)),
                  const Spacer(),
                  SizedBox(
                      height: 150,
                      child: FittedBox(
                          fit: BoxFit.contain,
                          child: Text('${r.reps}',
                              style: AppTypography.hero.copyWith(
                                  fontSize: 220, color: AppColors.accent)))),
                  Text('REP · ${name.toUpperCase()}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: AppTypography.display40.copyWith(fontSize: 26)),
                  const SizedBox(height: 14),
                  Text(
                      '${r.sets} set · ${workoutTime(Duration(seconds: r.durationSeconds))}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.text2)),
                  const SizedBox(height: 14),
                  Row(children: [
                    Expanded(
                        child: _Metric(
                            r.quality?.hasEnoughData == true
                                ? '${r.quality!.qualityScore}/100'
                                : '—',
                            context.tr('Điểm form', 'Form score'))),
                    Expanded(
                        child: _Metric(
                            goal == null
                                ? '∞'
                                : r.reps == goal
                                    ? '100%'
                                    : r.reps > goal
                                        ? '+${r.reps - goal}'
                                        : '${(r.reps / goal * 100).round()}%',
                            goal == null
                                ? context.tr('Tập tự do', 'Free workout')
                                : r.reps == goal
                                    ? context.tr('Đạt mục tiêu', 'Goal reached')
                                    : r.reps > goal
                                        ? context.tr(
                                            'Vượt mục tiêu', 'Above goal')
                                        : context.tr(
                                            'Mục tiêu', 'Goal progress'))),
                  ]),
                  const SizedBox(height: 14),
                  if (r.aiFeedback?.trim().isNotEmpty == true)
                    Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.accentBorder)),
                        child: Text(r.aiFeedback!,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 14, height: 1.4))),
                  const Spacer(),
                  Text('REPCOACH AI',
                      textAlign: TextAlign.center,
                      style: AppTypography.display40.copyWith(fontSize: 24)),
                  const SizedBox(height: 8),
                  Text(context.tr('Mỗi rep đều có giá trị', 'Every rep counts'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.text3)),
                ])));
  }
}

class _Metric extends StatelessWidget {
  const _Metric(this.value, this.label);
  final String value, label;
  @override
  Widget build(BuildContext context) => Column(children: [
        FittedBox(
            child: Text(value,
                style: AppTypography.display40.copyWith(fontSize: 32))),
        Text(label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: AppColors.text2)),
      ]);
}
