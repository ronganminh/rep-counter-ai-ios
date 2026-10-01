import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../camera_page.dart';
import '../../../core/config/feature_flags.dart';
import '../../../core/i18n/locale_controller.dart';
import '../../../exercise.dart';
import '../../../theme/app_typography.dart';
import '../../../widgets/product_ui.dart';
import '../data/routine_store.dart';
import '../domain/routine_preset.dart';
import 'routine_editor_page.dart';

class RoutineListSection extends StatefulWidget {
  const RoutineListSection({super.key, this.store});

  final RoutineStore? store;

  @override
  State<RoutineListSection> createState() => _RoutineListSectionState();
}

class _RoutineListSectionState extends State<RoutineListSection> {
  late Future<List<RoutinePreset>> _routines;

  RoutineStore get _store => widget.store ?? RoutineStore();

  @override
  void initState() {
    super.initState();
    _routines = _store.load();
  }

  Future<void> _reload() async {
    final next = _store.load();
    setState(() => _routines = next);
    await next;
  }

  ExerciseProfile? _profileFor(String id) {
    for (final profile in allExercises) {
      if (profile.id == id &&
          FeatureFlags.visibleExerciseIds.contains(profile.id)) {
        return profile;
      }
    }
    return null;
  }

  Future<void> _edit([RoutinePreset? preset]) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => RoutineEditorPage(preset: preset, store: _store),
      ),
    );
    if (changed == true && mounted) await _reload();
  }

  Future<void> _delete(RoutinePreset preset) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('Xóa routine?', 'Delete routine?')),
        content: Text(preset.name),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.tr('Hủy', 'Cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              context.tr('Xóa', 'Delete'),
              style: TextStyle(color: context.palette.dangerText),
            ),
          ),
        ],
      ),
    );
    if (yes != true) return;
    await _store.delete(preset.id);
    if (mounted) await _reload();
  }

  void _start(RoutinePreset preset) {
    final profile = _profileFor(preset.exerciseId);
    if (profile == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(context.tr(
          'Bài tập này chưa khả dụng trong bản hiện tại.',
          'This exercise is not available in this build.',
        )),
      ));
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CameraPage(
          profile: profile,
          routine: preset.toSnapshot(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<RoutinePreset>>(
        future: _routines,
        builder: (context, snapshot) {
          final p = context.palette;
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return TextButton(
              onPressed: _reload,
              child: Text(context.tr('Tải lại routine', 'Reload routines')),
            );
          }
          final routines = snapshot.data ?? const <RoutinePreset>[];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionLabel(context.tr('Bài tập đã lưu', 'Saved routines')),
              for (final routine in routines) ...[
                _RoutineCard(
                  routine: routine,
                  exerciseName:
                      exerciseNameFor(routine.exerciseId, context.s),
                  onStart: () => _start(routine),
                  onEdit: () => _edit(routine),
                  onDelete: () => _delete(routine),
                ),
                const SizedBox(height: 12),
              ],
              InkWell(
                key: const Key('create-routine'),
                onTap: _edit,
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 90),
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  decoration: BoxDecoration(
                    color: p.surface2,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: p.accent),
                  ),
                  alignment: Alignment.centerLeft,
                  child: Text(
                    context.tr('+ Tạo routine', '+ Create routine'),
                    style: AppTypography.title20.copyWith(
                      color: p.accentInk,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      );
}

class _RoutineCard extends StatelessWidget {
  const _RoutineCard({
    required this.routine,
    required this.exerciseName,
    required this.onStart,
    required this.onEdit,
    required this.onDelete,
  });

  final RoutinePreset routine;
  final String exerciseName;
  final VoidCallback onStart, onEdit, onDelete;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.borderStrong),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(width: 4, color: p.accent),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 16, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(routine.name, style: AppTypography.title20),
                    const SizedBox(height: 6),
                    Text(
                      '${routine.targetSets} × ${routine.targetReps} · '
                      '${context.tr('Nghỉ', 'Rest')} ${routine.restSeconds} '
                      '${context.tr('giây', 'sec')} · $exerciseName',
                      style: AppTypography.body14.copyWith(color: p.text2),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        FilledButton(
                          key: Key('start-routine-${routine.id}'),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(112, 36),
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                          ),
                          onPressed: onStart,
                          child: Text(context.tr('Bắt đầu', 'Start')),
                        ),
                        TextButton.icon(
                          onPressed: onEdit,
                          icon: const Icon(LucideIcons.pencil, size: 16),
                          label: Text(context.tr('Sửa', 'Edit')),
                        ),
                        TextButton.icon(
                          onPressed: onDelete,
                          icon: const Icon(LucideIcons.trash2, size: 16),
                          label: Text(
                            context.tr('Xóa', 'Delete'),
                            style: TextStyle(color: p.dangerText),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
