import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ironrank/core/config/app_config.dart';
import 'package:ironrank/core/storage/local_store.dart';
import 'package:ironrank/core/storage/token_storage.dart';
import 'package:ironrank/core/theme/app_theme.dart';
import 'package:ironrank/core/utils/time_zone.dart';

/// Phone-sized viewport (logical 412×915 at 1x) for screen tests.
const phoneSize = Size(412, 915);

LocalStore? _store;

/// Token storage that never touches the platform keystore.
class MemoryTokenStorage extends TokenStorage {
  AuthTokens? _tokens;

  @override
  Future<AuthTokens?> read() async => _tokens;

  @override
  Future<void> save(AuthTokens tokens) async => _tokens = tokens;

  @override
  Future<void> clear() async => _tokens = null;
}

/// Golden snapshots are opt-in:
///   flutter test --dart-define=GOLDENS=true --update-goldens
/// Pixel-exact comparisons differ between operating systems, so the default run
/// only checks that screens build and lay out without errors.
const goldensEnabled = bool.fromEnvironment('GOLDENS');

Future<void> snapshot(Finder finder, String name) async {
  if (!goldensEnabled) return;
  await expectLater(finder, matchesGoldenFile('goldens/$name.png'));
}

bool _iconsLoaded = false;

/// Loads the Material Icons font so snapshots show real glyphs instead of boxes.
Future<void> _loadIcons() async {
  if (_iconsLoaded) return;
  final loader = FontLoader('MaterialIcons')..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
  await loader.load();
  _iconsLoaded = true;
}

/// Advances [frames] frames of [step] each, letting multi-frame animations run.
Future<void> pumpFrames(WidgetTester tester, {int frames = 20, Duration step = const Duration(milliseconds: 50)}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(step);
  }
}

/// Fresh in-memory store for each test (safe inside fake-async widget tests).
Future<LocalStore> testStore() async => LocalStore.memory();

/// A real Hive-backed store in a temp directory, for persistence tests only.
/// Never use it inside testWidgets: Hive file I/O can't finish under fake async.
Future<LocalStore> hiveTestStore() async {
  if (_store != null) return _store!;
  final dir = await Directory.systemTemp.createTemp('ironrank_test');
  _store = await LocalStore.open(path: dir.path);
  return _store!;
}

const testConfig = AppConfig(
  apiBaseUrl: 'http://localhost:0/api/v1',
  connectTimeout: Duration(milliseconds: 1),
  receiveTimeout: Duration(milliseconds: 1),
);

/// Pumps [child] inside the real theme and a ProviderScope.
Future<void> pumpScreen(
  WidgetTester tester,
  Widget child, {
  List<dynamic> overrides = const [],
  ThemeMode themeMode = ThemeMode.dark,
  LocalStore? store,
  double textScale = 1,
}) async {
  GoogleFonts.config.allowRuntimeFetching = false;
  tester.view.physicalSize = phoneSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.runAsync(_loadIcons);
  final localStore = store ?? (await tester.runAsync(testStore))!;
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        appConfigProvider.overrideWithValue(testConfig),
        localStoreProvider.overrideWithValue(localStore),
        tokenStorageProvider.overrideWithValue(MemoryTokenStorage()),
        // The platform time-zone lookup never resolves under fake async.
        timeZoneProvider.overrideWith((ref) async => 'UTC'),
        ...overrides.cast(),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: themeMode,
        // Simulates the system accessibility text size.
        builder: (context, app) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
          child: app!,
        ),
        home: child,
      ),
    ),
  );
}
