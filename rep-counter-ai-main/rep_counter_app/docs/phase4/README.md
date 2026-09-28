# Native iOS launch evidence — updated UI

Updated 27 September 2026: the screenshot at this path now shows the new
onboarding. The earlier Phase 4 capture showed the legacy onboarding.
See [the UI migration gallery](../new-ui/README.md) for the remaining screens.

[`ios26-onboarding.png`](ios26-onboarding.png) is a native simulator screenshot,
captured with `xcrun simctl io … screenshot` after installing and launching the
actual Flutter app. It is not a widget render or a mock camera screenshot.

- Device: RepCoach iPhone 17 Pro, iOS 26.0 Universal (23A343).
- Runtime boot architecture: arm64; app binary: x86_64 via Rosetta 2.
- App: `com.ronganminh.repCounterApp`, debug build with the real ML Kit plugins.
- Verified: app installation, process launch and first onboarding screen.
- Not verified here: Device Hub pointer interaction or physical camera/rep accuracy.

Controller/camera integration regression coverage is in
`test/features/workout/workout_controller_test.dart` and
`test/features/workout/camera_page_controller_test.dart`.
