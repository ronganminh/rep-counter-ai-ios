import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/i18n/l10n.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_radius.dart';
import '../../../theme/app_typography.dart';
import '../../../widgets/app_button.dart';
import '../../auth/presentation/auth_gate_page.dart';
import '../coach_v2.dart';
import 'coach_widgets.dart';

/// AC-03a `/coach/consent`: explains first, never forced (Final C §7,
/// P4-08a). Lists exactly what is sent and never sent. "Not now" returns to
/// where the user was and never blocks training. Pops `true` when agreed.
class CoachConsentPage extends StatelessWidget {
  const CoachConsentPage({super.key, this.store = const CoachConsentStore()});
  final CoachConsentStore store;

  /// Account first (D-11: the coach needs an account), then consent once.
  /// Resolves `true` when the user is signed in and agreed.
  static Future<bool> ensure(BuildContext context,
      {CoachConsentStore store = const CoachConsentStore(),
      Future<bool> Function(BuildContext)? requireAccount}) async {
    final signedIn = await (requireAccount ??
        (c) => AuthGatePage.require(c, AuthGateReason.coach))(context);
    if (!signedIn || !context.mounted) return false;
    if (await store.given()) return true;
    if (!context.mounted) return false;
    final ok = await Navigator.of(context, rootNavigator: true).push<bool>(
        MaterialPageRoute(builder: (_) => CoachConsentPage(store: store)));
    return ok == true;
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    Widget list(String title, List<String> items, bool sent) => CoachCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CoachCaption(title),
              const SizedBox(height: 8),
              for (final t in items)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(children: [
                    Icon(sent ? LucideIcons.check : LucideIcons.x,
                        size: 18,
                        color: sent ? AppColors.success : AppColors.text2),
                    const SizedBox(width: 10),
                    Expanded(child: Text(t, style: AppTypography.body14)),
                  ]),
                ),
            ],
          ),
        );
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: l.navBack,
          icon: const Icon(LucideIcons.chevronLeft),
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ),
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: ListView(
              key: const Key('coach-consent'),
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.accentTint,
                      borderRadius: BorderRadius.circular(AppRadius.r14),
                    ),
                    child: const Icon(LucideIcons.sparkle,
                        color: AppColors.accent, size: 32),
                  ),
                ),
                const SizedBox(height: 20),
                Semantics(
                    header: true,
                    child: Text(l.ptConsentTitle,
                        style: AppTypography.title22.copyWith(fontSize: 26))),
                const SizedBox(height: 10),
                Text(l.ptConsentBody,
                    style: AppTypography.body16
                        .copyWith(color: AppColors.textMuted)),
                const SizedBox(height: 16),
                list(l.ptSent, [l.ptSent1, l.ptSent2, l.ptSent3], true),
                const SizedBox(height: 12),
                list(
                    l.ptNeverSent, [l.ptNever1, l.ptNever2, l.ptNever3], false),
                const SizedBox(height: 16),
                Text('${l.ptConsentCredits} ${l.ptConsentOff}',
                    style:
                        AppTypography.body14.copyWith(color: AppColors.text2)),
                const SizedBox(height: 12),
                const CoachDisclaimer(),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Column(children: [
              AppButton(
                key: const Key('coach-consent-on'),
                label: l.ptTurnOn,
                onPressed: () async {
                  await store.give();
                  if (context.mounted) Navigator.of(context).pop(true);
                },
              ),
              const SizedBox(height: 10),
              AppButton(
                key: const Key('coach-consent-not-now'),
                label: l.commonNotNow,
                variant: AppButtonVariant.secondary,
                onPressed: () => Navigator.of(context).pop(false),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
