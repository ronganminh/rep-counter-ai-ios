import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Exact WCAG 2.1 text-contrast audit for widget tests.
///
/// Flutter's `textContrastGuideline` samples pixels per merged semantics
/// node, so a dim subtitle next to a bright title passes. This walks every
/// painted paragraph instead: foreground = the paragraph's text colour,
/// background = the ancestors' fills composited (tints over surfaces over the
/// scaffold), ratio per WCAG. Large text (≥ 18 px, or ≥ 14 px bold) needs 3:1,
/// everything else 4.5:1.
class ContrastIssue {
  ContrastIssue(this.text, this.ratio, this.required, this.fg, this.bg);
  final String text;
  final double ratio, required;
  final Color fg, bg;
  @override
  String toString() =>
      '"$text": ${ratio.toStringAsFixed(2)} < $required '
      '(fg ${_hex(fg)} on bg ${_hex(bg)})';
}

String _hex(Color c) =>
    '#${c.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';

double _channel(double v) => v <= 0.03928
    ? v / 12.92
    : math.pow((v + 0.055) / 1.055, 2.4).toDouble();

double luminance(Color c) =>
    0.2126 * _channel(c.r) + 0.7152 * _channel(c.g) + 0.0722 * _channel(c.b);

double contrastRatio(Color a, Color b) {
  final la = luminance(a), lb = luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

Color _over(Color top, Color bottom) => Color.alphaBlend(top, bottom);

/// Fill colour a widget paints behind its children, if any.
Color? _fillOf(Widget w, ThemeData theme) {
  if (w is ColoredBox) return w.color;
  if (w is DecoratedBox && w.decoration is BoxDecoration) {
    return (w.decoration as BoxDecoration).color;
  }
  if (w is Material) {
    if (w.type == MaterialType.transparency) return null;
    return w.color;
  }
  if (w is Scaffold) return w.backgroundColor ?? theme.scaffoldBackgroundColor;
  return null;
}

List<ContrastIssue> auditTextContrast(WidgetTester tester,
    {Set<String> ignore = const {}}) {
  final issues = <ContrastIssue>[];
  for (final element in find.byType(RichText).evaluate()) {
    final render = element.renderObject;
    if (render is! RenderParagraph || !render.attached || !render.hasSize) {
      continue;
    }
    // Skip text that is not on screen (scrolled away / offstage), and icon
    // glyphs (not text; disabled controls are exempt under WCAG 1.4.3).
    if (!_visible(render)) continue;
    if (element.findAncestorWidgetOfExactType<Icon>() != null) continue;
    final span = render.text;
    final text = span.toPlainText().trim();
    if (text.isEmpty || ignore.contains(text)) continue;
    final style = span.style;
    final fg = style?.color;
    if (fg == null || fg.a == 0) continue;
    final theme = Theme.of(element);

    // Composite fills from the nearest ancestor outward until opaque.
    final fills = <Color>[];
    element.visitAncestorElements((ancestor) {
      final fill = _fillOf(ancestor.widget, theme);
      if (fill != null && fill.a > 0) {
        fills.add(fill);
        if (fill.a >= 1) return false;
      }
      return true;
    });
    var bg = theme.scaffoldBackgroundColor;
    for (final fill in fills.reversed) {
      bg = _over(fill, bg);
    }
    final effectiveFg = _over(fg, bg);
    final size = style?.fontSize ?? 14;
    final bold = (style?.fontWeight?.value ?? 400) >= 700;
    final large = size >= 18 || (size >= 14 && bold);
    final required = large ? 3.0 : 4.5;
    final ratio = contrastRatio(effectiveFg, bg);
    if (ratio + 0.005 < required) {
      issues.add(ContrastIssue(text, ratio, required, fg, bg));
    }
  }
  return issues;
}

bool _visible(RenderParagraph p) {
  final view = p.owner?.rootNode;
  if (view is! RenderBox || !view.hasSize) return true;
  final rect = MatrixUtils.transformRect(
      p.getTransformTo(view), Offset.zero & p.size);
  return rect.overlaps(Offset.zero & view.size);
}
