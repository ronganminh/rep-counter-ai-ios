#!/usr/bin/env python3
"""Fail closed for deterministic App Store v1 source / metadata regressions."""
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

def main():
    spec = read("pubspec.yaml")
    ensure("version: 1.0.0+3" in spec, "Release version/build is not synchronized")
    strings = read("lib/core/i18n/app_strings.dart")
    legal = read("lib/features/legal/legal_page.dart")
    ensure("Gemini" not in strings and "Gemini" not in legal, "Stale Gemini provider text")
    ensure("GroqCloud" in legal and "GroqCloud" in read("lib/features/ai/presentation/ai_consent.dart"), "AI provider privacy copy inconsistent")
    flags = read("lib/core/config/feature_flags.dart")
    ensure("defaultValue: false" in flags, "Release feature defaults must remain gated")
    picker = read("lib/features/exercises/presentation/exercise_picker_screen.dart")
    ensure("FeatureFlags.visibleExerciseIds.contains" in picker, "Exercise picker must respect release gate")
    settings = read("lib/features/legal/settings_page.dart")
    ensure("1.0.0 (3)" in settings, "Settings release version mismatched")
    ensure("AppLinks.hasAppStoreListing" in settings, "iOS review link needs listing gate")
    info = plistlib.loads((ROOT / "ios/Runner/Info.plist").read_bytes())
    for key in ("NSCameraUsageDescription", "NSPhotoLibraryAddUsageDescription"):
        ensure(bool(info.get(key)), f"Missing {key}")
    ensure(info["CFBundleDisplayName"] == "RepCoach AI", "Incorrect iOS display name")
    ensure(set(info["CFBundleLocalizations"]) == {"en", "vi"}, "Native localization missing")
    manifest = plistlib.loads((ROOT / "ios/Runner/PrivacyInfo.xcprivacy").read_bytes())
    ensure(manifest["NSPrivacyTracking"] is False, "Tracking declaration changed")
    ensure(any(x["NSPrivacyAccessedAPIType"] == "NSPrivacyAccessedAPITypeUserDefaults"
               and "CA92.1" in x["NSPrivacyAccessedAPITypeReasons"]
               for x in manifest["NSPrivacyAccessedAPITypes"]), "UserDefaults reason missing")
    for lang in ("en", "vi"):
        localized = read(f"ios/Runner/{lang}.lproj/InfoPlist.strings")
        ensure("NSCameraUsageDescription" in localized and "NSPhotoLibraryAddUsageDescription" in localized,
               f"Missing native {lang} permission prompts")
    project = read("ios/Runner.xcodeproj/project.pbxproj")
    ensure(project.count("TARGETED_DEVICE_FAMILY = 1;") == 3, "v1 should target iPhone only")
    ensure("PrivacyInfo.xcprivacy in Resources" in project and "InfoPlist.strings in Resources" in project,
           "iOS privacy and localization resources are not bundled")
    ensure("com.ronganminh.repCounterApp" in project, "Bundle ID changed")
    ensure("NSPrivacyCollectedDataTypeFitness" in str(manifest), "Workout statistics privacy declaration missing")
    print("PASS: App Store v1 static release gates")

if __name__ == "__main__":
    try:
        main()
    except (AssertionError, KeyError, OSError, ValueError) as exc:
        print(f"FAIL: {exc}", file=sys.stderr)
        sys.exit(1)
