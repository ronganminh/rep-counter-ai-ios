# Track A — A9 stabilization

A9 is a release/stabilization sweep. It does not introduce a new product
feature and must not rewrite the rep-counting engine.

## Automated product sweep

The machine-readable source is
`test/fixtures/a9_stabilization_manifest.json`.

The full suite must retain automated evidence for:

- Free workout
- Target reps
- Timed challenge
- Routine workout
- History reopen
- Progress filters
- Export
- Settings
- AI result UI/offline behavior

All 24 vNext deliverables are mapped to their implementation and test evidence
in the manifest so a later refactor cannot silently delete a mapped surface.

## Accessibility / visual QA

Automated tests cover key semantics, VI/EN copy, Dynamic Type around 2x,
muted voice behavior and camera/result/settings widgets. A9 visual QA should
still be done at approximately 393 x 852 first and then responsive sizes.

Reduced Motion and VoiceOver are product requirements. Simulator/widget
semantics tests are supporting evidence, not a substitute for real-device
assistive-technology smoke testing.

## Production regression gate

A9 is the full release regression, so both established engine baselines are
required:

- `pushup-1 = 28`
- `pushup-2 = 67`
- accepted rep total never decreases
- `HUD == saved WorkoutRecord == ResultPage` for each fixture

These numbers remain regression baselines, not human accuracy claims.

## Real-device gate

Status: **PENDING until evidence is recorded from a supported physical iPhone.**

Required smoke checks:

- camera/orientation/skeleton
- placement
- TTS
- haptics
- pause/background
- export/native share
- Time Challenge
- Routine rest
- push-up on the real camera

Pull-up is excluded because A8 remains blocked.

Do not mark this section passed from an iOS Simulator run. When a physical
device run is completed, record device model/iOS version/date and pass/fail
notes here or in an attached evidence document, then update the A9 manifest.

## Merge decision

Automated CI may be green while the real-device gate remains pending. A9 is
ready for merge only after the required automated gates are green **and** the
real-device smoke evidence is reviewed, unless the release owner explicitly
accepts the manual-gate exception.


## Simulator-first Track A completion exception

On 2026-10-02 the release owner explicitly accepted completing Track A with
simulator/CI evidence first because no physical iPhone was available through
the connected tooling. This exception does **not** claim that the real-device
smoke test passed; that hardware check remains deferred.

Accepted simulator/CI evidence:

- Staging Integration #110: success.
- RepCoach CI #172: success.
- pushup-1: 3901 frames, HUD 28, saved 28, ResultPage 28, monotonic.
- pushup-2: 9007 frames, HUD 67, saved 67, ResultPage 67, monotonic.

Under this explicit exception, A9 may be merged and Track A may be considered
code/CI complete. Physical-iPhone smoke remains a post-Track-A follow-up.
