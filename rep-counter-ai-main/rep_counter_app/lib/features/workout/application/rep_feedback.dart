import '../domain/rep_metric.dart';
import '../domain/rep_tracker.dart';

enum RepFeedbackKind {
  countedClean,
  countedWarning,
  placementInterrupted,
  poseLost,
}

class RepFeedback {
  const RepFeedback._({
    required this.kind,
    this.repNumber,
    this.primaryFlag,
  });

  const RepFeedback.countedClean(int repNumber)
      : this._(
          kind: RepFeedbackKind.countedClean,
          repNumber: repNumber,
        );

  const RepFeedback.countedWarning(
    int repNumber,
    RepQualityFlag primaryFlag,
  ) : this._(
          kind: RepFeedbackKind.countedWarning,
          repNumber: repNumber,
          primaryFlag: primaryFlag,
        );

  const RepFeedback.placementInterrupted()
      : this._(kind: RepFeedbackKind.placementInterrupted);

  const RepFeedback.poseLost() : this._(kind: RepFeedbackKind.poseLost);

  final RepFeedbackKind kind;
  final int? repNumber;
  final RepQualityFlag? primaryFlag;

  bool get counted =>
      kind == RepFeedbackKind.countedClean ||
      kind == RepFeedbackKind.countedWarning;

  bool get persistsUntilResolved =>
      kind == RepFeedbackKind.placementInterrupted ||
      kind == RepFeedbackKind.poseLost;
}

const repFeedbackFlagPriority = <RepQualityFlag>[
  RepQualityFlag.poseUnreliable,
  RepQualityFlag.bodyAlignmentLost,
  RepQualityFlag.shallow,
  RepQualityFlag.incompleteLockout,
  RepQualityFlag.tooFast,
  RepQualityFlag.leftRightUneven,
  RepQualityFlag.tooSlow,
];

RepQualityFlag? primaryRepFeedbackFlag(Set<RepQualityFlag> flags) {
  for (final flag in repFeedbackFlagPriority) {
    if (flags.contains(flag)) return flag;
  }
  return null;
}

RepFeedback feedbackForCompletedRep(
  int repNumber,
  Set<RepQualityFlag> flags,
) {
  final primary = primaryRepFeedbackFlag(flags);
  return primary == null
      ? RepFeedback.countedClean(repNumber)
      : RepFeedback.countedWarning(repNumber, primary);
}

RepFeedback? feedbackForAbortedRep(RepAbortReason reason) => switch (reason) {
      RepAbortReason.placementLost => const RepFeedback.placementInterrupted(),
      RepAbortReason.signalLost => const RepFeedback.poseLost(),
      RepAbortReason.reset => null,
    };
