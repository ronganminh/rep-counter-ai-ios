import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/i18n/l10n.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_radius.dart';
import '../../../theme/app_typography.dart';
import '../../../widgets/product_ui.dart';
import '../coach_v2.dart';
import 'coach_consent_page.dart';

/// Settings › AI privacy rows for AI Coach (AC-05a, the part shipped now):
/// the AI Coach switch (consent; turning it off withdraws it, as the
/// consent screen promises) and Body check-in shown OFF and not tappable,
/// "later release" (D-37). The body check-in flow itself is not built.
class CoachPrivacyRows extends StatefulWidget {
  const CoachPrivacyRows(
      {super.key, this.store = const CoachConsentStore(), this.requireAccount});
  final CoachConsentStore store;
  final Future<bool> Function(BuildContext)? requireAccount;

  @override
  State<CoachPrivacyRows> createState() => _CoachPrivacyRowsState();
}

class _CoachPrivacyRowsState extends State<CoachPrivacyRows> {
  bool? _on;

  @override
  void initState() {
    super.initState();
    _read();
  }

  Future<void> _read() async {
    final on = await widget.store.given();
    if (mounted) setState(() => _on = on);
  }

  Future<void> _set(bool on) async {
    if (on) {
      await CoachConsentPage.ensure(context,
          store: widget.store, requireAccount: widget.requireAccount);
    } else {
      await widget.store.withdraw();
    }
    await _read();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsRow(
          key: const Key('settings-ai-coach'),
          icon: LucideIcons.messageCircle,
          title: l.ptBodyAiCoachRow,
          subtitle: l.ptBodyAiCoachSub,
          trailing: Switch(
              key: const Key('settings-ai-coach-switch'),
              value: _on ?? false,
              onChanged: _on == null ? null : _set),
        ),
        Semantics(
          key: const Key('settings-body-check-in'),
          enabled: false,
          child: SettingsRow(
            icon: LucideIcons.scanFace,
            title: l.ptBodyRow,
            subtitle: l.ptBodyRowSub,
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: BorderRadius.circular(AppRadius.r6),
              ),
              child: Text(l.ptBodyBeta,
                  style: AppTypography.caption12.copyWith(
                      color: AppColors.text2, fontWeight: FontWeight.w700)),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Text(l.ptBodyRowNote,
              style: AppTypography.caption12.copyWith(color: AppColors.text2)),
        ),
      ],
    );
  }
}
