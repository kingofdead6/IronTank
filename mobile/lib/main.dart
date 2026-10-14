import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/notifications/notification_service.dart';
import 'core/storage/local_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // Fonts ship in assets/fonts, so the app looks right offline on first launch.
  GoogleFonts.config.allowRuntimeFetching = false;
  _registerFontLicenses();

  final notifications = NotificationService();
  final results = await Future.wait([AppConfig.load(), LocalStore.open(), notifications.init()]);

  runApp(
    ProviderScope(
      // Failed requests surface immediately; screens offer their own retry.
      retry: (_, _) => null,
      overrides: [
        appConfigProvider.overrideWithValue(results[0] as AppConfig),
        localStoreProvider.overrideWithValue(results[1] as LocalStore),
        notificationServiceProvider.overrideWithValue(notifications),
      ],
      child: const IronRankApp(),
    ),
  );
}

/// The bundled fonts are SIL OFL licensed; list them on the licenses page.
void _registerFontLicenses() {
  LicenseRegistry.addLicense(() async* {
    for (final (family, file) in const [('Inter Tight', 'OFL-InterTight.txt'), ('Space Grotesk', 'OFL-SpaceGrotesk.txt')]) {
      final text = await rootBundle.loadString('assets/fonts/$file');
      yield LicenseEntryWithLineBreaks([family], text);
    }
  });
}
