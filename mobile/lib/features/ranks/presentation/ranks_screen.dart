import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/motion.dart';
import '../../../core/utils/units.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/rank_badge.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/staggered.dart';
import '../../auth/application/auth_controller.dart';
import '../../exercises/data/exercise.dart';
import '../../progress/application/progress_providers.dart';
import '../../progress/data/progress_models.dart';
import '../application/rank_seen_store.dart';
import 'widgets/level_up_dialog.dart';

/// Strength ranks: overall badge, every lift, muscle groups and the tier ladder.
class RanksScreen extends ConsumerStatefulWidget {
  const RanksScreen({super.key});

  @override
  ConsumerState<RanksScreen> createState() => _RanksScreenState();
}

class _RanksScreenState extends ConsumerState<RanksScreen> {
  bool _checkedLevelUps = false;

  /// Celebrates tiers gained since the last visit, then records what was seen.
  Future<void> _celebrate(Ranks ranks) async {
    if (_checkedLevelUps) return;
    _checkedLevelUps = true;
    final seen = ref.read(rankSeenStoreProvider);
    final ups = seen.levelUps(ranks);
    await seen.save(ranks.tierSnapshot);
    if (ups.isEmpty || !mounted) return;
    await Future<void>.delayed(AppMotion.slow);
    if (mounted) await showLevelUp(context, ups.first, more: ups.length - 1);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(ranksProvider);
    final unit = ref.watch(currentUserProvider)?.unit ?? WeightUnit.kg;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: const Text('Ranks')),
      body: AppBackground(
        intensity: 1.4,
        child: SafeArea(
          child: async.when(
            loading: () => const SkeletonList(count: 4, itemHeight: AppSizes.chartHeightSm),
            error: (e, _) => ErrorState(error: e, onRetry: () => ref.invalidate(ranksProvider)),
            data: (ranks) {
              // Runs once per visit (guarded by _checkedLevelUps).
              WidgetsBinding.instance.addPostFrameCallback((_) => _celebrate(ranks));
              return RefreshIndicator(
                onRefresh: () => ref.refresh(ranksProvider.future),
                child: _content(ranks, unit),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _content(Ranks ranks, WeightUnit unit) {
    final c = context.colors;
    final o = ranks.overall;
    final items = <Widget>[
      Center(
        child: RankBadge(
          tierIndex: o.ranked ? o.tierIndex : null,
          tierName: o.tier,
          progress: o.progress,
          size: AppSizes.rankBadgeLg,
        ),
      ),
      const SizedBox(height: AppSpacing.lg),
      Text(
        o.ranked ? o.tier!.toUpperCase() : 'UNRANKED',
        textAlign: TextAlign.center,
        style: context.text.displaySmall?.copyWith(letterSpacing: 4, color: o.ranked ? TierColors.of(o.tierIndex).primary : c.textMuted),
      ),
      Text(
        o.ranked
            ? (o.nextTier == null ? 'The very top. Legendary.' : '${o.progress}% of the way to ${o.nextTier}')
            : 'Log the big lifts to earn your rank',
        textAlign: TextAlign.center,
        style: context.text.bodyLarge?.copyWith(color: c.textSecondary),
      ),
      if (o.ranked)
        Text(
          'Overall rank across ${ranks.liftsRanked} of ${ranks.lifts.length} lifts',
          textAlign: TextAlign.center,
          style: context.text.bodySmall,
        ),
      if (ranks.assumedSex) ...[
        const SizedBox(height: AppSpacing.lg),
        GlassCard(
          onTap: () => context.push(Routes.editProfile),
          child: Row(
            children: [
              Icon(Icons.info_outline_rounded, color: c.warning),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: Text('Set your sex in your profile for accurate strength standards.', style: context.text.bodyMedium)),
              Icon(Icons.chevron_right_rounded, color: c.textMuted),
            ],
          ),
        ),
      ],
      const SectionHeader(title: 'Lifts'),
      for (final lift in ranks.lifts)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: _LiftCard(lift: lift, unit: unit),
        ),
      const SectionHeader(title: 'Muscle groups'),
      GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: AppSpacing.md,
        crossAxisSpacing: AppSpacing.md,
        childAspectRatio: 0.82,
        children: [for (final g in ranks.muscleGroups) _GroupTile(group: g)],
      ),
      const SectionHeader(title: 'Tiers'),
      _TierLadder(tiers: ranks.tiers, current: o.tierIndex),
      const SizedBox(height: AppSpacing.lg),
      Text(
        'Ranks compare your best estimated 1RM from the last 12 months to your bodyweight, '
        'using sex-specific strength standards. Pull-ups and dips include your bodyweight.',
        style: context.text.bodySmall,
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: AppSpacing.xxl),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.lg, AppSpacing.screen, 0),
      children: [for (var i = 0; i < items.length; i++) items[i].staggered(i)],
    );
  }
}

class _LiftCard extends StatelessWidget {
  const _LiftCard({required this.lift, required this.unit});

  final LiftRank lift;
  final WeightUnit unit;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = lift.standing;
    final tier = TierColors.of(s.ranked ? s.tierIndex : null);

    return GlassCard(
      blur: false,
      onTap: lift.exerciseId == null ? null : () => context.push(Routes.exercise(lift.exerciseId!)),
      semanticLabel: '${lift.name}: ${s.ranked ? s.tier : 'unranked'}',
      child: Row(
        children: [
          RankBadge(
            tierIndex: s.ranked ? s.tierIndex : null,
            tierName: s.tier,
            progress: s.progress,
            size: AppSizes.rankBadgeSm * 1.25,
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(lift.name, style: context.text.titleMedium)),
                    Text(s.ranked ? s.tier! : 'Unranked', style: context.text.labelLarge?.copyWith(color: s.ranked ? tier.primary : c.textMuted)),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                if (s.ranked) ...[
                  Text(
                    '${Units.weight(lift.e1rm ?? 0, unit)} e1RM · ${lift.ratio?.toStringAsFixed(2)}× bodyweight',
                    style: context.text.bodySmall?.copyWith(color: c.textSecondary),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _TierProgress(progress: s.progress / 100, tier: tier),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    s.nextTier == null
                        ? 'Maxed out'
                        : '${s.nextTier} at ${Units.weight(lift.nextTierE1rm ?? 0, unit)} e1RM',
                    style: context.text.bodySmall,
                  ),
                ] else
                  Text('Log a working set to get ranked', style: context.text.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TierProgress extends StatelessWidget {
  const _TierProgress({required this.progress, required this.tier});

  final double progress;
  final TierColors tier;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: AppRadii.pillAll,
      child: SizedBox(
        height: AppSpacing.sm,
        child: Stack(
          children: [
            Positioned.fill(child: ColoredBox(color: context.colors.glassFill)),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress),
              duration: AppMotion.ring,
              curve: AppMotion.emphasized,
              builder: (_, v, _) => FractionallySizedBox(
                widthFactor: v,
                heightFactor: 1,
                alignment: Alignment.centerLeft,
                child: DecoratedBox(decoration: BoxDecoration(gradient: tier.gradient)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupTile extends StatelessWidget {
  const _GroupTile({required this.group});

  final MuscleGroupRank group;

  @override
  Widget build(BuildContext context) {
    final s = group.standing;
    return GlassCard(
      blur: false,
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          RankBadge(
            tierIndex: s.ranked ? s.tierIndex : null,
            tierName: s.tier,
            progress: s.progress,
            size: AppSizes.rankBadgeSm,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(labelize(group.group), style: context.text.labelLarge),
          Text(
            s.ranked ? s.tier! : '—',
            style: context.text.bodySmall?.copyWith(color: s.ranked ? TierColors.of(s.tierIndex).primary : null),
          ),
        ],
      ),
    );
  }
}

class _TierLadder extends StatelessWidget {
  const _TierLadder({required this.tiers, required this.current});

  final List<String> tiers;
  final int? current;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < tiers.length; i++)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.md),
              child: AnimatedOpacity(
                duration: AppMotion.medium,
                opacity: current == null || i <= current! ? 1 : AppOpacity.disabled,
                child: Column(
                  children: [
                    RankBadge(tierIndex: i, tierName: tiers[i], size: AppSizes.rankBadgeSm, showProgress: false),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      tiers[i],
                      style: context.text.labelMedium?.copyWith(
                        color: i == current ? TierColors.of(i).primary : null,
                        fontWeight: i == current ? FontWeight.w800 : null,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
