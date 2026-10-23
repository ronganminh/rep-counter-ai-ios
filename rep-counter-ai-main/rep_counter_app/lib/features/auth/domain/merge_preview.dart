import 'package:flutter/foundation.dart';

/// What "Bring your workouts" would do (Phase 9 merge preview). Workouts are
/// matched by their stable `client_id` (F-3), so nothing is counted twice.
/// The upload itself is A-2 and needs the backend.
@immutable
class MergePreview {
  const MergePreview(
      {required this.alreadyInAccount,
      required this.toUpload,
      required this.needsChoice});

  final int alreadyInAccount, toUpload, needsChoice;

  /// [conflicts] are ids present on both sides with different content.
  factory MergePreview.compute(
      {required Set<String> local,
      required Set<String> remote,
      Set<String> conflicts = const {}}) {
    final shared = local.intersection(remote);
    final choice = shared.intersection(conflicts).length;
    return MergePreview(
        alreadyInAccount: shared.length - choice,
        toUpload: local.difference(remote).length,
        needsChoice: choice);
  }

  bool get hasWork => toUpload > 0 || needsChoice > 0;
}
