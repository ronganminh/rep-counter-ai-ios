import 'package:flutter/material.dart';

import '../../../core/i18n/l10n.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/type_to_confirm_field.dart';

/// Where "Delete workout history" applies (D-20). Account deletion is a
/// separate flow (Profile › Delete account).
enum DeleteScope { phone, account, both }

/// D-20 history deletion with sync on: pick phone / account / both, then
/// type DELETE (XÓA). Returns the scope, or null when cancelled.
Future<DeleteScope?> showDeleteHistorySheet(BuildContext context) =>
    showModalBottomSheet<DeleteScope>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _DeleteHistorySheet(),
    );

class _DeleteHistorySheet extends StatefulWidget {
  const _DeleteHistorySheet();

  @override
  State<_DeleteHistorySheet> createState() => _DeleteHistorySheetState();
}

class _DeleteHistorySheetState extends State<_DeleteHistorySheet> {
  DeleteScope _scope = DeleteScope.phone;
  bool _confirmed = false;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final body = switch (_scope) {
      DeleteScope.phone => l.accountRemovesLocalWorkoutsSynced,
      DeleteScope.account => l.syncDeleteAccountBody,
      DeleteScope.both => l.syncDeleteBothBody,
    };
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
            20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(l.historyDeleteTitle, style: AppTypography.title22),
            ),
            const SizedBox(height: 12),
            RadioGroup<DeleteScope>(
              groupValue: _scope,
              onChanged: (v) => setState(() => _scope = v ?? _scope),
              child: Column(children: [
                for (final (scope, label) in [
                  (DeleteScope.phone, l.historyDeleteScopePhone),
                  (DeleteScope.account, l.historyDeleteScopeAccount),
                  (DeleteScope.both, l.historyDeleteScopeBoth),
                ])
                  RadioListTile<DeleteScope>(
                    key: Key('delete-scope-${scope.name}'),
                    contentPadding: EdgeInsets.zero,
                    value: scope,
                    title: Text(label),
                  ),
              ]),
            ),
            Text(body,
                key: const Key('delete-scope-body'),
                style: AppTypography.body14.copyWith(color: AppColors.text2)),
            const SizedBox(height: 8),
            Text(l.historyDeleteKeepsRewards,
                style: AppTypography.body14.copyWith(color: AppColors.text2)),
            const SizedBox(height: 16),
            TypeToConfirmField(
                onChanged: (ok) => setState(() => _confirmed = ok)),
            const SizedBox(height: 16),
            AppButton(
              key: const Key('delete-history-confirm'),
              label: l.historyDeleteTitle,
              variant: _confirmed
                  ? AppButtonVariant.destructiveConfirmed
                  : AppButtonVariant.danger,
              onPressed:
                  _confirmed ? () => Navigator.of(context).pop(_scope) : null,
            ),
            const SizedBox(height: 8),
            AppButton(
              label: l.commonCancel,
              variant: AppButtonVariant.ghost,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}
