import 'package:flutter/foundation.dart';

/// QA-06 / store compliance S-7 (owner decision L-D42).
///
/// On Android the system Back button leaves a permission explanation screen
/// (camera, reminders) and returns to the previous screen without showing the
/// system prompt, as the Android permission guidance asks ("Always provide
/// the option to cancel an educational UI flow").
///
/// iOS keeps the HIG pre-alert screen: one "Continue" button and no way to
/// leave before the system alert (App Store 5.1.1(iv), L-D24 / L-D38).
bool get systemBackLeavesPermissionExplanation =>
    defaultTargetPlatform == TargetPlatform.android;
