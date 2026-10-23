import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/i18n/l10n.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../widgets/app_button.dart';
import '../data/workout_draft_store.dart';
import '../data/workout_history_store.dart';
import 'widgets/discard_confirm.dart';
import 'widgets/workout_hud.dart' show workoutTime;

enum RecoveryOutcome { savedPartial, discarded }

/// W-5 / FA-10e: an unfinished workout was found at launch. The user must
/// choose: save it as one partial record, or discard it after a second
/// confirmation. Nothing is ever discarded silently, also after the
/// recovery window (D-06, decision log L-D17). Resume needs an engine change
/// and is not offered (L-D17).
class RecoveryPage extends StatefulWidget {
  const RecoveryPage(
      {super.key,
      required this.draft,
      this.store,
      this.history,
      this.now = DateTime.now});

  final WorkoutDraft draft;
  final WorkoutDraftStore? store;
  final WorkoutHistoryStore? history;
  final DateTime Function() now;

  /// Shows [RecoveryPage] for the pending draft, if any. Returns the outcome,
  /// or null when there was nothing to recover.
  static Future<RecoveryOutcome?> showIfPending(BuildContext context,
      {WorkoutDraftStore? store, WorkoutHistoryStore? history}) async {
    final drafts = store ?? WorkoutDraftStore();
    final draft = await drafts.pendingRecovery(history: history);
    if (draft == null || !context.mounted) return null;
    return Navigator.of(context).push<RecoveryOutcome>(MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) =>
            RecoveryPage(draft: draft, store: drafts, history: history)));
  }

  @override
  State<RecoveryPage> createState() => _RecoveryPageState();
}

class _RecoveryPageState extends State<RecoveryPage> {
  late final _store = widget.store ?? WorkoutDraftStore();
  bool _busy = false;
  String? _error;

  Future<void> _savePartial() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _store.savePartial(widget.draft, history: widget.history);
      if (mounted) Navigator.of(context).pop(RecoveryOutcome.savedPartial);
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = context.l10n.legacyCameraPageCouldNotSaveWorkout;
        });
      }
    }
  }

  Future<void> _discard() async {
    if (_busy || !await confirmDiscardWorkout(context) || !mounted) return;
    setState(() => _busy = true);
    await _store.clear();
    if (mounted) Navigator.of(context).pop(RecoveryOutcome.discarded);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n, d = widget.draft;
    final expired = d.isExpired(widget.now());
    return PopScope(
      // A choice is required: leaving would let the next workout overwrite
      // the draft, which would be a silent discard.
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: const BoxDecoration(
                          color: AppColors.accentTint, shape: BoxShape.circle),
                      child: const Icon(LucideIcons.history,
                          color: AppColors.accent, size: 32),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(l.recoveryTitle,
                      key: const Key('recovery-title'),
                      textAlign: TextAlign.center,
                      style: AppTypography.title22),
                  const SizedBox(height: 10),
                  Text(
                      expired
                          ? l.recoveryExpiredBody(
                              d.reps, WorkoutDraft.recoveryWindow.inHours)
                          : l.recoveryBody(d.reps),
                      key: const Key('recovery-body'),
                      textAlign: TextAlign.center,
                      style: AppTypography.body16
                          .copyWith(color: AppColors.textMuted)),
                  const SizedBox(height: 8),
                  Text(
                      '${d.exerciseName} · ${d.sets} set · ${workoutTime(Duration(seconds: d.durationSeconds))}',
                      textAlign: TextAlign.center,
                      style: AppTypography.body14
                          .copyWith(color: AppColors.text2)),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Semantics(
                      liveRegion: true,
                      child: Text(_error!,
                          textAlign: TextAlign.center,
                          style: AppTypography.body14
                              .copyWith(color: AppColors.warningText)),
                    ),
                  ],
                  const SizedBox(height: 28),
                  AppButton(
                      key: const Key('recovery-save-partial'),
                      label: l.recoverySavePartial,
                      icon: LucideIcons.save,
                      loading: _busy,
                      onPressed: _busy ? null : _savePartial),
                  const SizedBox(height: 12),
                  AppButton(
                      key: const Key('recovery-discard'),
                      label: l.workoutDiscardEllipsis,
                      variant: AppButtonVariant.danger,
                      onPressed: _busy ? null : _discard),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
