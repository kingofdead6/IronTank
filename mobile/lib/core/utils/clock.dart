import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/motion.dart';

/// Ticks once per second for timers. Widgets that show elapsed/remaining time
/// watch this instead of running their own periodic timers.
final clockProvider = StreamProvider.autoDispose<DateTime>(
  (ref) => Stream<DateTime>.periodic(AppMotion.tick, (_) => DateTime.now()),
);

/// Current time from [clockProvider], falling back to now before the first tick.
DateTime nowFrom(AsyncValue<DateTime> clock) => clock.value ?? DateTime.now();
