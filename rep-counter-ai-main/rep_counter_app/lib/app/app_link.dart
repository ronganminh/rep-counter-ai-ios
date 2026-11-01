import '../features/plan/application/plan_repository.dart';
import '../features/plan/domain/reminder_planner.dart';
import '../features/plan/domain/workout_plan.dart';
import '../features/workout/data/workout_history_store.dart';
import '../features/workout/data/workout_record.dart';
import 'app_tab_bar.dart';

/// N-2a: in-app destinations of `repcoach://` links (APP_NAVIGATION_MAP §5)
/// and of reminder taps. The OS hands `repcoach://` URLs to the app through
/// the URL type (iOS) and intent filter (Android) registered in X-1
/// (`os_links.dart`); universal links still need the domain files (BLOCKED,
/// 01_TASK_DEPENDENCIES §5).
enum AppLinkKind {
  planSession,
  workoutFeedback,
  inbox,
  membership,
  friendRequests,
  race,
  invite,
  challenge,
}

class AppLink {
  const AppLink(this.kind, [this.id]);

  final AppLinkKind kind;
  final String? id;

  /// `repcoach://…` from §5, or a reminder payload (`plan-session:<id>`).
  /// Anything else is ignored (null), never guessed.
  static AppLink? parse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    if (raw.startsWith(ReminderPlanner.payloadPrefix)) {
      final id = raw.substring(ReminderPlanner.payloadPrefix.length);
      return id.isEmpty ? null : AppLink(AppLinkKind.planSession, id);
    }
    final uri = Uri.tryParse(raw);
    if (uri == null || uri.scheme != 'repcoach') return null;
    final p = [uri.host, ...uri.pathSegments].where((s) => s.isNotEmpty);
    return switch (p.toList()) {
      ['plan', 'session', final id] => AppLink(AppLinkKind.planSession, id),
      ['workouts', final id, 'feedback'] =>
        AppLink(AppLinkKind.workoutFeedback, id),
      ['inbox'] => const AppLink(AppLinkKind.inbox),
      ['membership'] => const AppLink(AppLinkKind.membership),
      ['friends', 'requests'] => const AppLink(AppLinkKind.friendRequests),
      ['races', final id] => AppLink(AppLinkKind.race, id),
      ['invites', final id] => AppLink(AppLinkKind.invite, id),
      ['challenges', final id] => AppLink(AppLinkKind.challenge, id),
      _ => null,
    };
  }

  @override
  bool operator ==(Object other) =>
      other is AppLink && other.kind == kind && other.id == id;

  @override
  int get hashCode => Object.hash(kind, id);

  @override
  String toString() => 'AppLink($kind, $id)';
}

/// Why a link fell back instead of opening its destination.
enum LinkNotice {
  /// The session was already done: nothing new is started (Final B J20).
  sessionDone,

  /// The session no longer exists (plan replaced, ended or paused).
  sessionGone,

  /// The workout was deleted.
  workoutGone,

  /// Friends, races, invites and challenges need accounts, which are off.
  needsAccount,
}

sealed class LinkTarget {
  const LinkTarget();
}

class OpenSession extends LinkTarget {
  const OpenSession(this.sessionId);
  final String sessionId;
}

class OpenWorkout extends LinkTarget {
  const OpenWorkout(this.record);
  final WorkoutRecord record;
}

/// A tab, plus a notice when the link could not be followed.
/// The in-app inbox (NT-2).
class OpenInbox extends LinkTarget {
  const OpenInbox();
}

/// Friends (S-1), signed in or through the auth gate; [inviteCode] from a
/// `repcoach://invites/<code>` link is offered for acceptance.
class OpenFriends extends LinkTarget {
  const OpenFriends({this.inviteCode});
  final String? inviteCode;
}

class LinkFallback extends LinkTarget {
  const LinkFallback(this.tab, [this.notice]);
  final AppTab tab;
  final LinkNotice? notice;
}

/// Resolves a link against local data only; it never starts a workout.
class AppLinkRouter {
  AppLinkRouter(
      {PlanRepository? plans,
      Future<List<WorkoutRecord>> Function()? loadWorkouts,
      bool Function()? socialEnabled,
      bool Function()? inboxEnabled})
      : _plans = plans ?? PlanRepository(),
        _loadWorkouts = loadWorkouts ?? WorkoutHistoryStore().load,
        _social = socialEnabled ?? (() => false),
        _inbox = inboxEnabled ?? (() => false);

  final PlanRepository _plans;
  final Future<List<WorkoutRecord>> Function() _loadWorkouts;

  /// Whether Friends exists in this build (`ENABLE_SOCIAL` and accounts).
  final bool Function() _social;

  /// Whether the inbox exists in this build (`ENABLE_INBOX` and accounts).
  final bool Function() _inbox;

  Future<LinkTarget> resolve(AppLink link) async {
    switch (link.kind) {
      case AppLinkKind.planSession:
        final view = await _plans.load();
        PlannedSession? session;
        for (final s in view?.sessions ?? const <PlannedSession>[]) {
          if (s.id == link.id) session = s;
        }
        if (view == null ||
            session == null ||
            view.plan.status != PlanStatus.active ||
            session.state == SessionState.cancelled) {
          return const LinkFallback(AppTab.home, LinkNotice.sessionGone);
        }
        if (session.state == SessionState.completed) {
          return const LinkFallback(AppTab.home, LinkNotice.sessionDone);
        }
        return OpenSession(session.id);
      case AppLinkKind.workoutFeedback:
        for (final r in await _loadWorkouts()) {
          if (r.id == link.id) return OpenWorkout(r);
        }
        return const LinkFallback(AppTab.progress, LinkNotice.workoutGone);
      case AppLinkKind.inbox when _inbox():
        return const OpenInbox();
      case AppLinkKind.inbox:
        return const LinkFallback(AppTab.home);
      case AppLinkKind.membership:
        return const LinkFallback(AppTab.profile);
      case AppLinkKind.friendRequests when _social():
        return const OpenFriends();
      case AppLinkKind.invite when _social():
        return OpenFriends(inviteCode: link.id);
      case AppLinkKind.friendRequests:
      case AppLinkKind.race:
      case AppLinkKind.invite:
      case AppLinkKind.challenge:
        return const LinkFallback(AppTab.home, LinkNotice.needsAccount);
    }
  }
}
