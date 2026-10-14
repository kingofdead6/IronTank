import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/motion.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/gradient_button.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/staggered.dart';
import '../application/program_providers.dart';
import '../data/program_repository.dart';
import 'widgets/program_card.dart';

/// "My programs" and built-in templates.
class ProgramsScreen extends ConsumerStatefulWidget {
  const ProgramsScreen({super.key});

  @override
  ConsumerState<ProgramsScreen> createState() => _ProgramsScreenState();
}

class _ProgramsScreenState extends ConsumerState<ProgramsScreen> {
  ProgramScope _scope = ProgramScope.mine;

  @override
  Widget build(BuildContext context) {
    final programs = ref.watch(programListProvider(_scope));
    return Scaffold(
      appBar: AppBar(title: const Text('Programs')),
      extendBodyBehindAppBar: true,
      floatingActionButton: _scope == ProgramScope.mine
          ? FloatingActionButton.extended(
              onPressed: () => context.push(Routes.programBuilderNew),
              icon: const Icon(Icons.add_rounded),
              label: const Text('New program'),
            )
          : null,
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.md, AppSpacing.screen, AppSpacing.md),
                child: SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<ProgramScope>(
                    segments: const [
                      ButtonSegment(value: ProgramScope.mine, label: Text('My programs'), icon: Icon(Icons.person_rounded)),
                      ButtonSegment(value: ProgramScope.templates, label: Text('Templates'), icon: Icon(Icons.auto_awesome_rounded)),
                    ],
                    selected: {_scope},
                    onSelectionChanged: (s) => setState(() => _scope = s.first),
                  ),
                ),
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: AppMotion.medium,
                  child: RefreshIndicator(
                    key: ValueKey(_scope),
                    onRefresh: () => ref.refresh(programListProvider(_scope).future),
                    child: programs.when(
                      loading: () => const SkeletonList(count: 4, itemHeight: AppSizes.chartHeightSm),
                      error: (e, _) => ErrorState(error: e, onRetry: () => ref.invalidate(programListProvider(_scope))),
                      data: (list) {
                        if (list.isEmpty) {
                          return ListView(
                            children: [
                              EmptyState(
                                icon: Icons.view_agenda_outlined,
                                title: 'No programs yet',
                                message: 'Start from a proven template or build your own split.',
                                actionLabel: 'Browse templates',
                                onAction: () => setState(() => _scope = ProgramScope.templates),
                              ),
                              Padding(
                                padding: AppSpacing.screenPadding,
                                child: GradientButton(
                                  label: 'Build from scratch',
                                  variant: GradientButtonVariant.outlined,
                                  onPressed: () => context.push(Routes.programBuilderNew),
                                ),
                              ),
                            ],
                          );
                        }
                        return ListView.separated(
                          padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 0, AppSpacing.screen, AppSpacing.huge * 1.5),
                          itemCount: list.length + (_scope == ProgramScope.templates ? 1 : 0),
                          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
                          itemBuilder: (_, i) {
                            if (i == list.length) {
                              return Text(
                                'Activating a template copies it into My programs so you can tweak it.',
                                textAlign: TextAlign.center,
                                style: context.text.bodySmall,
                              );
                            }
                            final p = list[i];
                            return ProgramCard(program: p, onTap: () => context.push(Routes.program(p.id))).staggered(i);
                          },
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
