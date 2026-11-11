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
    ensure("version: 1.0.0+9" in spec, "Release version/build is not synchronized")
    strings = read("lib/core/i18n/app_strings.dart")
    legal = read("lib/features/legal/legal_page.dart")
    ensure("Gemini" not in strings and "Gemini" not in legal, "Stale Gemini provider text")
    ensure("GroqCloud" in legal and "GroqCloud" in read("lib/features/ai/presentation/ai_consent.dart"), "AI provider privacy copy inconsistent")
    flags = read("lib/core/config/feature_flags.dart")
    ensure("defaultValue: false" in flags, "Release feature defaults must remain gated")
    picker = read("lib/features/exercises/presentation/exercise_picker_screen.dart")
    ensure("FeatureFlags.visibleExerciseIds.contains" in picker, "Exercise picker must respect release gate")
    settings = read("lib/features/legal/settings_page.dart")
    ensure("1.0.0 (9)" in settings, "Settings release version mismatched")
    ensure("AppLinks.hasAppStoreListing" in settings, "iOS review link needs listing gate")
    info = plistlib.loads((ROOT / "ios/Runner/Info.plist").read_bytes())
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
    ensure(project.count("TARGETED_DEVICE_FAMILY = 1;") == 3, "v1 should target iPhone only")
    ensure("PrivacyInfo.xcprivacy in Resources" in project and "InfoPlist.strings in Resources" in project,
           "iOS privacy and localization resources are not bundled")
    ensure("com.ronganminh.repCounterApp" in project, "Bundle ID changed")
    ensure("NSPrivacyCollectedDataTypeFitness" in str(manifest), "Workout statistics privacy declaration missing")
    # Guideline 5.1.1(iv) (rejections of 1.0.0 (6) and (7); Photos found in QA
    # of (8)): Settings opens only from a neutral "access is off" notice, and no
    # copy asks the user to reconsider a permission.
    sources = {p.relative_to(ROOT).as_posix(): p.read_text(encoding="utf-8")
               for p in sorted((ROOT / "lib").rglob("*.dart"))}
    lib_dart = "\n".join(sources.values())
    link = "lib/core/permissions/permission_off_notice.dart"
    ensure(lib_dart.count("openAppSettings(") == 1 and "openAppSettings(" in sources[link],
           "openAppSettings may only be called from the shared permission-off link")
    callers = sorted(f for f, text in sources.items()
                     if "openRepCoachSettings(" in text and f != link)
    ensure(callers == ["lib/camera_page.dart"],
           f"Settings link may only be used by the camera-off notice: {callers}")
    ensure(sources[link].count("openRepCoachSettings(") == 2,
           "Permission-off dialog must open Settings only from its own button")
    for banned in ("I granted permission", "Tôi đã cấp quyền", "permission was denied",
                   "đã từ chối quyền", "Grant Camera permission", "Enable Camera",
                   "Photo access was denied", "Allow adding photos", "Hãy cho phép",
                   "Chưa có quyền thêm ảnh"):
        ensure(banned not in lib_dart, f"5.1.1(iv): banned permission copy {banned!r}")
    # "retry" next to permission/access/Settings in one string literal.
    for f, text in sources.items():
        for lit in re.findall(r"'((?:[^'\\\n]|\\.)*)'", text):
            low = lit.lower()
            if re.search(r"permission|access|quyền|settings|cài đặt", low) and \
                    re.search(r"retry|thử lại|try again", low):
                raise AssertionError(f"5.1.1(iv): retry in permission copy in {f}: {lit!r}")
    print("PASS: App Store v1 static release gates for 1.0.0 (9)")

if __name__ == "__main__":
    try:
        main()
    except (AssertionError, KeyError, OSError, ValueError) as exc:
        print(f"FAIL: {exc}", file=sys.stderr)
        sys.exit(1)
