import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/config/feature_flags.dart';
import '../../../core/i18n/locale_controller.dart';
import '../../../exercise.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../widgets/product_ui.dart';
import '../data/routine_store.dart';
import '../domain/routine_preset.dart';

class RoutineEditorPage extends StatefulWidget {
  const RoutineEditorPage({
    super.key,
    this.preset,
    this.store,
  });

  final RoutinePreset? preset;
  final RoutineStore? store;

  @override
  State<RoutineEditorPage> createState() => _RoutineEditorPageState();
}

class _RoutineEditorPageState extends State<RoutineEditorPage> {
  late final TextEditingController _name;
  late final TextEditingController _reps;
  late final TextEditingController _sets;
  late final TextEditingController _rest;
  late String _exerciseId;
  late bool _voice;
  bool _saving = false;

  List<ExerciseProfile> get _availableExercises => allExercises
      .where((profile) => FeatureFlags.visibleExerciseIds.contains(profile.id))
      .toList();

  @override
  void initState() {
    super.initState();
    final preset = widget.preset;
    _name = TextEditingController(text: preset?.name ?? '');
    _reps = TextEditingController(text: '${preset?.targetReps ?? 15}');
    _sets = TextEditingController(text: '${preset?.targetSets ?? 3}');
    _rest = TextEditingController(text: '${preset?.restSeconds ?? 60}');
    final available = _availableExercises;
    _exerciseId = preset != null &&
            available.any((profile) => profile.id == preset.exerciseId)
        ? preset.exerciseId
        : available.first.id;
    _voice = preset?.voiceCoachEnabled ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _reps.dispose();
    _sets.dispose();
    _rest.dispose();
    super.dispose();
  }

  bool get _valid {
    final reps = int.tryParse(_reps.text);
    final sets = int.tryParse(_sets.text);
    final rest = int.tryParse(_rest.text);
    return _name.text.trim().isNotEmpty &&
        reps != null &&
        reps > 0 &&
        sets != null &&
        sets > 0 &&
        rest != null &&
        rest >= 0;
  }

  Future<void> _save() async {
    if (!_valid || _saving) return;
    setState(() => _saving = true);
    final existing = widget.preset;
    final preset = RoutinePreset(
      id: existing?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      name: _name.text.trim(),
      exerciseId: _exerciseId,
      targetReps: int.parse(_reps.text),
      targetSets: int.parse(_sets.text),
      restSeconds: int.parse(_rest.text),
      voiceCoachEnabled: _voice,
    );
    try {
      await (widget.store ?? RoutineStore()).save(preset);
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(context.tr(
            'Không thể lưu routine. Hãy thử lại.',
            'Could not save the routine. Please retry.',
          )),
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
          children: [
            TextButton.icon(
              style: TextButton.styleFrom(alignment: Alignment.centerLeft),
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.chevron_left),
              label: Text(context.tr('Bài tập đã lưu', 'Saved routines')),
            ),
            const SizedBox(height: 12),
            Text(
              widget.preset == null
                  ? context.tr('TẠO ROUTINE', 'CREATE ROUTINE')
                  : context.tr('SỬA ROUTINE', 'EDIT ROUTINE'),
              style: AppTypography.display40,
            ),
            const SizedBox(height: 28),
            _FieldLabel(context.tr('Tên routine', 'Routine name')),
            TextField(
              key: const Key('routine-name'),
              controller: _name,
              textInputAction: TextInputAction.next,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: context.tr(
                  'Hít đất buổi sáng',
                  'Morning push-ups',
                ),
              ),
            ),
            const SizedBox(height: 20),
            _FieldLabel(context.tr('Bài tập', 'Exercise')),
            DropdownButtonFormField<String>(
              key: const Key('routine-exercise'),
              initialValue: _exerciseId,
              items: [
                for (final exercise in _availableExercises)
                  DropdownMenuItem(
                    value: exercise.id,
                    child: Text(exercise.localizedName(context.s)),
                  ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _exerciseId = value);
              },
            ),
            const SizedBox(height: 20),
            _FieldLabel(context.tr('Rep mỗi set', 'Reps per set')),
            TextField(
              key: const Key('routine-reps'),
              controller: _reps,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(3),
              ],
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(suffixText: 'rep'),
            ),
            const SizedBox(height: 20),
            _FieldLabel(context.tr('Số set', 'Number of sets')),
            TextField(
              key: const Key('routine-sets'),
              controller: _sets,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(2),
              ],
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 20),
            _FieldLabel(context.tr('Thời gian nghỉ', 'Rest duration')),
            TextField(
              key: const Key('routine-rest'),
              controller: _rest,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(4),
              ],
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                suffixText: context.tr('giây', 'sec'),
              ),
            ),
            const SizedBox(height: 28),
            Material(
              color: p.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: p.borderStrong),
              ),
              clipBehavior: Clip.antiAlias,
              child: SwitchListTile(
                key: const Key('routine-voice'),
                value: _voice,
                onChanged: (value) => setState(() => _voice = value),
                title: const Text('Voice Coach'),
                subtitle: Text(
                  context.tr(
                    'Dùng cài đặt giọng đọc hiện có của app',
                    'Uses the app’s existing voice coach',
                  ),
                  style: TextStyle(color: p.text2),
                ),
              ),
            ),
            const SizedBox(height: 28),
            FilledButton(
              key: const Key('save-routine'),
              onPressed: _valid && !_saving ? _save : null,
              child: Text(
                _saving
                    ? context.tr('Đang lưu…', 'Saving…')
                    : context.tr('Lưu routine', 'Save routine'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 10),
        child: Text(
          text.toUpperCase(),
          style: AppTypography.caption12.copyWith(color: context.palette.text2),
        ),
      );
}
