import 'package:flutter_test/flutter_test.dart';
import 'package:rep_counter_app/features/workout/application/rep_feedback.dart';
import 'package:rep_counter_app/features/workout/domain/rep_metric.dart';
import 'package:rep_counter_app/features/workout/domain/rep_tracker.dart';

void main() {
  group('rep feedback mapping', () {
    test('clean completed rep stays explicitly counted', () {
      final feedback = feedbackForCompletedRep(7, const {});
      expect(feedback.kind, RepFeedbackKind.countedClean);
      expect(feedback.repNumber, 7);
      expect(feedback.counted, isTrue);
      expect(feedback.primaryFlag, isNull);
    });

    test('warning priority is deterministic and still counted', () {
      final feedback = feedbackForCompletedRep(8, const {
        RepQualityFlag.tooFast,
        RepQualityFlag.shallow,
        RepQualityFlag.bodyAlignmentLost,
        RepQualityFlag.poseUnreliable,
      });
      expect(feedback.kind, RepFeedbackKind.countedWarning);
      expect(feedback.repNumber, 8);
      expect(feedback.counted, isTrue);
      expect(feedback.primaryFlag, RepQualityFlag.poseUnreliable);
    });

    test('priority order covers every quality flag', () {
      expect(
        repFeedbackFlagPriority,
        const [
          RepQualityFlag.poseUnreliable,
          RepQualityFlag.bodyAlignmentLost,
          RepQualityFlag.shallow,
          RepQualityFlag.incompleteLockout,
          RepQualityFlag.tooFast,
          RepQualityFlag.leftRightUneven,
          RepQualityFlag.tooSlow,
        ],
      );
    });

    test('tracker aborts map only to interruption presentation states', () {
      expect(
        feedbackForAbortedRep(RepAbortReason.placementLost)?.kind,
        RepFeedbackKind.placementInterrupted,
      );
      expect(
        feedbackForAbortedRep(RepAbortReason.signalLost)?.kind,
        RepFeedbackKind.poseLost,
      );
      expect(feedbackForAbortedRep(RepAbortReason.reset), isNull);
    });
  });
}
