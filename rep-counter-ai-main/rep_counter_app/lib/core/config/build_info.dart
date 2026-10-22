import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// App version and build number from the platform build metadata, so the
/// About row can never drift from `pubspec.yaml` (roadmap F-2).
class BuildInfo {
  const BuildInfo({required this.version, required this.buildNumber});

  final String version;
  final String buildNumber;

  /// `[APP_VERSION] ([BUILD_NUMBER])`, e.g. `2.0.0 (8)`.
  String get label => '$version ($buildNumber)';

  static Future<BuildInfo?> load() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (info.version.isEmpty) return null;
      return BuildInfo(version: info.version, buildNumber: info.buildNumber);
    } catch (_) {
      // Metadata is informational; never break Settings over it.
      return null;
    }
  }
}

/// Shows [BuildInfo.label], or an em dash while loading or if unavailable.
class AppVersionText extends StatefulWidget {
  const AppVersionText({super.key, this.style, this.loader = BuildInfo.load});

  final TextStyle? style;
  final Future<BuildInfo?> Function() loader;

  @override
  State<AppVersionText> createState() => _AppVersionTextState();
}

class _AppVersionTextState extends State<AppVersionText> {
  late final Future<BuildInfo?> _info = widget.loader();

  @override
  Widget build(BuildContext context) => FutureBuilder<BuildInfo?>(
        future: _info,
        builder: (context, snapshot) =>
            Text(snapshot.data?.label ?? '—', style: widget.style),
      );
}
