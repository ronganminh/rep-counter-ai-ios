import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/i18n/l10n.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_feedback.dart';
import '../../../widgets/product_ui.dart';
import '../../../widgets/status_badges.dart';
import '../../auth/presentation/merge_preview_page.dart';
import '../sync_controller.dart';
import '../sync_scope.dart';

/// Home: the sync badge and the "bring your workouts" offer, for a
/// signed-in user with sync on. Nothing at all otherwise.
class SyncHomeStrip extends StatelessWidget {
  const SyncHomeStrip({super.key});

  @override
  Widget build(BuildContext context) {
    final sync = SyncScope.maybeOf(context);
    if (sync == null || !sync.signedIn) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: SyncStatusBadge(
                key: const Key('home-sync-badge'),
                state: sync.badge,
                count: sync.pending),
          ),
          if (sync.mergeOffered) ...[
            const SizedBox(height: 12),
            SyncMergeBanner(sync: sync),
          ],
        ],
      ),
    );
  }
}

/// "N workouts on this phone aren't in your account yet" + Bring them.
class SyncMergeBanner extends StatelessWidget {
  const SyncMergeBanner({super.key, required this.sync});
  final SyncController sync;

  @override
  Widget build(BuildContext context) => AppBanner(
        key: const Key('sync-merge-banner'),
        title: context.l10n.authBringWorkouts,
        body: context.l10n.syncMergeOffer(sync.undecided),
        actionLabel: context.l10n.authBringMyWorkouts,
        onAction: () => openMergeFlow(context, sync),
      );
}

/// Profile (signed in): sync state with "Sync now", the failure banner and
/// the merge offer.
class SyncAccountSection extends StatelessWidget {
  const SyncAccountSection({super.key});

  @override
  Widget build(BuildContext context) {
    final sync = SyncScope.maybeOf(context);
    if (sync == null || !sync.signedIn) return const SizedBox.shrink();
    final l = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (sync.badge == SyncBadgeState.failed) ...[
          AppBanner(
            key: const Key('sync-failed-banner'),
            title: l.syncFailedTitle,
            body: l.syncFailedBody,
            tone: AppBannerTone.warn,
            actionLabel: l.commonRetryNow,
            onAction: sync.syncNow,
          ),
          const SizedBox(height: 12),
        ],
        if (sync.mergeOffered) ...[
          SyncMergeBanner(sync: sync),
          const SizedBox(height: 12),
        ],
        Card(
          clipBehavior: Clip.antiAlias,
          child: SettingsRow(
            key: const Key('profile-sync-now'),
            icon: LucideIcons.refreshCw,
            title: l.fbSyncNow,
            trailing: SyncStatusBadge(state: sync.badge, count: sync.pending),
            onTap: sync.busy ? null : sync.syncNow,
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

/// Guest → account merge (P9-06): reads the account, shows the dry run,
/// then applies the choice. Nothing is uploaded before the user confirms;
/// a failed read changes nothing.
Future<void> openMergeFlow(BuildContext context, SyncController sync) async {
  final navigator = Navigator.of(context);
  final plan = await navigator.push<MergePlan>(MaterialPageRoute(
      builder: (_) => _MergeLoadingPage(load: sync.prepareMerge)));
  if (plan == null || !context.mounted) return;
  final choice = await navigator.push<MergeChoice>(MaterialPageRoute(
      builder: (_) => MergePreviewPage(preview: plan.preview)));
  if (!context.mounted) return;
  switch (choice) {
    case MergeChoice.merge || MergeChoice.mergeKeepPhone:
      await sync.applyMerge(plan,
          keepPhone: choice == MergeChoice.mergeKeepPhone);
      if (context.mounted) {
        AppToast.show(context, context.l10n.authWorkoutsAccount);
      }
    case MergeChoice.keepOnPhone:
      await sync.keepOnPhone();
    case null:
      break;
  }
}

class _MergeLoadingPage extends StatefulWidget {
  const _MergeLoadingPage({required this.load});
  final Future<MergePlan> Function() load;

  @override
  State<_MergeLoadingPage> createState() => _MergeLoadingPageState();
}

class _MergeLoadingPageState extends State<_MergeLoadingPage> {
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    setState(() => _failed = false);
    try {
      final plan = await widget.load();
      if (mounted) Navigator.of(context).pop(plan);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: _failed
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppBanner(
                      key: const Key('merge-load-failed'),
                      title: l.syncFailedTitle,
                      body: l.authWorkoutsStillPhoneRetrying,
                      tone: AppBannerTone.warn,
                    ),
                    const SizedBox(height: 16),
                    AppButton(
                        key: const Key('merge-load-retry'),
                        label: l.commonRetryNow,
                        onPressed: _run),
                  ],
                )
              : Center(
                  child: Semantics(
                    label: l.authBringWorkouts,
                    child: const CircularProgressIndicator(
                        color: AppColors.text2),
                  ),
                ),
        ),
      ),
    );
  }
}
