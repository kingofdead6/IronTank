/// Models for `/stats/overview`, `/ranks`, `/prs` and bodyweight history.
library;

double _d(Object? v) => (v as num?)?.toDouble() ?? 0;
int _i(Object? v) => (v as num?)?.toInt() ?? 0;

class WeeklyPoint {
  const WeeklyPoint({required this.weekStart, required this.sessions, required this.volume, required this.durationSec});

  factory WeeklyPoint.fromJson(Map<String, dynamic> j) => WeeklyPoint(
    weekStart: DateTime.parse(j['weekStart'] as String),
    sessions: _i(j['sessions']),
    volume: _d(j['volume']),
    durationSec: _i(j['durationSec']),
  );

  final DateTime weekStart;
  final int sessions;
  final double volume;
  final int durationSec;
}

class MuscleShare {
  const MuscleShare({required this.group, required this.sets, required this.percent});

  factory MuscleShare.fromJson(Map<String, dynamic> j) =>
      MuscleShare(group: j['group'] as String, sets: _d(j['sets']), percent: _d(j['percent']));

  final String group;
  final double sets;
  final double percent;
}

class HeatmapDay {
  const HeatmapDay({required this.date, required this.sessions, required this.volume});

  factory HeatmapDay.fromJson(Map<String, dynamic> j) =>
      HeatmapDay(date: DateTime.parse(j['date'] as String), sessions: _i(j['sessions']), volume: _d(j['volume']));

  final DateTime date;
  final int sessions;
  final double volume;
}

class StatsOverview {
  const StatsOverview({
    required this.from,
    required this.to,
    required this.weeks,
    required this.sessions,
    required this.volume,
    required this.durationSec,
    required this.calories,
    required this.prs,
    required this.avgSessionsPerWeek,
    required this.streakDays,
    required this.streakWeeks,
    required this.weekly,
    required this.muscleDistribution,
    required this.heatmap,
    this.daysSinceLastWorkout,
  });

  factory StatsOverview.fromJson(Map<String, dynamic> j) {
    final range = j['range'] as Map<String, dynamic>;
    final totals = j['totals'] as Map<String, dynamic>;
    final streak = j['streak'] as Map<String, dynamic>;
    List<T> list<T>(String key, T Function(Map<String, dynamic>) f) =>
        (j[key] as List<dynamic>).map((e) => f(e as Map<String, dynamic>)).toList();
    return StatsOverview(
      from: DateTime.parse(range['from'] as String),
      to: DateTime.parse(range['to'] as String),
      weeks: _i(range['weeks']),
      sessions: _i(totals['sessions']),
      volume: _d(totals['volume']),
      durationSec: _i(totals['durationSec']),
      calories: _i(totals['calories']),
      prs: _i(totals['prs']),
      avgSessionsPerWeek: _d(totals['avgSessionsPerWeek']),
      streakDays: _i(streak['days']),
      streakWeeks: _i(streak['weeks']),
      weekly: list('weekly', WeeklyPoint.fromJson),
      muscleDistribution: list('muscleDistribution', MuscleShare.fromJson),
      heatmap: list('heatmap', HeatmapDay.fromJson),
      daysSinceLastWorkout: (j['daysSinceLastWorkout'] as num?)?.toInt(),
    );
  }

  final DateTime from;
  final DateTime to;
  final int weeks;
  final int sessions;
  final double volume;
  final int durationSec;
  final int calories;
  final int prs;
  final double avgSessionsPerWeek;
  final int streakDays;
  final int streakWeeks;
  final List<WeeklyPoint> weekly;
  final List<MuscleShare> muscleDistribution;
  final List<HeatmapDay> heatmap;
  final int? daysSinceLastWorkout;

  bool get isEmpty => sessions == 0;
}

/// A tier placement (lift, muscle group or overall).
class TierStanding {
  const TierStanding({required this.ranked, this.tierIndex, this.tier, this.nextTier, this.progress = 0});

  factory TierStanding.fromJson(Map<String, dynamic> j) => TierStanding(
    ranked: j['ranked'] as bool? ?? false,
    tierIndex: (j['tierIndex'] as num?)?.toInt(),
    tier: j['tier'] as String?,
    nextTier: j['nextTier'] as String?,
    progress: _i(j['progress']),
  );

  final bool ranked;
  final int? tierIndex;
  final String? tier;
  final String? nextTier;

  /// 0–100 toward the next tier.
  final int progress;
}

class LiftRank {
  const LiftRank({
    required this.key,
    required this.name,
    required this.standing,
    this.ratio,
    this.e1rm,
    this.bodyweightKg,
    this.nextTierE1rm,
    this.exerciseId,
    this.thresholds = const [],
  });

  factory LiftRank.fromJson(Map<String, dynamic> j) => LiftRank(
    key: j['key'] as String,
    name: j['name'] as String,
    standing: TierStanding.fromJson(j),
    ratio: (j['ratio'] as num?)?.toDouble(),
    e1rm: (j['e1rm'] as num?)?.toDouble(),
    bodyweightKg: (j['bodyweightKg'] as num?)?.toDouble(),
    nextTierE1rm: (j['nextTierE1rm'] as num?)?.toDouble(),
    exerciseId: j['exerciseId'] as String?,
    thresholds: (j['thresholds'] as List<dynamic>? ?? const []).map((e) => (e as num).toDouble()).toList(),
  );

  final String key;
  final String name;
  final TierStanding standing;
  final double? ratio;
  final double? e1rm;
  final double? bodyweightKg;
  final double? nextTierE1rm;
  final String? exerciseId;
  final List<double> thresholds;
}

class MuscleGroupRank {
  const MuscleGroupRank({required this.group, required this.standing});

  factory MuscleGroupRank.fromJson(Map<String, dynamic> j) =>
      MuscleGroupRank(group: j['group'] as String, standing: TierStanding.fromJson(j));

  final String group;
  final TierStanding standing;
}

class Ranks {
  const Ranks({
    required this.tiers,
    required this.overall,
    required this.liftsRanked,
    required this.lifts,
    required this.muscleGroups,
    required this.assumedSex,
  });

  factory Ranks.fromJson(Map<String, dynamic> j) {
    final overall = j['overall'] as Map<String, dynamic>;
    return Ranks(
      tiers: (j['tiers'] as List<dynamic>).cast<String>(),
      overall: TierStanding.fromJson(overall),
      liftsRanked: _i(overall['liftsRanked']),
      lifts: (j['lifts'] as List<dynamic>).map((e) => LiftRank.fromJson(e as Map<String, dynamic>)).toList(),
      muscleGroups: (j['muscleGroups'] as List<dynamic>).map((e) => MuscleGroupRank.fromJson(e as Map<String, dynamic>)).toList(),
      assumedSex: j['assumedSex'] as bool? ?? false,
    );
  }

  final List<String> tiers;
  final TierStanding overall;
  final int liftsRanked;
  final List<LiftRank> lifts;
  final List<MuscleGroupRank> muscleGroups;
  final bool assumedSex;

  /// Tier index per lift key plus "overall" (for level-up detection).
  Map<String, int> get tierSnapshot => {
    if (overall.tierIndex != null) 'overall': overall.tierIndex!,
    for (final l in lifts)
      if (l.standing.tierIndex != null) l.key: l.standing.tierIndex!,
  };
}

class BodyweightEntry {
  const BodyweightEntry({required this.id, required this.kg, required this.date});

  factory BodyweightEntry.fromJson(Map<String, dynamic> j) =>
      BodyweightEntry(id: j['id'] as String, kg: _d(j['kg']), date: DateTime.parse(j['date'] as String));

  final String id;
  final double kg;
  final DateTime date;
}
