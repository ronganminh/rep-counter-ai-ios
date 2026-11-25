#!/usr/bin/env python3
"""Fail closed for deterministic App Store source / metadata regressions.

Usage: check_app_store_readiness.py [--dart-define-from-file=<build defines>]
"""
import json
import pathlib
import plistlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
def read(path):
    return (ROOT / path).read_text(encoding="utf-8-sig")

def ensure(condition, message):
    if not condition:
        raise AssertionError(message)

def shown_copy(path):
    """Source text of a screen plus the EN / VI ARB values of the
    `context.l10n.<key>` getters it uses."""
    source = read(path)
    keys = set(re.findall(r"context\.l10n\.(\w+)", source))
    texts = []
    for locale in ("en", "vi"):
        arb = json.loads(read(f"lib/l10n/app_{locale}.arb"))
        texts.append(source + "\n" + "\n".join(str(arb.get(k, "")) for k in keys))
    return tuple(texts)


def check_permission_screens():
    """App Store 5.1.1(iv), L-D24 (App Review rejected 1.0.0 (6)): a
    pre-permission screen offers only "Continue", never "Allow", and has no
    "Not now" / close before the system prompt."""
    strings = read("lib/core/i18n/app_strings.dart")
    ensure("cameraContinue: 'Continue'" in strings
           and "cameraContinue: 'Tiếp tục'" in strings,
           "Camera pre-permission button must say Continue / Tiếp tục")
    ensure("cameraAllowAndOpen" not in strings,
           "Camera pre-permission must not say Allow")
    view = read("lib/features/workout/presentation/widgets/camera_permission_view.dart")
    ensure("'Not now'" not in view and "'Để sau'" not in view,
           "Camera pre-permission screen must not offer Not now")
    camera = read("lib/camera_page.dart")
    ensure("onExit: _beforePrompt ? null : _confirmExit" in camera
           and "!didPop && !_beforePrompt" in camera,
           "Camera gate must have no way out before the system prompt")
    reminders = read("lib/features/plan/presentation/reminder_settings_page.dart")
    ensure("label: l.commonContinue" in reminders
           and "reminder-not-now" not in reminders
           and "canPop: !intro || systemBackLeavesPermissionExplanation" in reminders,
           "Reminder explanation must only continue to the system prompt")
    # QA-06 (L-D42): only Android's system Back may leave an explanation
    # screen; iOS keeps the HIG pre-alert screen with no way out.
    explanation = read("lib/core/permissions/permission_explanation.dart")
    ensure(re.search(r"systemBackLeavesPermissionExplanation\s*=>\s*"
                     r"defaultTargetPlatform == TargetPlatform\.android;",
                     explanation),
           "Only Android may leave a permission explanation with system Back")
    # Rejection of 1.0.0 (7), L-D38: Settings opens only from the neutral
    # "permission off" notices, and no copy asks the user to reconsider.
    callers = sorted(str(p.relative_to(ROOT)) for p in (ROOT / "lib").rglob("*.dart")
                     if "openAppSettings(" in p.read_text(encoding="utf-8"))
    ensure(callers == ["lib/camera_page.dart",
                       "lib/features/plan/presentation/reminder_settings_page.dart",
                       "lib/features/share/story_page.dart"],
           f"Settings may only open from a permission-off notice link: {callers}")
    # lib/l10n mirrors the Final C handoff ARB byte for byte and still lists the
    # old strings; app code must not use them.
    app_dart = "\n".join(p.read_text(encoding="utf-8")
                         for p in sorted((ROOT / "lib").rglob("*.dart"))
                         if "l10n" not in p.relative_to(ROOT).parts[:2])
    for banned in ("I granted permission", "Tôi đã cấp quyền", "permission was denied",
                   "đã từ chối quyền", "Grant Camera permission", "Enable Camera",
                   "reminder-denied", ".cameraDenied", ".cameraDeniedBody",
                   ".cameraGrantedRetry", ".notifDenied", ".legacyCameraPermission",
                   # Photos (QA of v1 build 8): Save image -> "Don't Allow".
                   "Photo access was denied", "Allow adding photos", "Hãy cho phép",
                   "Chưa có quyền thêm ảnh", ".legacyStoryPagePhotoAccessWasDenied",
                   # Unused handoff copy that asks to allow / tap "Allow".
                   ".plansCountOwnRepsKeep", ".v1FrontCameraCountsReps"):
        ensure(banned not in app_dart, f"5.1.1(iv): banned permission copy {banned!r}")
    # Every openAppSettings( call must be the Open Settings button of a
    # permission-off notice: `onOpenSettings: () => [unawaited(]openAppSettings(`.
    for path in sorted((ROOT / "lib").rglob("*.dart")):
        text = path.read_text(encoding="utf-8")
        for m in re.finditer(r"openAppSettings\(", text):
            before = text[max(0, m.start() - 60):m.start()]
            ensure(re.search(r"onOpenSettings:\s*\(\)\s*=>\s*(unawaited\()?$", before),
                   f"openAppSettings outside a notice's Open Settings button in {path.relative_to(ROOT)}")
    # "retry" next to permission/access/Settings in one app string literal.
    for lit in re.findall(r"'((?:[^'\\\n]|\\.)*)'", app_dart):
        low = lit.lower()
        ensure(not (re.search(r"permission|access|quyền|settings|cài đặt", low)
                    and re.search(r"retry|thử lại|try again", low)),
               f"5.1.1(iv): retry in permission copy: {lit!r}")
    for locale, word in (("en", "allow"), ("vi", "cho phép")):
        arb = json.loads(read(f"lib/l10n/app_{locale}.arb"))
        for key in ("cameraAllowAndOpen", "notifPrePermTitle", "notifPrePermBody",
                    "commonContinue"):
            ensure(word not in str(arb.get(key, "")).lower(),
                   f"Pre-permission copy {key} ({locale}) must not say Allow")


def _truthy(value):
    return str(value).strip().lower() == "true"


def check_login_services(define_files=()):
    """App Store 4.8 (S-5, L-D42): an iOS build that offers Google Sign-In
    must also offer Sign in with Apple. The app hides Google on iOS when
    Apple is off (fail-safe), and no dart-define file may ask for Google on
    iOS without Apple."""
    bootstrap = read("lib/features/auth/data/auth_bootstrap.dart")
    ensure("c.googleConfigured(ios: ios) && (!ios || apple)" in bootstrap,
           "4.8: iOS must hide Google Sign-In when Sign in with Apple is off")
    files = sorted(ROOT.glob("dart_defines*.json")) + [
        pathlib.Path(f) for f in define_files]
    for path in files:
        values = json.loads(path.read_text(encoding="utf-8-sig"))
        if not _truthy(values.get("ENABLE_ACCOUNTS", "false")):
            continue
        if str(values.get("GOOGLE_IOS_CLIENT_ID", "")).strip():
            ensure(_truthy(values.get("APPLE_SIGN_IN_ENABLED", "false")),
                   f"4.8: {path.name} enables Google Sign-In on iOS without "
                   "APPLE_SIGN_IN_ENABLED=true")


PRIVACY_MANIFEST = "ios/Runner/PrivacyInfo.xcprivacy"
PRIVACY_DECLARATIONS = ROOT.parent / "store_listing/PRIVACY_DECLARATIONS_V2.md"
# App Privacy label (PRIVACY_DECLARATIONS_V2.md A.2) -> manifest data type key.
APP_PRIVACY_TYPES = {
    "Email Address": "EmailAddress",
    "Name": "Name",
    "User ID": "UserID",
    "Fitness": "Fitness",
    "Other User Content": "OtherUserContent",
    "Product Interaction": "ProductInteraction",
}
# Required reason APIs the app's own code reaches (plugins ship their own
# manifests): UserDefaults through shared_preferences, read by this app only.
REQUIRED_REASONS = {"NSPrivacyAccessedAPICategoryUserDefaults": {"CA92.1"}}


def declared_app_privacy_types(text=None):
    """Data types ticked in table A.2 of PRIVACY_DECLARATIONS_V2.md."""
    text = PRIVACY_DECLARATIONS.read_text(encoding="utf-8") if text is None else text
    section = text.split("### A.2", 1)[1].split("\n### ", 1)[0]
    labels = re.findall(r"^\| \[ \] \| \*\*[^*›]+› ([^*]+)\*\*", section, re.M)
    return [label.strip() for label in labels]


def check_privacy_manifest(manifest=None, declared=None):
    """App Store 5.1.1 / 5.1.2, S-3 (L-D42): PrivacyInfo.xcprivacy declares
    exactly the App Privacy data types of PRIVACY_DECLARATIONS_V2.md A.2,
    all linked to the user, never for tracking, for app functionality, with
    no tracking domains, and a valid reason for each required reason API."""
    if manifest is None:
        manifest = plistlib.loads((ROOT / PRIVACY_MANIFEST).read_bytes())
    declared = declared_app_privacy_types() if declared is None else declared
    ensure(manifest.get("NSPrivacyTracking") is False, "Privacy manifest: tracking must be false")
    ensure(not manifest.get("NSPrivacyTrackingDomains"), "Privacy manifest: no tracking domains allowed")
    unknown = [d for d in declared if d not in APP_PRIVACY_TYPES]
    ensure(not unknown, f"Privacy manifest: no manifest key for App Privacy type(s) {unknown}")
    expected = {"NSPrivacyCollectedDataType" + APP_PRIVACY_TYPES[d] for d in declared}
    entries = manifest.get("NSPrivacyCollectedDataTypes", [])
    found = [e.get("NSPrivacyCollectedDataType") for e in entries]
    ensure(len(found) == len(set(found)), "Privacy manifest: duplicate data type")
    ensure(set(found) == expected,
           f"Privacy manifest data types {sorted(found)} differ from App Privacy A.2 {sorted(expected)}")
    for e in entries:
        name = e["NSPrivacyCollectedDataType"]
        ensure(e.get("NSPrivacyCollectedDataTypeLinked") is True, f"{name} must be linked to the user")
        ensure(e.get("NSPrivacyCollectedDataTypeTracking") is False, f"{name} must not be used for tracking")
        ensure(e.get("NSPrivacyCollectedDataTypePurposes") == ["NSPrivacyCollectedDataTypePurposeAppFunctionality"],
               f"{name} purpose must be App Functionality only")
    apis = {x.get("NSPrivacyAccessedAPIType"): set(x.get("NSPrivacyAccessedAPITypeReasons", []))
            for x in manifest.get("NSPrivacyAccessedAPITypes", [])}
    ensure(apis == REQUIRED_REASONS, f"Privacy manifest required reason APIs {apis} != {REQUIRED_REASONS}")


def check_flag_defaults():
    """Every ENABLE_* switch in the app defaults to off, so a build without
    --dart-define never ships accounts, sync, credits, XP, social, billing
    or push."""
    for path in sorted((ROOT / "lib").rglob("*.dart")):
        text = path.read_text(encoding="utf-8")
        for match in re.finditer(r"fromEnvironment\(\s*'(ENABLE_\w+)'([^)]*)\)", text):
            ensure("defaultValue: true" not in match.group(2),
                   f"{match.group(1)} must default to false ({path.relative_to(ROOT)})")


def main(argv=()):
    define_files = [a.split("=", 1)[1] for a in argv
                    if a.startswith("--dart-define-from-file=")]
    spec = read("pubspec.yaml")
    version_match = re.search(
        r"(?m)^version:\s*(\d+\.\d+\.\d+)\+(\d+)\s*$", spec
    )
    ensure(version_match is not None, "Release version/build is not synchronized")
    release_version, release_build = version_match.groups()
    strings = read("lib/core/i18n/app_strings.dart")
    # Screens migrated to gen-l10n (roadmap L-1) show ARB text, so check the
    # copy each screen actually renders in both languages, not only literals.
    legal_en, legal_vi = shown_copy("lib/features/legal/legal_page.dart")
    consent_en, consent_vi = shown_copy("lib/features/ai/presentation/ai_consent.dart")
    ensure(all("Gemini" not in text for text in (strings, legal_en, legal_vi)),
           "Stale Gemini provider text")
    ensure(all("GroqCloud" in text for text in (legal_en, legal_vi, consent_en, consent_vi)),
           "AI provider privacy copy inconsistent")
    flags = read("lib/core/config/feature_flags.dart")
    ensure("defaultValue: false" in flags, "Release feature defaults must remain gated")
    picker = read("lib/features/exercises/presentation/exercise_picker_screen.dart")
    ensure("FeatureFlags.visibleExerciseIds.contains" in picker, "Exercise picker must respect release gate")
    settings = read("lib/features/legal/settings_page.dart")
    # The About row reads the version from build metadata (roadmap F-2), so
    # it cannot drift from pubspec.yaml; a hard-coded literal is a regression.
    ensure(
        "AppVersionText(" in settings
        and not re.search(r"'\d+\.\d+\.\d+ \(\d+\)'", settings),
        "Settings release version must come from build metadata",
    )
    ensure("AppLinks.hasAppStoreListing" in settings, "iOS review link needs listing gate")
    info = plistlib.loads((ROOT / "ios/Runner/Info.plist").read_bytes())
    ensure(
        info.get("CFBundleShortVersionString") == "$(FLUTTER_BUILD_NAME)"
        and info.get("CFBundleVersion") == "$(FLUTTER_BUILD_NUMBER)",
        "iOS version must come from pubspec.yaml build metadata",
    )
    for key in ("NSCameraUsageDescription", "NSPhotoLibraryAddUsageDescription"):
        ensure(bool(info.get(key)), f"Missing {key}")
    ensure(info.get("ITSAppUsesNonExemptEncryption") is False,
           "Export-compliance declaration must stay synchronized")
    ensure(info["CFBundleDisplayName"] == "RepCoach AI", "Incorrect iOS display name")
    ensure(set(info["CFBundleLocalizations"]) == {"en", "vi"}, "Native localization missing")
    check_privacy_manifest()
    for lang in ("en", "vi"):
        localized = read(f"ios/Runner/{lang}.lproj/InfoPlist.strings")
        ensure("NSCameraUsageDescription" in localized and "NSPhotoLibraryAddUsageDescription" in localized,
               f"Missing native {lang} permission prompts")
    project = read("ios/Runner.xcodeproj/project.pbxproj")
    ensure(project.count("TARGETED_DEVICE_FAMILY = 1;") == 3, "Release should target iPhone only")
    ensure("PrivacyInfo.xcprivacy in Resources" in project and "InfoPlist.strings in Resources" in project,
           "iOS privacy and localization resources are not bundled")
    ensure("com.ronganminh.repCounterApp" in project, "Bundle ID changed")
    # D-12: Sign in with Apple capability and the auth / Google callback schemes.
    entitlements = plistlib.loads((ROOT / "ios/Runner/Runner.entitlements").read_bytes())
    ensure(entitlements.get("com.apple.developer.applesignin") == ["Default"],
           "Sign in with Apple entitlement missing")
    ensure(project.count("CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;") == 3,
           "Runner entitlements must apply to Debug, Profile and Release")
    schemes = {s for t in info.get("CFBundleURLTypes", []) for s in t.get("CFBundleURLSchemes", [])}
    ensure("com.ronganminh.repcoach" in schemes, "Auth callback URL scheme missing")
    ensure(any(s.startswith("com.googleusercontent.apps.") for s in schemes),
           "Google Sign-In reversed client ID URL scheme missing")
    check_permission_screens()
    check_flag_defaults()
    check_login_services(define_files)
    print(
        f"PASS: App Store static release gates for "
        f"{release_version} ({release_build})"
    )

if __name__ == "__main__":
    try:
        main(sys.argv[1:])
    except (AssertionError, KeyError, OSError, ValueError) as exc:
        print(f"FAIL: {exc}", file=sys.stderr)
        sys.exit(1)
