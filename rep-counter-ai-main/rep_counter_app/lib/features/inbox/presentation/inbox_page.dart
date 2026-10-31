import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/os_links.dart';
import '../../../core/i18n/l10n.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../widgets/app_feedback.dart';
import '../inbox_controller.dart';
import '../push_inbox.dart';

/// Opens the inbox when it exists in this build and the user is signed in.
Future<void> openInbox(BuildContext context) async {
  final inbox = InboxScope.maybeOf(context);
  if (inbox == null || !inbox.signedIn) return;
  await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => InboxPage(controller: inbox)));
}

/// Home's bell (Final C Phase 10) with the unread count, as text for screen
/// readers (`notifBellLabel`). Nothing when the inbox is off or signed out.
class InboxBell extends StatelessWidget {
  const InboxBell({super.key});

  @override
  Widget build(BuildContext context) {
    final inbox = InboxScope.maybeOf(context);
    if (inbox == null || !inbox.signedIn) return const SizedBox.shrink();
    final n = inbox.unreadCount;
    return IconButton(
      key: const Key('home-inbox-bell'),
      tooltip: context.l10n.notifBellLabel(n),
      onPressed: () => openInbox(context),
      icon: Badge(
        isLabelVisible: n > 0,
        label: Text('$n'),
        child: const Icon(LucideIcons.bell),
      ),
    );
  }
}

/// NT-2 inbox: newest first, unread marked by a dot and the word, tap opens
/// the item's in-app link through the N-2a router (never over a workout).
class InboxPage extends StatefulWidget {
  const InboxPage({super.key, required this.controller, this.openLink});

  final InboxController controller;

  /// Where a tapped link goes; the app shell by default.
  final void Function(String link)? openLink;

  @override
  State<InboxPage> createState() => _InboxPageState();
}

class _InboxPageState extends State<InboxPage> {
  InboxController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    _c.addListener(_changed);
    WidgetsBinding.instance.addPostFrameCallback((_) => _c.refresh());
  }

  @override
  void dispose() {
    _c.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _open(InboxItem item) async {
    await _c.markRead(item);
    if (!mounted) return;
    Navigator.of(context).pop();
    (widget.openLink ?? InAppLinks.open)(item.link);
  }

  String _when(BuildContext context, DateTime t) {
    final local = t.toLocal();
    final loc = MaterialLocalizations.of(context);
    return '${loc.formatShortDate(local)} · '
        '${loc.formatTimeOfDay(TimeOfDay.fromDateTime(local))}';
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final items = _c.items;
    final unread = _c.unreadCount;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.notifInboxTitle),
        actions: [
          if (unread > 0)
            TextButton(
              key: const Key('inbox-read-all'),
              onPressed: _c.markAllRead,
              child: Text(l.notifMarkAllRead),
            ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _c.refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              if (_c.failed) ...[
                AppBanner(
                  key: const Key('inbox-failed'),
                  title: l.faScreenCouldnTLoad,
                  tone: AppBannerTone.warn,
                  actionLabel: l.commonRetryNow,
                  onAction: _c.refresh,
                ),
                const SizedBox(height: 16),
              ],
              if (unread > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(l.notifUnread(unread),
                      key: const Key('inbox-unread-count'),
                      style:
                          AppTypography.body14.copyWith(color: AppColors.text2)),
                ),
              if (!_c.loaded && !_c.failed)
                const Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (items.isEmpty && _c.loaded)
                Padding(
                  padding: const EdgeInsets.only(top: 40),
                  child: Column(children: [
                    const Icon(LucideIcons.inbox,
                        size: 40, color: AppColors.text2),
                    const SizedBox(height: 12),
                    Text(l.notifNoNotificationsYet,
                        key: const Key('inbox-empty'),
                        style: AppTypography.title20),
                    const SizedBox(height: 4),
                    Text(l.notifEmptyCaughtUp,
                        style: AppTypography.body14
                            .copyWith(color: AppColors.text2)),
                  ]),
                )
              else
                for (final item in items)
                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      key: Key('inbox-${item.id}'),
                      onTap: () => _open(item),
                      leading: _c.isUnread(item)
                          ? Semantics(
                              label: l.notifUnread3,
                              child: const Icon(Icons.circle,
                                  size: 10, color: AppColors.success))
                          : const SizedBox(width: 10),
                      title: Text(item.title,
                          style: AppTypography.body16.copyWith(
                              fontWeight: _c.isUnread(item)
                                  ? FontWeight.w700
                                  : FontWeight.w400)),
                      subtitle: Text(
                          [
                            if (item.body != null && item.body!.isNotEmpty)
                              item.body!,
                            _when(context, item.createdAt),
                          ].join('\n'),
                          style: AppTypography.body14
                              .copyWith(color: AppColors.text2)),
                      trailing: const Icon(LucideIcons.chevronRight, size: 18),
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
