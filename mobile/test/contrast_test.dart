import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ironrank/core/theme/app_colors.dart';

/// WCAG 2.1 relative luminance.
double _luminance(Color c) {
  double ch(double v) => v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
}

/// Contrast ratio between [fg] composited over [bg] and [bg].
double contrast(Color fg, Color bg) {
  final over = Color.alphaBlend(fg, bg);
  final a = _luminance(over), b = _luminance(bg);
  return (math.max(a, b) + 0.05) / (math.min(a, b) + 0.05);
}

void main() {
  for (final (name, c) in [('dark', AppColors.dark), ('light', AppColors.light)]) {
    group('$name theme contrast (WCAG AA)', () {
      // Text sits on the page background and on glass cards over it.
      final surfaces = {'background': c.background, 'card': Color.alphaBlend(c.glassFill, c.background), 'elevated': c.backgroundElevated};

      for (final s in surfaces.entries) {
        test('primary/secondary/muted text on ${s.key}', () {
          expect(contrast(c.textPrimary, s.value), greaterThanOrEqualTo(7), reason: 'textPrimary (AAA)');
          expect(contrast(c.textSecondary, s.value), greaterThanOrEqualTo(4.5), reason: 'textSecondary');
          // Muted text is used for small labels, so it must also reach 4.5:1.
          expect(contrast(c.textMuted, s.value), greaterThanOrEqualTo(4.5), reason: 'textMuted');
        });
      }

      test('text on the accent gradient (buttons)', () {
        // Large, bold labels: AA large-text threshold (3:1) at both gradient ends.
        expect(contrast(c.onAccent, c.accentStart), greaterThanOrEqualTo(3));
        expect(contrast(c.onAccent, c.accentEnd), greaterThanOrEqualTo(3));
      });

      test('status colours are distinguishable on the background', () {
        for (final status in [c.success, c.warning, c.danger, c.accent]) {
          expect(contrast(status, c.background), greaterThanOrEqualTo(3));
        }
      });
    });
  }
}
