import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../widgets/product_ui.dart';
import '../../workout/data/workout_history_store.dart';
import '../../workout/data/workout_record.dart';
import 'workout_export_service.dart';

typedef WorkoutExportRecordLoader = Future<List<WorkoutRecord>> Function();
typedef WorkoutExportShareCallback = Future<void> Function(
  WorkoutExportFile file,
  Rect? sharePositionOrigin,
);

enum _ExportUiState { idle, preparing, empty, failure }

class ExportDataSheet extends StatefulWidget {
  const ExportDataSheet({
    super.key,
    this.loadRecords,
    this.shareFile,
    this.service = const WorkoutExportService(),
  });

  final WorkoutExportRecordLoader? loadRecords;
  final WorkoutExportShareCallback? shareFile;
  final WorkoutExportService service;

  @override
  State<ExportDataSheet> createState() => _ExportDataSheetState();
}

class _ExportDataSheetState extends State<ExportDataSheet> {
  WorkoutExportFormat _format = WorkoutExportFormat.csv;
  bool _includeAi = false;
  _ExportUiState _state = _ExportUiState.idle;
  bool _cancelRequested = false;

  Future<List<WorkoutRecord>> _load() =>
      widget.loadRecords?.call() ?? WorkoutHistoryStore().load();

  Future<void> _share(WorkoutExportFile file, Rect? origin) async {
    final callback = widget.shareFile;
    if (callback != null) {
      await callback(file, origin);
      return;
    }
    await SharePlus.instance.share(ShareParams(
      files: [
        XFile.fromData(file.bytes, mimeType: file.mimeType),
      ],
      fileNameOverrides: [file.fileName],
      title: 'RepCoach workout history',
      sharePositionOrigin: origin,
    ));
  }

  Future<void> _createExport(BuildContext buttonContext) async {
    if (_state == _ExportUiState.preparing) return;
    final box = buttonContext.findRenderObject() as RenderBox?;
    final origin =
        box == null ? null : box.localToGlobal(Offset.zero) & box.size;

    setState(() {
      _state = _ExportUiState.preparing;
      _cancelRequested = false;
    });
    await Future<void>.delayed(Duration.zero);

    try {
      final records = await _load();
      if (!mounted) return;
      if (records.isEmpty) {
        setState(() => _state = _ExportUiState.empty);
        return;
      }

      final file = widget.service.build(
        records: records,
        format: _format,
        includeSavedAiFeedback: _includeAi,
      );
      if (_cancelRequested || !mounted) {
        if (mounted) setState(() => _state = _ExportUiState.idle);
        return;
      }

      await _share(file, origin);
      if (mounted && !_cancelRequested) Navigator.of(context).pop();
    } on EmptyWorkoutExport {
      if (mounted) setState(() => _state = _ExportUiState.empty);
    } catch (_) {
      if (mounted) setState(() => _state = _ExportUiState.failure);
    }
  }

  void _cancelPreparing() {
    _cancelRequested = true;
    setState(() => _state = _ExportUiState.idle);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SafeArea(
      top: false,
      child: Material(
        color: p.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .82,
          ),
          child: switch (_state) {
            _ExportUiState.preparing => _PreparingView(
                format: _format,
                onCancel: _cancelPreparing,
              ),
            _ExportUiState.empty => _EmptyView(
                onClose: () => Navigator.of(context).pop(),
              ),
            _ExportUiState.failure => _FailureView(
                onRetry: () => setState(() => _state = _ExportUiState.idle),
                onClose: () => Navigator.of(context).pop(),
              ),
            _ExportUiState.idle => _buildIdle(context),
          },
        ),
      ),
    );
  }

  Widget _buildIdle(BuildContext context) {
    final p = context.palette;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      children: [
        Center(
          child: Container(
            width: 61,
            height: 5,
            decoration: BoxDecoration(
              color: p.track,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          context.tr('XUẤT LỊCH SỬ TẬP LUYỆN', 'EXPORT WORKOUT HISTORY'),
          style: AppTypography.headline28,
        ),
        const SizedBox(height: 28),
        _FormatOption(
          key: const Key('export-format-csv'),
          title: 'CSV',
          subtitle: context.tr(
            'Phù hợp với bảng tính',
            'Spreadsheet-friendly',
          ),
          selected: _format == WorkoutExportFormat.csv,
          onTap: () => setState(() => _format = WorkoutExportFormat.csv),
        ),
        const SizedBox(height: 16),
        _FormatOption(
          key: const Key('export-format-json'),
          title: 'JSON',
          subtitle: context.tr(
            'Phù hợp để sao lưu hoặc sử dụng kỹ thuật',
            'Best for backup or technical use',
          ),
          selected: _format == WorkoutExportFormat.json,
          onTap: () => setState(() => _format = WorkoutExportFormat.json),
        ),
        const SizedBox(height: 20),
        Container(
          decoration: BoxDecoration(
            color: p.bg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: p.borderStrong),
          ),
          child: CheckboxListTile(
            key: const Key('export-include-ai'),
            value: _includeAi,
            onChanged: (value) => setState(() => _includeAi = value ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(context.tr(
              'Bao gồm nhận xét AI đã lưu',
              'Include saved AI feedback',
            )),
            subtitle: Text(
              context.tr('Mặc định tắt', 'Off by default'),
              style: AppTypography.caption12.copyWith(color: p.text3),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Semantics(
          label: context.tr(
            'Không bao gồm hình ảnh camera, video hoặc tọa độ pose.',
            'Does not include camera images, video, or pose landmarks.',
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(LucideIcons.shieldCheck, size: 18, color: p.success),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  context.tr(
                    'Không bao gồm hình ảnh camera, video hoặc tọa độ pose.',
                    'Camera images, video and pose landmarks are not included.',
                  ),
                  style: AppTypography.body14.copyWith(color: p.success),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        Builder(builder: (buttonContext) {
          return FilledButton(
            key: const Key('create-export'),
            onPressed: () => _createExport(buttonContext),
            child: Text(context.tr('Tạo file xuất', 'Create export')),
          );
        }),
      ],
    );
  }
}

class _FormatOption extends StatelessWidget {
  const _FormatOption({
    super.key,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      button: true,
      selected: selected,
      label: '$title, $subtitle',
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 104),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: p.bg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: selected ? p.accent : p.borderStrong),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.title20.copyWith(
                        color: selected ? p.accentInk : p.text,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: AppTypography.body14.copyWith(color: p.text2),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                selected ? '✓' : '○',
                style: AppTypography.title20.copyWith(
                  color: selected ? p.accentInk : p.text3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreparingView extends StatelessWidget {
  const _PreparingView({required this.format, required this.onCancel});

  final WorkoutExportFormat format;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final formatName = format == WorkoutExportFormat.csv ? 'CSV' : 'JSON';
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 44, 24, 24),
      children: [
        Text(
          context.tr('XUẤT LỊCH SỬ', 'EXPORT HISTORY'),
          style: AppTypography.display40,
        ),
        const SizedBox(height: 72),
        Center(
          child: SizedBox(
            width: 160,
            height: 160,
            child: CircularProgressIndicator(
              strokeWidth: 8,
              color: p.accent,
              backgroundColor: p.surface2,
            ),
          ),
        ),
        const SizedBox(height: 42),
        Text(
          context.tr('Đang tạo file xuất…', 'Creating export…'),
          textAlign: TextAlign.center,
          style: AppTypography.headline28,
        ),
        const SizedBox(height: 14),
        Text(
          context.tr(
            'Đang gom lịch sử tập luyện thành $formatName trên thiết bị.',
            'Preparing your workout history as $formatName on this device.',
          ),
          textAlign: TextAlign.center,
          style: AppTypography.body16.copyWith(color: p.text2),
        ),
        const SizedBox(height: 56),
        OutlinedButton(
          key: const Key('cancel-export'),
          onPressed: onCancel,
          child: Text(context.tr('Hủy', 'Cancel')),
        ),
      ],
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 44, 24, 24),
      children: [
        Text(context.tr('XUẤT LỊCH SỬ', 'EXPORT HISTORY'),
            style: AppTypography.display40),
        const SizedBox(height: 40),
        Container(
          padding: const EdgeInsets.fromLTRB(24, 30, 24, 28),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: p.borderStrong),
          ),
          child: Column(
            children: [
              Text('∅',
                  style: AppTypography.metric64.copyWith(color: p.text3)),
              const SizedBox(height: 18),
              Text(
                context.tr('Chưa có gì để xuất', 'Nothing to export yet'),
                textAlign: TextAlign.center,
                style: AppTypography.title20,
              ),
              const SizedBox(height: 8),
              Text(
                context.tr(
                  'Hãy hoàn thành một buổi tập trước.',
                  'Complete a workout first.',
                ),
                textAlign: TextAlign.center,
                style: AppTypography.body14.copyWith(color: p.text2),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        OutlinedButton(
          onPressed: onClose,
          child: Text(context.tr('Đóng', 'Close')),
        ),
      ],
    );
  }
}

class _FailureView extends StatelessWidget {
  const _FailureView({required this.onRetry, required this.onClose});

  final VoidCallback onRetry;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 44, 24, 24),
      children: [
        Text(context.tr('XUẤT LỊCH SỬ', 'EXPORT HISTORY'),
            style: AppTypography.display40),
        const SizedBox(height: 40),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: p.warning),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('!',
                  style: AppTypography.headline28.copyWith(color: p.warning)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr(
                        'Không thể tạo file xuất',
                        'Could not create export',
                      ),
                      style: AppTypography.title20,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      context.tr(
                        'Dữ liệu trên máy vẫn an toàn. Hãy thử lại.',
                        'Your local workout data is still safe. Please retry.',
                      ),
                      style: AppTypography.body14.copyWith(color: p.text2),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        FilledButton(
          key: const Key('retry-export'),
          onPressed: onRetry,
          child: Text(context.tr('Thử lại', 'Retry')),
        ),
        const SizedBox(height: 14),
        OutlinedButton(
          onPressed: onClose,
          child: Text(context.tr('Đóng', 'Close')),
        ),
      ],
    );
  }
}
