import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/i18n/l10n.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_feedback.dart';
import '../../../widgets/product_ui.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/application/auth_scope.dart';
import '../../auth/presentation/auth_gate_page.dart';
import '../social.dart';
import '../supabase_social_api.dart';

/// Opens Friends, asking guests to sign in first and coming back here
/// afterwards (auth gate with return-to). [inviteCode] comes from a
/// `repcoach://invites/<code>` link and is offered for acceptance.
Future<void> openFriends(BuildContext context, {String? inviteCode}) async {
  final api = SocialScope.maybeOf(context);
  if (api == null) return;
  if (!await AuthGatePage.require(context, AuthGateReason.friends)) return;
  if (!context.mounted) return;
  await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => FriendsPage(api: api, inviteCode: inviteCode)));
}

/// S-1 Friends (Final C Phase 7): invite by link or code, accept or
/// decline requests, block, report, and this week's friends leaderboard of
/// camera-counted reps only (D-18). There is no search by name (Q6).
class FriendsPage extends StatefulWidget {
  const FriendsPage(
      {super.key,
      required this.api,
      this.inviteCode,
      this.exerciseId = 'push_up',
      this.share});

  final SocialApi api;
  final String? inviteCode;
  final String exerciseId;

  /// Opens the share sheet; tests replace it.
  final Future<void> Function(String text)? share;

  static String inviteLink(String code) => 'repcoach://invites/$code';

  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage> {
  List<FriendSummary>? _friends;
  List<LeaderboardRow>? _board;
  bool _failed = false, _busy = false;
  String? _invite;
  late final _code = TextEditingController(text: widget.inviteCode ?? '');
  final _nameField = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _code.dispose();
    _nameField.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final friends = await widget.api.friends();
      final board = await widget.api.leaderboard(widget.exerciseId);
      if (!mounted) return;
      setState(() {
        _friends = friends;
        _board = board;
        _failed = false;
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  String _error(Object e) {
    final l = context.l10n;
    return switch (e) {
      SocialError(code: 'invite_expired') => l.socialInviteExpired,
      SocialError(code: 'invite_used') => l.socialInviteUsed,
      SocialError(code: 'self') => l.socialInviteSelf,
      SocialError(code: 'blocked') => l.socialInviteBlocked,
      SocialError(code: 'not_found') => l.socialNoOneFound,
      SocialError(code: 'too_many_invites') => l.socialTooManyInvites,
      SocialError(code: 'too_many_reports') => l.socialTooManyReports,
      _ => l.socialNothingChangedCheckConnection,
    };
  }

  /// Runs a social call; refusals and failures become a toast, never a
  /// crash, and the list is reloaded after a change.
  Future<bool> _run(Future<void> Function() call, {String? done}) async {
    if (_busy) return false;
    setState(() => _busy = true);
    try {
      await call();
      if (mounted && done != null) AppToast.show(context, done);
      await _load();
      return true;
    } catch (e) {
      if (mounted) {
        AppToast.show(context, _error(e),
            icon: LucideIcons.circleAlert, iconColor: AppColors.warningText);
      }
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createInvite() => _run(() async {
        final code = await widget.api.createInvite();
        if (mounted) setState(() => _invite = code);
      });

  /// Opening someone's invite sends their friend request to me (the
  /// server's rule, Final C "the link opens a request to you"); I accept it
  /// in Requests.
  Future<void> _accept() async {
    final code = _code.text.trim();
    if (code.isEmpty) return;
    if (await _run(() => widget.api.acceptInvite(code),
        done: context.l10n.socialInviteOpened)) {
      _code.clear();
    }
  }

  Future<void> _saveName() async {
    final auth = AuthScope.maybeOf(context)?.state;
    final name = _nameField.text.trim();
    if (auth is! AuthSignedIn || name.isEmpty) return;
    await _run(() => widget.api.setDisplayName(auth.user.id, name),
        done: context.l10n.accountDisplayName);
  }

  Future<void> _block(FriendSummary f) async {
    final l = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.socialBlockTitle),
        content: Text(l.socialBlockBody),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l.commonCancel)),
          FilledButton(
              key: const Key('friends-block-confirm'),
              onPressed: () => Navigator.pop(context, true),
              child: Text(l.socialBlockAction)),
        ],
      ),
    );
    if (ok == true) await _run(() => widget.api.block(f.userId));
  }

  Future<void> _report(FriendSummary f) async {
    final result = await showModalBottomSheet<(String, bool)>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => const _ReportSheet());
    if (result == null || !mounted) return;
    final (reason, alsoBlock) = result;
    await _run(() async {
      await widget.api.report(f.userId, reason);
      if (alsoBlock) await widget.api.block(f.userId);
    }, done: context.l10n.socialReportSent);
  }

  String _name(String n) => n.trim().isEmpty ? context.l10n.socialNoName : n;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final friends = _friends;
    final requests = [
      for (final f in friends ?? const <FriendSummary>[])
        if (f.state == FriendState.requestReceived) f
    ];
    final others = [
      for (final f in friends ?? const <FriendSummary>[])
        if (f.state != FriendState.requestReceived) f
    ];
    return Scaffold(
      appBar: AppBar(title: Text(l.socialFriends)),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              if (_failed) ...[
                AppBanner(
                  key: const Key('friends-load-failed'),
                  title: l.socialCouldnTLoadFriends,
                  body: l.socialWorkoutsSafeTryAgain,
                  tone: AppBannerTone.warn,
                  actionLabel: l.commonRetryNow,
                  onAction: _load,
                ),
                const SizedBox(height: 16),
              ],
              SectionLabel(l.socialInviteFriend),
              Text(l.socialInviteOnlyBody,
                  style: AppTypography.body14.copyWith(color: AppColors.text2)),
              const SizedBox(height: 12),
              if (_invite == null)
                AppButton(
                  key: const Key('friends-create-invite'),
                  label: l.socialInviteFriend,
                  icon: LucideIcons.userPlus,
                  onPressed: _busy ? null : _createInvite,
                )
              else
                _InviteCard(
                    code: _invite!,
                    share: widget.share ??
                        (text) => SharePlus.instance
                            .share(ShareParams(text: text))
                            .then((_) {})),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(
                  child: TextField(
                    key: const Key('friends-code'),
                    controller: _code,
                    textCapitalization: TextCapitalization.none,
                    decoration:
                        InputDecoration(labelText: l.socialInviteCodeLabel),
                    onSubmitted: (_) => _accept(),
                  ),
                ),
                const SizedBox(width: 8),
                AppButton(
                  key: const Key('friends-accept-code'),
                  label: l.socialAdd,
                  expand: false,
                  variant: AppButtonVariant.secondary,
                  onPressed: _busy ? null : _accept,
                ),
              ]),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(
                  child: TextField(
                    key: const Key('friends-display-name'),
                    controller: _nameField,
                    maxLength: 80,
                    decoration: InputDecoration(
                        labelText: l.accountDisplayName, counterText: ''),
                    onSubmitted: (_) => _saveName(),
                  ),
                ),
                const SizedBox(width: 8),
                AppButton(
                  key: const Key('friends-save-name'),
                  label: l.commonSave,
                  expand: false,
                  variant: AppButtonVariant.secondary,
                  onPressed: _busy ? null : _saveName,
                ),
              ]),
              const SizedBox(height: 24),
              if (friends == null && !_failed)
                const Center(child: CircularProgressIndicator())
              else ...[
                if (requests.isNotEmpty) ...[
                  SectionLabel(l.socialRequests),
                  for (final f in requests)
                    Card(
                      key: Key('friend-request-${f.userId}'),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(_name(f.displayName),
                                style: AppTypography.body16),
                            Text(l.socialSentRequest,
                                style: AppTypography.body14
                                    .copyWith(color: AppColors.text2)),
                            const SizedBox(height: 12),
                            Row(children: [
                              Expanded(
                                child: AppButton(
                                  key: Key('friend-decline-${f.userId}'),
                                  label: l.socialDecline,
                                  variant: AppButtonVariant.secondary,
                                  onPressed: _busy
                                      ? null
                                      : () => _run(
                                          () => widget.api.respond(f.userId,
                                              accept: false),
                                          done: l.socialDeclinedValueTheyAren(
                                              _name(f.displayName))),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: AppButton(
                                  key: Key('friend-accept-${f.userId}'),
                                  label: l.socialAccept,
                                  onPressed: _busy
                                      ? null
                                      : () => _run(
                                          () => widget.api.respond(f.userId,
                                              accept: true),
                                          done: l.socialValueNowFriends(
                                              _name(f.displayName))),
                                ),
                              ),
                            ]),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                ],
                SectionLabel(l.socialFriends),
                if (others.isEmpty)
                  Text(l.socialTrainFriends,
                      style:
                          AppTypography.body14.copyWith(color: AppColors.text2))
                else
                  for (final f in others)
                    Card(
                      child: ListTile(
                        key: Key('friend-${f.userId}'),
                        title: Text(_name(f.displayName)),
                        subtitle: Text(switch (f.state) {
                          FriendState.requestSent => l.socialRequestSent,
                          FriendState.blocked => l.socialBlocked,
                          _ => l.socialFriends,
                        }),
                        trailing: f.state == FriendState.blocked
                            ? null
                            : PopupMenuButton<String>(
                                key: Key('friend-menu-${f.userId}'),
                                tooltip: l.socialMoreRemoveBlockReport,
                                onSelected: (v) =>
                                    v == 'block' ? _block(f) : _report(f),
                                itemBuilder: (_) => [
                                  PopupMenuItem(
                                      value: 'block',
                                      child: Text(l.socialBlockAction)),
                                  PopupMenuItem(
                                      value: 'report',
                                      child: Text(l.socialReport)),
                                ],
                              ),
                      ),
                    ),
                const SizedBox(height: 24),
                SectionLabel(l.socialLeaderboard),
                Text(l.socialOnlyCameraCountedPush,
                    style:
                        AppTypography.body14.copyWith(color: AppColors.text2)),
                const SizedBox(height: 8),
                if ((_board ?? const []).isEmpty)
                  Text(l.socialLeaderboardEmpty,
                      key: const Key('leaderboard-empty'),
                      style:
                          AppTypography.body14.copyWith(color: AppColors.text2))
                else
                  Card(
                    key: const Key('leaderboard'),
                    child: Column(children: [
                      for (final (i, row) in _board!.indexed)
                        ListTile(
                          leading: Text('${i + 1}',
                              style: AppTypography.title20),
                          title: Text(row.me
                              ? l.socialYou
                              : _name(row.displayName)),
                          trailing: Text('${row.reps}',
                              style: AppTypography.title20),
                        ),
                    ]),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _InviteCard extends StatelessWidget {
  const _InviteCard({required this.code, required this.share});
  final String code;
  final Future<void> Function(String text) share;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final link = FriendsPage.inviteLink(code);
    return Card(
      key: const Key('friends-invite-card'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText(code, style: AppTypography.title22),
            const SizedBox(height: 4),
            Text(l.socialInviteValid,
                style: AppTypography.body14.copyWith(color: AppColors.text2)),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              AppButton(
                key: const Key('friends-copy-code'),
                label: l.socialCopyCode,
                expand: false,
                variant: AppButtonVariant.secondary,
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: code));
                  if (context.mounted) AppToast.show(context, l.socialCopyCode);
                },
              ),
              AppButton(
                key: const Key('friends-share-invite'),
                label: l.socialShareInvite,
                expand: false,
                icon: LucideIcons.share2,
                onPressed: () => share('$link\n$code'),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

class _ReportSheet extends StatefulWidget {
  const _ReportSheet();

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  String? _reason;
  bool _block = false;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final reasons = [
      ('offensive_name', l.socialOffensiveNameAvatar),
      ('harassment', l.socialHarassmentUnwantedContact),
      ('cheating', l.socialCheatingChallenges),
      ('other', l.socialSomethingElse),
    ];
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.socialWhatSWrongAccount, style: AppTypography.title22),
            RadioGroup<String>(
              groupValue: _reason,
              onChanged: (v) => setState(() => _reason = v),
              child: Column(children: [
                for (final (id, label) in reasons)
                  RadioListTile<String>(
                    key: Key('report-$id'),
                    contentPadding: EdgeInsets.zero,
                    value: id,
                    title: Text(label),
                  ),
              ]),
            ),
            CheckboxListTile(
              key: const Key('report-also-block'),
              contentPadding: EdgeInsets.zero,
              value: _block,
              onChanged: (v) => setState(() => _block = v ?? false),
              title: Text(l.socialAlsoBlockAccount),
            ),
            Text(l.socialWeIncludeUsernameItem,
                style: AppTypography.body14.copyWith(color: AppColors.text2)),
            const SizedBox(height: 16),
            AppButton(
              key: const Key('report-send'),
              label: _reason == null ? l.socialPickReasonSend : l.socialReport,
              onPressed: _reason == null
                  ? null
                  : () => Navigator.of(context).pop((_reason!, _block)),
            ),
          ],
        ),
      ),
    );
  }
}
