# RepCoach AI — App Store v1 release gate

This gate applies to the **iPhone-only** Flutter release. Do not submit for App Review merely because CI is green.

## Current scope
- Product: push-ups and local workout history. Pull-ups and other exercises remain disabled in production until independently validated; never advertise unvalidated counters.
- Camera inference stays on device. AI feedback is optional, consent-gated and sends limited workout statistics to RepCoach's backend and GroqCloud. No camera frames, videos, audio or raw pose landmarks are sent.
- No account or in-app purchases in this Flutter v1. Do not advertise subscriptions, AI credits or account sync until actually implemented.
- Release version 1.0.0 (8), bundle ID `com.ronganminh.repCounterApp`; target iPhone. iOS minimum 15.5.
- App Privacy on App Store Connect must reflect actual app and every bundled SDK. Review the built app's merged privacy report, including third-party plugin manifests, rather than treating the first-party PrivacyInfo.xcprivacy as exhaustive.

## CI and code verification
1. Run `flutter pub get && flutter analyze --fatal-infos && flutter test`.
2. Run `python3 tool/check_app_store_readiness.py` after resolving dependencies.
3. Run the existing iOS simulator replay CI and compare HUD / record / result counts.
4. Build an **unsigned** release on Xcode 26+ with iOS 26+ SDK in the App Store readiness workflow. This proves compilation only; it is **not** a distributable TestFlight artifact.
5. Do not promote if any tests, privacy contract checks or release compilation fail.

## Apple Developer / TestFlight (human-owned credentials)
1. Verify paid Apple Developer membership and agreements, tax/banking if needed, and access to App Store Connect.
2. In Xcode `ios/Runner.xcworkspace`, choose your Apple Developer Team for the Runner target. Register the bundle ID above in the team. Do not commit a private key, .p12, provisioning profile, password or App Store Connect API credential.
3. Set up automatic signing, then from `rep-counter-ai-main/rep_counter_app`: `flutter pub get`, `python3 tool/check_app_store_readiness.py`, `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer tool/build_ios.sh --ipa --release`. This uses `flutter build ipa --release`; the default export requires a valid App Store distribution signing setup. Use `--export-options-plist=<path>` if your signing arrangement needs one.
4. Inspect the archive's app icon, version/build, iPhone deployment target, entitlements, bundled privacy manifests, code signing and App Store export. Upload the signed IPA using Xcode Organizer / Transporter / an authorized App Store Connect upload workflow.
5. Install TestFlight on at least one **physical** supported iPhone; request camera permission, place camera, calibrate, count 10+ real push-ups, verify skeleton alignment and monotonic counting, background/foreground, the camera permission rules below, sound/haptics/voice, offline feedback, consent, saved results/history, image saving/sharing and deletion. Confirm counts match between HUD and ResultPage.
6. Verify optional AI with both manual and automatic consent: GroqCloud endpoint success, timeout, offline fallback and no upload of video/landmarks. Verify the public privacy URL and support contact load from App Review's region.
7. Collect **real screenshots from the release build** for required iPhone display sizes (not fixture/mockup images). Fill App Store Connect name, subtitle, categories, description, keywords, age rating, support URL, privacy URL, App Privacy nutrition labels, export compliance, rights declaration, pricing/availability and Review Notes. Explain camera placement, the lack of login, and how reviewer can test a real push-up or a demo.
8. Submit for App Review only after TestFlight sign-off. A successful unsigned build does not imply Apple acceptance.

## Camera permission rules — Guideline 5.1.1(iv) (release checklist, build 1.0.0 (8))
Apple rejected 1.0.0 (6) (an "Allow" / "Not now" screen before the prompt) and 1.0.0 (7) (a "permission was denied" screen with a 3-step guide, a prominent "Open settings" button and "I granted permission • Retry", shown right after "Don't Allow"). Build 8 follows these rules; check each on a physical iPhone (and iPad in iPhone compatibility mode) before submitting:
- [ ] **Before the prompt:** the explanation screen (camera used on device only) has a single **Continue** button that always shows the iOS camera prompt. No "Allow", no "Not now", no close; back does nothing.
- [ ] **"Don't Allow" in the system prompt:** the app returns to the previous screen. No denied screen, Settings is not opened, the prompt is not shown again.
- [ ] **Camera off, user taps Start again:** only the neutral notice "Camera access is off for RepCoach. Rep counting needs the camera." / "Quyền truy cập camera của RepCoach đang tắt. Tính năng đếm rep cần camera." with two equal buttons **Back** and **Open Settings**. No icon or "denied" title, no steps, no retry, no wording asking the user to reconsider. Settings opens only when the user taps that link.
- [ ] **Back from Settings with camera on:** the camera opens; nothing else is asked.
- [ ] **Static gate:** `tool/check_app_store_readiness.py` fails if `openAppSettings(` appears more than once in `lib/` or if the old denied/retry copy comes back.
- [ ] **Notifications:** the v1 store build requests no notification permission (`POST_NOTIFICATIONS` exists only in the `diag` Android flavor); nothing to change. If one is added later, the same rules apply.

### Building 1.0.0 (8)
From `rep-counter-ai-main/rep_counter_app` on the `release/v1` commit that contains the build-8 hotfix (after the owner merges it):
```bash
flutter pub get
python3 tool/check_app_store_readiness.py
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer tool/build_ios.sh --ipa --release
```
`pubspec.yaml` is `1.0.0+8`, so the IPA is version 1.0.0, build 8. Upload with Xcode Organizer / Transporter, run the checklist above in TestFlight, then reply in App Review and submit build 8.

## Release metadata / manual decisions
- Website privacy: https://repcoach-ai.duckdns.org/privacy-policy.html (compare deployed content against the repository's GroqCloud policy).
- Support: ronganminh221@gmail.com (provide a publicly reachable support page if requested by Connect).
- `APP_STORE_ID`: not known until App Store Connect generates a numeric Apple ID. Add to future production builds if you want the in-app review deep link; the review button is hidden on iOS until configured.
- Localized native camera/Photos prompts are in `ios/Runner/{en,vi}.lproj/InfoPlist.strings`.
- Third-party SDK privacy / Required Reason API review is **mandatory** before submission. The manifest in Runner declares app-owned workout statistics sent for optional AI functionality and UserDefaults usage; refine against actual merged app reports.
- Physical device verification, screenshots, Apple signing and App Store Connect submissions cannot be completed by GitHub's unsigned CI alone.

## Apple documentation
- https://developer.apple.com/app-store/review/guidelines/
- https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
- https://docs.flutter.dev/deployment/ios
