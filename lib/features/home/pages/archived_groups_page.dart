import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import '../../../core/navigation/route_paths.dart';
import '../../../core/widgets/async_value_builder.dart';
import '../../groups/providers/groups_provider.dart';
import '../../groups/widgets/group_card.dart';
import '../../../domain/domain.dart';

class ArchivedGroupsPage extends ConsumerWidget {
  const ArchivedGroupsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final archivedAsync = ref.watch(archivedGroupsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('archived_groups'.tr()),
      ),
      body: AsyncValueBuilder<List<Group>>(
        value: archivedAsync,
        data: (context, groups) {
          if (groups.isEmpty) {
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
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: groups.length,
            itemBuilder: (context, index) {
              final group = groups[index];
              return GroupCard(
                key: ValueKey(group.id),
                group: group,
                onTap: () => context.push(RoutePaths.groupDetail(group.id)),
              );
            },
          );
        },
      ),
    );
  }
}
