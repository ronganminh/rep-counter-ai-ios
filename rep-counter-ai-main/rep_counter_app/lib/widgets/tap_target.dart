import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

/// Gives a small visual control a hit area of at least 48 × 48 dp
/// (PRODUCT_DECISIONS D-24) without enlarging what is drawn.
///
/// The whole box, including the transparent margin, receives taps, so a
/// 36–40 px chip stays visually compact but meets the 44 pt / 48 dp target.
class TapTarget extends StatelessWidget {
  const TapTarget({
    super.key,
    required this.onTap,
    required this.child,
    this.minSize = AppSpacing.minTouch,
  });

  final VoidCallback? onTap;
  final Widget child;
  final double minSize;

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: minSize, minHeight: minSize),
          child: Center(widthFactor: 1, heightFactor: 1, child: child),
        ),
      );
}
