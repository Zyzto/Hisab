import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import '../../../core/layout/content_aligned_app_bar.dart';
import '../../../core/layout/constrained_content.dart';
import '../../../core/navigation/nav_back.dart';
import '../../../core/navigation/route_paths.dart';
import '../../../core/utils/error_report_helper.dart';
import '../../../core/widgets/error_content.dart';
import '../../groups/providers/groups_provider.dart';
import '../../groups/widgets/group_card.dart';
import '../../groups/widgets/group_section_header.dart';
import '../../../core/repository/repository_providers.dart';
import '../../../domain/domain.dart';

class ArchivedGroupsPage extends ConsumerStatefulWidget {
  const ArchivedGroupsPage({super.key});

  @override
  ConsumerState<ArchivedGroupsPage> createState() => _ArchivedGroupsPageState();
}

class _ArchivedGroupsPageState extends ConsumerState<ArchivedGroupsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      seedParentHistoryForBrowserBack(
        context: context,
        parentPath: RoutePaths.home,
        currentPath: RoutePaths.archivedGroups,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final archivedAsync = ref.watch(archivedGroupsProvider);
    final locallyArchivedAsync = ref.watch(locallyArchivedGroupsProvider);
    final canPop = routerCanPop(context);

    return PopScope(
      canPop: canPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) popOrGo(context, RoutePaths.home);
      },
      child: LayoutBuilder(
        builder: (context, layoutConstraints) {
          return Scaffold(
            appBar: ContentAlignedAppBar(
              contentAreaWidth: layoutConstraints.maxWidth,
              title: Text('archived_groups'.tr()),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => popOrGo(context, RoutePaths.home),
              ),
            ),
            body: ConstrainedContent(
              child: archivedAsync.when(
                data: (archived) => locallyArchivedAsync.when(
                  data: (locallyArchived) {
                    final hasAny =
                        archived.isNotEmpty || locallyArchived.isNotEmpty;
                    if (!hasAny) {
                      final theme = Theme.of(context);
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primaryContainer
                                      .withValues(alpha: 0.55),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.archive_outlined,
                                  size: 34,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'no_archived_items'.tr(),
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    return ListView(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      children: [
                        if (archived.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                            child: GroupSectionHeader(
                              label: 'archived_groups'.tr(),
                            ),
                          ),
                          ...archived.map(
                            (group) => GroupCard(
                              key: ValueKey('global-${group.id}'),
                              group: group,
                              onTap: () => context
                                  .push(RoutePaths.groupDetail(group.id)),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        if (locallyArchived.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                            child: GroupSectionHeader(
                              label: 'hidden_by_me'.tr(),
                            ),
                          ),
                          ...locallyArchived.map(
                            (group) => _LocallyArchivedTile(
                              key: ValueKey('local-${group.id}'),
                              group: group,
                              onUnhide: () => ref
                                  .read(groupRepositoryProvider)
                                  .clearLocalArchived(group.id),
                              onTap: () => context
                                  .push(RoutePaths.groupDetail(group.id)),
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, st) {
                    sendErrorTelemetryIfOnline(
                      ref,
                      message: e.toString(),
                      details: e.toString(),
                    );
                    return Center(
                      child: ErrorContentWidget(
                        message: e.toString(),
                        details: e.toString(),
                        stackTrace: st,
                        onRetry: () {
                          ref.invalidate(archivedGroupsProvider);
                          ref.invalidate(locallyArchivedGroupsProvider);
                        },
                      ),
                    );
                  },
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, st) {
                  sendErrorTelemetryIfOnline(
                    ref,
                    message: e.toString(),
                    details: e.toString(),
                  );
                  return Center(
                    child: ErrorContentWidget(
                      message: e.toString(),
                      details: e.toString(),
                      stackTrace: st,
                      onRetry: () {
                        ref.invalidate(archivedGroupsProvider);
                        ref.invalidate(locallyArchivedGroupsProvider);
                      },
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

class _LocallyArchivedTile extends StatelessWidget {
  const _LocallyArchivedTile({
    super.key,
    required this.group,
    required this.onUnhide,
    required this.onTap,
  });

  final Group group;
  final VoidCallback onUnhide;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: GroupCard(group: group, onTap: onTap),
          ),
          IconButton(
            icon: const Icon(Icons.visibility_outlined),
            tooltip: 'unhide_from_my_list'.tr(),
            onPressed: onUnhide,
          ),
        ],
      ),
    );
  }
}
