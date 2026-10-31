import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/i18n/l10n.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../widgets/app_button.dart';
import '../domain/merge_preview.dart';
import 'auth_widgets.dart';

enum MergeChoice {
  /// Merge; a workout that differs keeps the account's version.
  merge,

  /// Merge; a workout that differs keeps this phone's version.
  mergeKeepPhone,
  keepOnPhone,
}

/// Phase 9 merge preview: what bringing guest workouts into the account
/// would do. Nothing leaves the phone from this screen; the caller performs
/// the upload (A-2) only after [MergeChoice.merge] or
/// [MergeChoice.mergeKeepPhone]. Workouts that differ get one choice for
/// all of them; there is no "keep both", which would count them twice.
class MergePreviewPage extends StatefulWidget {
  const MergePreviewPage({super.key, required this.preview});
  final MergePreview preview;

  @override
  State<MergePreviewPage> createState() => _MergePreviewPageState();
}

class _MergePreviewPageState extends State<MergePreviewPage> {
  bool _keepPhone = false;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final preview = widget.preview;
    Widget row(Key key, IconData icon, String label, int n) => ListTile(
          key: key,
          contentPadding: EdgeInsets.zero,
          leading: Icon(icon, color: AppColors.text2),
          title: Text(label, style: AppTypography.body16),
          trailing:
              Text('$n', style: AppTypography.metric40.copyWith(fontSize: 24)),
        );
    return AuthScaffold(
      title: l.authBringWorkouts,
      body: l.authNothingLeavesPhoneUntil,
      children: [
        row(const Key('merge-already'), LucideIcons.circleCheck,
            l.authAlreadyAccount, preview.alreadyInAccount),
        row(const Key('merge-new'), LucideIcons.upload, l.authNewWillUpload,
            preview.toUpload),
        if (preview.needsChoice > 0) ...[
          row(const Key('merge-choice'), LucideIcons.gitCompare,
              l.authNeedsChoice, preview.needsChoice),
          const SizedBox(height: 16),
          Text(l.mergeConflictTitle(preview.needsChoice),
              style: AppTypography.title20),
          const SizedBox(height: 4),
          Text(l.authThereSNoKeep,
              style: AppTypography.body14.copyWith(color: AppColors.text2)),
          RadioGroup<bool>(
            groupValue: _keepPhone,
            onChanged: (v) => setState(() => _keepPhone = v ?? false),
            child: Column(children: [
              RadioListTile<bool>(
                  key: const Key('merge-keep-account'),
                  contentPadding: EdgeInsets.zero,
                  value: false,
                  title: Text(l.mergeKeepAccount)),
              RadioListTile<bool>(
                  key: const Key('merge-keep-phone'),
                  contentPadding: EdgeInsets.zero,
                  value: true,
                  title: Text(l.mergeKeepPhone)),
            ]),
          ),
        ],
        const SizedBox(height: 24),
        AppButton(
            key: const Key('merge-confirm'),
            label: l.authMergeIntoMyAccount,
            onPressed: preview.hasWork
                ? () => Navigator.of(context).pop(_keepPhone
                    ? MergeChoice.mergeKeepPhone
                    : MergeChoice.merge)
                : null),
        const SizedBox(height: 12),
        AppButton(
            key: const Key('merge-keep'),
            label: l.authKeepWorkoutsPhoneOnly,
            variant: AppButtonVariant.secondary,
            onPressed: () =>
                Navigator.of(context).pop(MergeChoice.keepOnPhone)),
      ],
    );
  }
}
