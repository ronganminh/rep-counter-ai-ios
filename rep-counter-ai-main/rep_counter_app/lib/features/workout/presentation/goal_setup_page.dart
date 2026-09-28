import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../camera_page.dart';
import '../../../core/i18n/locale_controller.dart';
import '../../../exercise.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../widgets/product_ui.dart';
import 'exercise_icon.dart';

class GoalSetupPage extends StatelessWidget {
  const GoalSetupPage({super.key, required this.profile});
  final ExerciseProfile profile;
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: Text(profile.localizedName(context.s))),
      body: SafeArea(
          child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: GoalSetupContent(
                  profile: profile,
                  onStart: (goal) => Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                          builder: (_) => CameraPage(
                              profile: profile, targetReps: goal)))))));
}

class GoalSetupContent extends StatefulWidget {
  const GoalSetupContent(
      {super.key, required this.profile, required this.onStart});
  final ExerciseProfile profile;
  final ValueChanged<int?> onStart;
  @override
  State<GoalSetupContent> createState() => _GoalSetupContentState();
}

class _GoalSetupContentState extends State<GoalSetupContent> {
  final _custom = TextEditingController();
  int? _goal = 20;
  bool _free = false;
  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              ExerciseIcon(
                  exerciseId: widget.profile.id,
                  color: AppColors.accent,
                  size: 40),
              const SizedBox(width: 12),
              Expanded(
                  child: Text(widget.profile.localizedName(context.s),
                      style: AppTypography.title20))
            ]),
            const SizedBox(height: 24),
            Text(context.tr('KẾ HOẠCH HÔM NAY', "TODAY'S PLAN"),
                style: AppTypography.display40),
            const SizedBox(height: 12),
            Text(
                context.tr(
                    'Chọn mục tiêu. Bạn vẫn có thể tập tiếp sau khi đạt.',
                    'Choose a goal. You can keep going after reaching it.'),
                style: const TextStyle(color: AppColors.text2, height: 1.5)),
            const SizedBox(height: 24),
            Wrap(spacing: 10, runSpacing: 10, children: [
              for (final value in [10, 20, 30, 50])
                ChoiceChip(
                    label: Text('$value rep'),
                    selected: !_free && _goal == value,
                    onSelected: (_) => setState(() {
                          _goal = value;
                          _free = false;
                          _custom.clear();
                        }))
            ]),
            const SizedBox(height: 16),
            TextField(
                controller: _custom,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(3)
                ],
                decoration: InputDecoration(
                    labelText: context.s.goalOther,
                    suffixText: 'rep',
                    filled: true,
                    fillColor: AppColors.surface2,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: AppColors.border))),
                onChanged: (text) => setState(() {
                      final n = int.tryParse(text);
                      _goal = n != null && n > 0 ? n : null;
                      _free = false;
                    })),
            const SizedBox(height: 16),
            FilterChip(
                label: Text(context.tr(
                    'Tập tự do · không mục tiêu', 'Free workout · no goal')),
                avatar: const Icon(LucideIcons.infinity, size: 18),
                selected: _free,
                onSelected: (value) => setState(() => _free = value)),
            const SizedBox(height: 28),
            FilledButton.icon(
                onPressed: !_free && _goal == null
                    ? null
                    : () => widget.onStart(_free ? null : _goal),
                icon: const Icon(LucideIcons.play, size: 22),
                label: Text(context.tr('BẮT ĐẦU', 'START'))),
            const SizedBox(height: 12),
            Text(widget.profile.localizedHint(context.s),
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppColors.text3, fontSize: 12, height: 1.5)),
          ]);
}
