import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/local_store.dart';
import '../../progress/data/progress_models.dart';

/// A tier increase to celebrate.
class LevelUp {
  const LevelUp({required this.label, required this.fromIndex, required this.toIndex, required this.tiers});

  /// "Overall" or a lift name.
  final String label;
  final int fromIndex;
  final int toIndex;
  final List<String> tiers;
}

/// Remembers the tiers the user has already seen on this device, so the
/// Ranks screen can celebrate tiers gained since the last visit.
class RankSeenStore {
  RankSeenStore(this._store);

  final LocalStore _store;
  static const _key = 'seenRankTiers';

  // Stored in the per-user cache, which is wiped on logout, so another
  // account on this device starts from its own baseline.
  Map<String, int>? read() => _store.readJson(_key)?.map((k, v) => MapEntry(k, (v as num).toInt()));

  Future<void> save(Map<String, int> tiers) => _store.writeJson(_key, tiers);

  Future<void> clear() => _store.deleteJson(_key);

  /// Tier increases between the stored snapshot and [ranks], overall first.
  /// Returns nothing on the very first visit (there's no baseline yet).
  List<LevelUp> levelUps(Ranks ranks) {
    final seen = read();
    if (seen == null) return const [];
    final current = ranks.tierSnapshot;
    final names = {'overall': 'Overall', for (final l in ranks.lifts) l.key: l.name};
    final ups = <LevelUp>[
      for (final entry in current.entries)
        if (seen[entry.key] != null && entry.value > seen[entry.key]!)
          LevelUp(label: names[entry.key] ?? entry.key, fromIndex: seen[entry.key]!, toIndex: entry.value, tiers: ranks.tiers),
    ];
    ups.sort((a, b) => a.label == 'Overall' ? -1 : (b.label == 'Overall' ? 1 : b.toIndex.compareTo(a.toIndex)));
    return ups;
  }
}

final rankSeenStoreProvider = Provider<RankSeenStore>((ref) => RankSeenStore(ref.watch(localStoreProvider)));
