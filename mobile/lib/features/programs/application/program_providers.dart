import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';

import '../data/program.dart';
import '../data/program_repository.dart';

final programListProvider = FutureProvider.autoDispose.family<List<Program>, ProgramScope>(
  (ref, scope) => ref.watch(programRepositoryProvider).list(scope),
);

final programDetailProvider = FutureProvider.autoDispose.family<Program, String>(
  (ref, id) => ref.watch(programRepositoryProvider).get(id),
);

/// The active program and the next day to train (used by Home and Workout).
final activeProgramProvider = FutureProvider<ActiveProgram>((ref) => ref.watch(programRepositoryProvider).active());

/// `invalidate` of either a `Ref` or a `WidgetRef`.
typedef Invalidate = void Function(ProviderOrFamily provider, {bool asReload});

/// Refreshes every program-related view after a mutation:
/// `invalidatePrograms(ref.invalidate)`.
void invalidatePrograms(Invalidate invalidate) {
  invalidate(programListProvider);
  invalidate(programDetailProvider);
  invalidate(activeProgramProvider);
}
