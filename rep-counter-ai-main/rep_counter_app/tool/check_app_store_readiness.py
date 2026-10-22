#!/usr/bin/env python3
"""Fail closed for deterministic App Store source / metadata regressions."""
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


def main():
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
    manifest = plistlib.loads((ROOT / "ios/Runner/PrivacyInfo.xcprivacy").read_bytes())
    ensure(manifest["NSPrivacyTracking"] is False, "Tracking declaration changed")
    ensure(any(x["NSPrivacyAccessedAPIType"] == "NSPrivacyAccessedAPICategoryUserDefaults"
               and "CA92.1" in x["NSPrivacyAccessedAPITypeReasons"]
               for x in manifest["NSPrivacyAccessedAPITypes"]), "UserDefaults reason missing")
    for lang in ("en", "vi"):
        localized = read(f"ios/Runner/{lang}.lproj/InfoPlist.strings")
        ensure("NSCameraUsageDescription" in localized and "NSPhotoLibraryAddUsageDescription" in localized,
               f"Missing native {lang} permission prompts")
    project = read("ios/Runner.xcodeproj/project.pbxproj")
    ensure(project.count("TARGETED_DEVICE_FAMILY = 1;") == 3, "Release should target iPhone only")
    ensure("PrivacyInfo.xcprivacy in Resources" in project and "InfoPlist.strings in Resources" in project,
           "iOS privacy and localization resources are not bundled")
    ensure("com.ronganminh.repCounterApp" in project, "Bundle ID changed")
    ensure("NSPrivacyCollectedDataTypeFitness" in str(manifest), "Workout statistics privacy declaration missing")
    print(
        f"PASS: App Store static release gates for "
        f"{release_version} ({release_build})"
    )

if __name__ == "__main__":
    try:
        main()
    except (AssertionError, KeyError, OSError, ValueError) as exc:
        print(f"FAIL: {exc}", file=sys.stderr)
        sys.exit(1)
