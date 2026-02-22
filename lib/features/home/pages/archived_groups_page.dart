import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import '../../../core/navigation/route_paths.dart';
import '../../../core/widgets/error_content.dart';
import '../../groups/providers/groups_provider.dart';
import '../../groups/widgets/group_card.dart';
import '../../../core/repository/repository_providers.dart';
import '../../../domain/domain.dart';

class ArchivedGroupsPage extends ConsumerWidget {
  const ArchivedGroupsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final archivedAsync = ref.watch(archivedGroupsProvider);
    final locallyArchivedAsync = ref.watch(locallyArchivedGroupsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('archived_groups'.tr()),
      ),
      body: archivedAsync.when(
        data: (archived) => locallyArchivedAsync.when(
          data: (locallyArchived) {
            final hasAny = archived.isNotEmpty || locallyArchived.isNotEmpty;
            if (!hasAny) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.archive_outlined,
                        size: 64,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'no_archived_groups'.tr(),
                        style: Theme.of(context).textTheme.titleMedium,
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
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Text(
                      'archived_groups'.tr(),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ),
                  ...archived.map(
                    (group) => GroupCard(
                      key: ValueKey('global-${group.id}'),
                      group: group,
                      onTap: () =>
                          context.push(RoutePaths.groupDetail(group.id)),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (locallyArchived.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Text(
                      'hidden_by_me'.tr(),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ),
                  ...locallyArchived.map(
                    (group) => _LocallyArchivedTile(
                      key: ValueKey('local-${group.id}'),
                      group: group,
                      onUnhide: () => ref
                          .read(groupRepositoryProvider)
                          .clearLocalArchived(group.id),
                      onTap: () =>
                          context.push(RoutePaths.groupDetail(group.id)),
                    ),
                  ),
                ],
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: ErrorContentWidget(
              message: e.toString(),
              onRetry: () {
                ref.invalidate(archivedGroupsProvider);
                ref.invalidate(locallyArchivedGroupsProvider);
              },
            ),
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: ErrorContentWidget(
            message: e.toString(),
            onRetry: () {
              ref.invalidate(archivedGroupsProvider);
              ref.invalidate(locallyArchivedGroupsProvider);
            },
          ),
        ),
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
            child: GroupCard(
              group: group,
              onTap: onTap,
            ),
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
