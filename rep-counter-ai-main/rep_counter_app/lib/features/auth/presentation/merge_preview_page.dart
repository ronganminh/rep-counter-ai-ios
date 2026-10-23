import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/i18n/l10n.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../widgets/app_button.dart';
import '../domain/merge_preview.dart';
import 'auth_widgets.dart';

enum MergeChoice { merge, keepOnPhone }

/// Phase 9 merge preview: what bringing guest workouts into the account
/// would do. Nothing leaves the phone from this screen; the caller performs
/// the upload (A-2) only after [MergeChoice.merge].
class MergePreviewPage extends StatelessWidget {
  const MergePreviewPage({super.key, required this.preview});
  final MergePreview preview;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
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
        if (preview.needsChoice > 0)
          row(const Key('merge-choice'), LucideIcons.gitCompare,
              l.authNeedsChoice, preview.needsChoice),
        const SizedBox(height: 24),
        AppButton(
            key: const Key('merge-confirm'),
            label: l.authMergeIntoMyAccount,
            onPressed: preview.hasWork
                ? () => Navigator.of(context).pop(MergeChoice.merge)
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
