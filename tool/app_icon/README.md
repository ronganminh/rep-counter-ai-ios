# RepCoach AI — app icon

Implementation of `design-handoff/design/app-icon.dc.html` (Concept 2 · vòng đếm + chấm khớp).
The geometry lives in `glyph.mjs`, and `generate.mjs` renders every file listed in `design-handoff/docs/DESIGN_HANDOFF.md` §9.1.

```sh
pip install pillow          # strips alpha from store icons
node tool/app_icon/generate.mjs
```

It needs Playwright/Chromium and network access to Google Fonts for the feature graphic.

| Output | Use |
|---|---|
| `assets/icon/ios/AppIcon-1024.png` | App Store / Xcode. Square, no rounded corners, RGB (no alpha) |
| `assets/icon/ios/AppIcon-dark-1024.png` | iOS 18 dark appearance. Transparent background |
| `assets/icon/ios/AppIcon-tinted-1024.png` | iOS 18 tinted appearance. `#DADAD2` glyph on black |
| `assets/icon/ios/AppIcon.appiconset/` | Drop-in replacement for `ios/Runner/Assets.xcassets/AppIcon.appiconset` |
| `assets/icon/android/ic_launcher_{foreground,background,monochrome}.png` | 432 px (108 dp @ xxxhdpi) adaptive layers for `flutter_launcher_icons` |
| `assets/icon/android/res/` | Ready-made `mipmap-*` tree (adaptive + legacy square/round) for `android/app/src/main/res` |
| `play/icon-512.png` | Google Play store icon |
| `play/feature-graphic-1024x500.png` | Google Play feature graphic |
| `assets/brand/mark.svg` | In-app mark next to the wordmark (1.3em), `flutter_svg` |
| `assets/brand/glyph.svg` | Glyph only, transparent |
| `assets/brand/splash.png` | 1152 px splash for `flutter_native_splash` |
| `assets/icon/master/*.svg` | Vector masters of every variant |

The Flutter project's root has `flutter_launcher_icons.yaml` and `flutter_native_splash.yaml`, which point at these files.

On transparent layers (the Android foreground and monochrome layers, the iOS dark variant and `glyph.svg`), the dark outline around the joint dot is cut out of the ring instead of painted. It looks the same on the dark background and stays correct on wallpapers and under system tinting.
