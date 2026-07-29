import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/database_providers.dart';
import '../../../core/layout/constrained_content.dart';
import '../../../core/layout/content_aligned_app_bar.dart';
import '../../../core/navigation/route_paths.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../domain/domain.dart';
import '../../settings/providers/settings_framework_providers.dart';
import '../providers/profile_my_expenses_provider.dart';
import '../widgets/profile_expense_tile.dart';
import '../widgets/profile_expenses_filters_bar.dart';

class ProfileExpensesPage extends ConsumerStatefulWidget {
  const ProfileExpensesPage({super.key});

  @override
  ConsumerState<ProfileExpensesPage> createState() =>
      _ProfileExpensesPageState();
}

class _ProfileExpensesPageState extends ConsumerState<ProfileExpensesPage> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: ref.read(profileExpensesFilterProvider).query,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(profileExpensesFilterProvider);
    final filteredAsync = ref.watch(filteredProfileExpensesProvider);
    final allAsync = ref.watch(profileMyExpensesProvider);
    final displayCurrency = ref.watch(displayCurrencyProvider);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final allItems = allAsync.asData?.value ?? const <ProfileExpenseItem>[];

    return LayoutBuilder(
      builder: (context, layoutConstraints) {
        return Scaffold(
          appBar: ContentAlignedAppBar(
            contentAreaWidth: layoutConstraints.maxWidth,
            title: Text('profile_all_expenses_title'.tr()),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go(RoutePaths.profile);
                }
              },
            ),
            actions: [
              // Always reserve the slot so showing/hiding clear doesn't shift the bar.
              IconButton(
                tooltip: 'profile_expenses_clear_filters'.tr(),
                onPressed: filter.hasActiveFilters
                    ? () {
                        ref.read(profileExpensesFilterProvider.notifier).state =
                            const ProfileExpensesFilter();
                        _searchController.clear();
                      }
                    : null,
                icon: Icon(
                  Icons.filter_alt_off_rounded,
                  color: filter.hasActiveFilters
                      ? null
                      : Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.28),
                ),
              ),
            ],
          ),
          body: ConstrainedContent(
            child: RefreshIndicator(
              onRefresh: () async {
                await ref.read(dataSyncServiceProvider.notifier).syncNow();
                ref.invalidate(profileMyExpensesProvider);
              },
              child: filteredAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text('$e'),
                    ),
                  ],
                ),
                data: (items) {
                  return CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(
                        child: ProfileExpensesFiltersBar(
                          searchController: _searchController,
                          allItems: allItems,
                          onFilterChanged: (next) {
                            ref
                                    .read(
                                      profileExpensesFilterProvider.notifier,
                                    )
                                    .state =
                                next;
                          },
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: cs.surfaceContainerHighest.withValues(
                                alpha: 0.5,
                              ),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: cs.outlineVariant.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.receipt_long_outlined,
                                  size: 18,
                                  color: cs.primary,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'analytics_expense_count'.tr(
                                      namedArgs: {'count': '${items.length}'},
                                    ),
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                Text(
                                  _formatTotal(items, displayCurrency),
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (items.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.search_off_rounded,
                                    size: 48,
                                    color: cs.onSurfaceVariant.withValues(
                                      alpha: 0.55,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    filter.hasActiveFilters
                                        ? 'profile_expenses_no_matches'.tr()
                                        : 'profile_my_expenses_empty'.tr(),
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.bodyLarge?.copyWith(
                                      color: cs.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      else
                        SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => ProfileExpenseTile(
                              item: items[index],
                              showManageMenu: true,
                            ),
                            childCount: items.length,
                          ),
                        ),
                      const SliverToBoxAdapter(child: SizedBox(height: 32)),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatTotal(
    List<ProfileExpenseItem> items,
    String displayCurrency,
  ) {
    if (items.isEmpty) {
      return CurrencyFormatter.formatCents(
        0,
        displayCurrency.isEmpty ? 'USD' : displayCurrency,
      );
    }

    final currencies = items.map((e) => e.group.currencyCode).toSet();
    final code = currencies.length == 1
        ? currencies.first
        : (displayCurrency.isEmpty ? currencies.first : displayCurrency);

    var total = 0;
    for (final item in items) {
      if (item.group.currencyCode != code) continue;
      final signed = item.expense.transactionType == TransactionType.income
          ? -item.myShareCents
          : item.myShareCents;
      total += signed;
    }
    final formatted = CurrencyFormatter.formatCents(total.abs(), code);
    return total < 0 ? '−$formatted' : formatted;
  }
}
