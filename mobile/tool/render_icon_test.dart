// Renders the launcher icon artwork from the app's own design tokens.
//
//   flutter test tool/render_icon_test.dart --update-goldens
//   dart run flutter_launcher_icons
//
// Writes assets/icon/icon.png (full icon, iOS + legacy Android) and
// assets/icon/icon_foreground.png + icon_background.png (Android adaptive icon layers).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ironrank/core/theme/app_colors.dart';

const _size = 1024.0;

/// Fraction of the canvas the bolt occupies. Adaptive icons keep their content
/// inside the central ~66% safe zone, so the foreground uses a smaller glyph.
const _boltFull = 0.78;
const _boltAdaptive = 0.5;

Widget _icon({required bool background, required double boltFraction, bool bolt = true}) {
  const c = AppColors.dark;
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Container(
      width: _size,
      height: _size,
      decoration: background
          ? BoxDecoration(
              gradient: LinearGradient(colors: [c.accentStart, c.accentEnd], begin: Alignment.topLeft, end: Alignment.bottomRight),
            )
          : null,
      alignment: Alignment.center,
      child: bolt ? Icon(Icons.bolt_rounded, size: _size * boltFraction, color: c.onAccent) : null,
    ),
  );
}

void main() {
  setUpAll(() async {
    final loader = FontLoader('MaterialIcons')..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await loader.load();
  });

  for (final (name, background, fraction, bolt) in [
    ('icon', true, _boltFull, true),
    ('icon_foreground', false, _boltAdaptive, true),
    ('icon_background', true, 0.0, false),
  ]) {
    testWidgets('render $name', (tester) async {
      tester.view.physicalSize = const Size(_size, _size);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(RepaintBoundary(child: _icon(background: background, boltFraction: fraction, bolt: bolt)));
      await expectLater(find.byType(RepaintBoundary).first, matchesGoldenFile('../assets/icon/$name.png'));
    });
  }
}
