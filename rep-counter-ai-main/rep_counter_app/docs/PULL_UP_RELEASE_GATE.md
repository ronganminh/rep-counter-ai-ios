# Pull-up A8 production release gate

Status: **BLOCKED — keep `pull_up` hidden from the store build.**

This document is the A8 release decision record. It does not change the
pull-up counter or relax its existing diagnostic behavior. The machine-readable
source is `test/fixtures/pull_up_validation_manifest.json`.

## Acceptance threshold

Before store visibility can change, all of the following evidence must be
present and reviewed:

- representative dataset coverage across front, rear, slight side angles, body
  sizes, clothing, lighting, distances, bars/backgrounds, mount/dismount/rest
  and temporary pose loss;
- complete human annotation for every release fixture: actual count, valid-rep
  intervals/timestamps, invalid/partial attempts, mount, dismount, pose-loss
  windows and camera-angle notes;
- no systematic mount/dismount false reps;
- accepted-rep total remains monotonic;
- production `CameraPage -> WorkoutController -> save -> ResultPage` has
  `HUD == saved == result`;
- no severe angle-specific failure that would make normal placement guidance
  misleading;
- real-device validation on at least one recent and one older supported iPhone,
  including orientation, mounting distance, TTS/haptics interaction and normal
  session thermal behavior.

Precision/recall may only be reported when event-level human annotation exists.
Aggregate counts alone are not enough.

## Evidence currently in the repository

| Fixture | Human aggregate | Engine reference | Absolute error | Error rate |
|---|---:|---:|---:|---:|
| `pull_up_front` | 47 | 46 | 1 | 2.13% |
| `pull_up_back_closeup` | 30 | 21 | 9 | 30.00% |

These are **offline reference fixtures**, not production iPhone replay evidence.
The rear close-up video is a known adverse-distance case where hands/bar often
leave the frame.

The following A8 metrics are intentionally **not claimed yet**:

- event precision/recall;
- false positives inside annotated mount/dismount windows;
- placement-ready rate;
- pose-loss rate;
- production accepted-count monotonicity;
- production HUD/saved/result equality for pull-up.

The existing fixture `gate` boolean is the pull-up per-frame count gate, not
the full app `PlacementStatus.ready`; it must not be relabeled as a
placement-ready metric.

## Missing evidence

Current fixtures do not cover all required angles/body sizes/clothing and do
not contain event-level human annotations. There is no approved pull-up video
matrix in GitHub Actions, and no recorded recent/older-iPhone validation in the
repository.

Therefore A8 must not enable the store feature flag. A future release decision
must update the manifest with real evidence rather than changing this document
alone.
