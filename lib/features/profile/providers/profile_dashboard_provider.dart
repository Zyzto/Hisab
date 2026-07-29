import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/expense_totals.dart';
import '../../../core/widgets/amount_with_secondary_display.dart';
import '../../../domain/domain.dart';
import '../../balance/providers/balance_provider.dart';
import '../../groups/providers/group_member_provider.dart';
import '../../groups/providers/groups_provider.dart';
import '../../settings/providers/display_currency_rate_provider.dart';
import '../../settings/providers/settings_framework_providers.dart';
import '../../transaction_scanner/providers/scanner_providers.dart';
import 'notification_providers.dart';

class ProfileBalanceRow {
  const ProfileBalanceRow({
    required this.group,
    required this.balanceCents,
    required this.currencyCode,
  });

  final Group group;
  final int balanceCents;
  final String currencyCode;

  bool get youOwe => balanceCents < 0;
  bool get owesYou => balanceCents > 0;
}

class ProfilePersonalBudgetRow {
  const ProfilePersonalBudgetRow({
    required this.group,
    required this.spentCents,
    this.budgetCents,
  });

  final Group group;
  final int spentCents;
  final int? budgetCents;

  bool get hasBudget => budgetCents != null && budgetCents! > 0;
  bool get overBudget => hasBudget && spentCents >= budgetCents!;
  bool get nearBudget =>
      hasBudget && !overBudget && spentCents >= (budgetCents! * 0.8).round();
  double get progress =>
      hasBudget ? (spentCents / budgetCents!).clamp(0.0, 1.2) : 0.0;
}

class ProfileGlobalNet {
  const ProfileGlobalNet({
    required this.displayCurrencyCode,
    required this.netDisplayCents,
    required this.convertedGroupCount,
    required this.skippedGroupCount,
    required this.isPartial,
  });

  final String displayCurrencyCode;
  final int netDisplayCents;
  final int convertedGroupCount;
  final int skippedGroupCount;
  final bool isPartial;
}

class ProfileKpis {
  const ProfileKpis({
    required this.sharedGroups,
    required this.personalLists,
    required this.archived,
    required this.pendingDrafts,
    required this.unreadNotifications,
  });

  final int sharedGroups;
  final int personalLists;
  final int archived;
  final int pendingDrafts;
  final int unreadNotifications;
}

class ProfileDashboardData {
  const ProfileDashboardData({
    required this.kpis,
    required this.balanceRows,
    required this.personalBudgets,
    required this.groups,
    this.globalNet,
  });

  final ProfileKpis kpis;
  final List<ProfileBalanceRow> balanceRows;
  final List<ProfilePersonalBudgetRow> personalBudgets;
  final List<Group> groups;
  final ProfileGlobalNet? globalNet;
}

final profileDashboardProvider = Provider<AsyncValue<ProfileDashboardData>>((
  ref,
) {
  final groupsAsync = ref.watch(groupsProvider);
  final archivedAsync = ref.watch(archivedGroupsProvider);
  final drafts = ref.watch(pendingDraftCountProvider).asData?.value ?? 0;
  final unread =
      ref.watch(unreadNotificationCountProvider).asData?.value ?? 0;
  final displayCurrency = ref.watch(displayCurrencyProvider);

  return groupsAsync.when(
    loading: () => const AsyncValue.loading(),
    error: AsyncValue.error,
    data: (groups) {
      return archivedAsync.when(
        loading: () => const AsyncValue.loading(),
        error: AsyncValue.error,
        data: (archived) {
          final shared = groups.where((g) => !g.isPersonal).toList();
          final personal = groups.where((g) => g.isPersonal).toList();

          final balanceRows = <ProfileBalanceRow>[];
          for (final group in shared) {
            final member = ref
                .watch(myMemberInGroupProvider(group.id))
                .asData
                ?.value;
            final participantId = member?.participantId;
            if (participantId == null) continue;
            final balanceResult = ref
                .watch(groupBalanceProvider(group.id))
                .asData
                ?.value;
            if (balanceResult == null) continue;
            ParticipantBalance? mine;
            for (final b in balanceResult.balances) {
              if (b.participantId == participantId) {
                mine = b;
                break;
              }
            }
            if (mine == null || mine.balanceCents == 0) continue;
            balanceRows.add(
              ProfileBalanceRow(
                group: group,
                balanceCents: mine.balanceCents,
                currencyCode: mine.currencyCode,
              ),
            );
          }

          final personalBudgets = <ProfilePersonalBudgetRow>[];
          for (final group in personal) {
            final expenses =
                ref.watch(expensesByGroupProvider(group.id)).asData?.value;
            if (expenses == null) continue;
            final spent = expenses.fold<int>(
              0,
              (s, e) => s + contributionToExpenseTotal(e),
            );
            personalBudgets.add(
              ProfilePersonalBudgetRow(
                group: group,
                spentCents: spent,
                budgetCents: group.budgetAmountCents,
              ),
            );
          }

          ProfileGlobalNet? globalNet;
          if (displayCurrency.isNotEmpty && balanceRows.isNotEmpty) {
            var net = 0;
            var converted = 0;
            var skipped = 0;
            for (final row in balanceRows) {
              if (row.currencyCode == displayCurrency) {
                net += row.balanceCents;
                converted++;
                continue;
              }
              final rateKey = '${row.currencyCode}|$displayCurrency';
              final rate = ref
                  .watch(displayCurrencyRateProvider(rateKey))
                  .asData
                  ?.value;
              if (rate == null || rate == 0) {
                skipped++;
                continue;
              }
              net += AmountWithSecondaryDisplay.toDisplayCents(
                row.balanceCents,
                row.currencyCode,
                displayCurrency,
                rate,
              );
              converted++;
            }
            globalNet = ProfileGlobalNet(
              displayCurrencyCode: displayCurrency,
              netDisplayCents: net,
              convertedGroupCount: converted,
              skippedGroupCount: skipped,
              isPartial: skipped > 0,
            );
          }

          return AsyncValue.data(
            ProfileDashboardData(
              kpis: ProfileKpis(
                sharedGroups: shared.length,
                personalLists: personal.length,
                archived: archived.length,
                pendingDrafts: drafts,
                unreadNotifications: unread,
              ),
              balanceRows: balanceRows,
              personalBudgets: personalBudgets,
              groups: groups,
              globalNet: globalNet,
            ),
          );
        },
      );
    },
  );
});
