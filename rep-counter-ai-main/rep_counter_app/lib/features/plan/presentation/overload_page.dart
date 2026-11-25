import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/i18n/l10n.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/product_ui.dart';
import '../application/plan_repository.dart';
import '../data/overload_dismissals.dart';
import '../domain/overload_advisor.dart';
import '../domain/workout_plan.dart';
import 'plan_copy.dart';
import 'targets_editor_page.dart';

/// PL-1 rule 5: progressive overload is opt-in (off by default). Each
/// suggestion is offered with Accept / Edit / Dismiss; accepting changes
/// only sessions still to come, never completed ones.
///
/// With [proposed] (the AI coach v2, L-D43) the page reviews those changes
/// instead, in the same Accept / Edit / Dismiss flow; dismissing one only
/// drops it from this review.
class OverloadPage extends StatefulWidget {
  const OverloadPage(
      {super.key, this.repository, this.dismissals, this.proposed});

  final PlanRepository? repository;
  final OverloadDismissals? dismissals;
  final List<ProposedChange>? proposed;

  @override
  State<OverloadPage> createState() => _OverloadPageState();
}

class _OverloadPageState extends State<OverloadPage> {
  late final _repo = widget.repository ?? PlanRepository();
  late final _dismissals = widget.dismissals ?? OverloadDismissals();
  PlanView? _view;
  List<OverloadSuggestion> _suggestions = const [];
  late final List<ProposedChange>? _pending = widget.proposed?.toList();
  bool get _coach => _pending != null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final view = await _repo.load();
    final dismissed = await _dismissals.load();
    if (!mounted) return;
    setState(() {
      _view = view;
      _suggestions = view == null
          ? const []
          : _coach
              ? [for (final c in _pending!) c.suggestion]
              : OverloadAdvisor.suggest(view.plan, view.sessions, view.workouts,
                  dismissed: dismissed);
    });
  }

  Future<void> _toggle(bool on) async {
    await _repo.setProgressiveOverload(on);
    await _load();
  }

  Future<void> _accept(OverloadSuggestion s, ExerciseTarget target) async {
    await _repo.edit(OverloadAdvisor.apply(_view!.plan, s, target));
    _pending?.removeWhere((c) => identical(c.suggestion, s));
    await _load();
  }

  Future<void> _edit(OverloadSuggestion s) async {
    final edited = await Navigator.of(context).push<
        List<
            ExerciseTarget>>(MaterialPageRoute(
        builder: (_) => TargetsEditorPage(
            title: context.tr('Sửa mục tiêu', 'Edit target'),
            note: context.tr(
                'Áp dụng cho các buổi sắp tới. Buổi đã tập không đổi.',
                'Applies to upcoming sessions. Sessions already done stay as they are.'),
            targets: [s.proposed])));
    if (edited == null || edited.length != 1) return;
    await _accept(s, edited.single);
  }

  Future<void> _dismiss(OverloadSuggestion s) async {
    if (_coach) {
      _pending!.removeWhere((c) => identical(c.suggestion, s));
    } else {
      await _dismissals.add(s.key);
    }
    await _load();
  }

  String? _note(OverloadSuggestion s) {
    for (final c in _pending ?? const <ProposedChange>[]) {
      if (identical(c.suggestion, s)) return c.note;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final view = _view;
    return Scaffold(
      appBar: AppBar(
          title: Text(_coach
              ? context.tr('Gợi ý của HLV AI', 'AI coach suggestions')
              : context.tr('Gợi ý tăng dần', 'Progression suggestions'))),
      body: SafeArea(
        child: view == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  if (_coach) ...[
                    Text(
                        context.tr(
                            'Không có gì tự thay đổi: chấp nhận, sửa hoặc bỏ qua từng đề xuất. Chỉ các buổi sắp tới thay đổi.',
                            'Nothing changes on its own: accept, edit or dismiss each suggestion. Only upcoming sessions change.'),
                        style: AppTypography.body14
                            .copyWith(color: AppColors.text2)),
                    const SizedBox(height: 16),
                    if (_suggestions.isEmpty)
                      Text(
                          key: const Key('coach-changes-done'),
                          context.tr('Đã xem hết đề xuất.',
                              'All suggestions reviewed.'),
                          style: AppTypography.body14),
                  ] else
                    SwitchListTile(
                      key: const Key('overload-toggle'),
                      contentPadding: EdgeInsets.zero,
                      title: Text(context.tr(
                          'Đề xuất tăng mục tiêu', 'Suggest target increases')),
                      subtitle: Text(context.tr(
                          'Tắt theo mặc định. Không có gì tự thay đổi: bạn chọn chấp nhận, sửa hoặc bỏ qua từng đề xuất.',
                          'Off by default. Nothing changes on its own: you accept, edit or dismiss each suggestion.')),
                      value: view.plan.progressiveOverload,
                      onChanged: _toggle,
                    ),
                  if (!_coach) const SizedBox(height: 8),
                  Text(context.l10n.plansTargetsGeneralFitnessGuidance,
                      style: AppTypography.caption12
                          .copyWith(color: AppColors.text2)),
                  const SizedBox(height: 16),
                  if (!_coach && view.plan.progressiveOverload && _suggestions.isEmpty)
                    Text(
                        key: const Key('overload-none'),
                        context.tr(
                            'Chưa có đề xuất. Cần ít nhất 2 buổi trọn vẹn liên tiếp đạt mục tiêu.',
                            'No suggestions yet. They need at least 2 complete sessions in a row that met the target.'),
                        style: AppTypography.body14
                            .copyWith(color: AppColors.text2)),
                  for (final s in _suggestions) _card(view.plan, s),
                ],
              ),
      ),
    );
  }

  Widget _card(WorkoutPlan plan, OverloadSuggestion s) {
    final increase = s.kind == SuggestionKind.increase;
    final name = context.exerciseName(s.current.exerciseId);
    final template = context.templateName(plan, s.templateId);
    return Container(
      key: Key('suggestion-${s.templateId}-${s.index}'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(increase ? LucideIcons.trendingUp : LucideIcons.equal,
              color: increase ? AppColors.accent : AppColors.text2),
          const SizedBox(width: 8),
          Expanded(
              child: Text('$template · $name', style: AppTypography.row15)),
        ]),
        const SizedBox(height: 8),
        Text(
            increase
                ? '${context.targetText(s.current)} → ${context.targetText(s.proposed)}'
                : context.tr('Giữ ${context.targetText(s.current)}',
                    'Keep ${context.targetText(s.current)}'),
            style: AppTypography.title20),
        const SizedBox(height: 6),
        Text(
            _coach
                ? (_note(s)?.isNotEmpty ?? false)
                    ? _note(s)!
                    : context.tr(
                        'Đề xuất từ HLV AI dựa trên số liệu tập của bạn.',
                        'Suggested by your AI coach from your training numbers.')
                : increase
                    ? context.tr(
                        '${s.evidence} buổi gần nhất đều trọn vẹn và đạt mục tiêu, nên đề xuất tăng nhẹ khoảng 10%.',
                        'Your last ${s.evidence} sessions were complete and met the target, so a small step of about 10% is suggested.')
                    : context.tr(
                        'Chưa đủ buổi trọn vẹn đạt mục tiêu: nên giữ mục tiêu hiện tại.',
                        'Not enough complete sessions met this target yet: keeping it is suggested.'),
            style: AppTypography.body14.copyWith(color: AppColors.text2)),
        const SizedBox(height: 12),
        if (increase) ...[
          AppButton(
              key: Key('accept-${s.templateId}-${s.index}'),
              label: context.tr('Chấp nhận', 'Accept'),
              onPressed: () => _accept(s, s.proposed)),
          const SizedBox(height: 8),
          AppButton(
              key: Key('edit-${s.templateId}-${s.index}'),
              label: context.tr('Sửa', 'Edit'),
              variant: AppButtonVariant.secondary,
              onPressed: () => _edit(s)),
          const SizedBox(height: 8),
        ],
        AppButton(
            key: Key('dismiss-${s.templateId}-${s.index}'),
            label: increase
                ? context.tr('Bỏ qua', 'Dismiss')
                : context.tr('Đã hiểu', 'Got it'),
            variant: AppButtonVariant.ghost,
            onPressed: () => _dismiss(s)),
      ]),
    );
  }
}
