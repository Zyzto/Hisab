import 'package:flutter_logging_service/flutter_logging_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/settle_up_service.dart';
import '../../../core/utils/expense_totals.dart';
import '../../../core/widgets/amount_with_secondary_display.dart';
import '../../../domain/domain.dart';
import '../../settings/providers/display_currency_rate_provider.dart';
import '../../settings/providers/settings_framework_providers.dart';
import 'profile_data_providers.dart';

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

List<ParticipantBalance> _balancesForGroup(
  Group group,
  List<Participant> participants,
  List<Expense> expenses,
) {
  final snapshotJson = group.settlementSnapshotJson;
  final isArchiveAutoFreeze =
      group.isSettlementFrozen &&
      snapshotJson == archiveAutoFreezeSnapshotMarker;

  if (group.isSettlementFrozen &&
      snapshotJson != null &&
      snapshotJson.isNotEmpty &&
      !isArchiveAutoFreeze) {
    try {
      return SettlementSnapshot.fromJsonString(snapshotJson).balances;
    } catch (e) {
      Log.warning(
        'Profile dashboard: snapshot parse failed; omitting live fallback',
        error: e,
      );
      // Keep frozen numbers stable: zeros so the row is skipped (no shifting live net).
      return [
        for (final p in participants)
          ParticipantBalance(
            participantId: p.id,
            balanceCents: 0,
            currencyCode: group.currencyCode,
          ),
      ];
    }
  }
  if (group.isSettlementFrozen &&
      (snapshotJson == null || snapshotJson.isEmpty)) {
    return [
      for (final p in participants)
        ParticipantBalance(
          participantId: p.id,
          balanceCents: 0,
          currencyCode: group.currencyCode,
        ),
    ];
  }
  return computeBalances(participants, expenses, group.currencyCode);
}

ProfileDashboardData _buildDashboard(
  ProfileDataSnapshot snap, {
  required String displayCurrency,
  required Map<String, double?> ratesByPair,
}) {
  final shared = snap.groups.where((g) => !g.isPersonal).toList();
  final personal = snap.groups.where((g) => g.isPersonal).toList();

  final balanceRows = <ProfileBalanceRow>[];
  for (final group in shared) {
    final participantId = snap.myParticipantIdByGroupId[group.id];
    if (participantId == null) continue;
    final participants =
        snap.activeParticipantsByGroupId[group.id] ?? const <Participant>[];
    final expenses = snap.expensesByGroupId[group.id] ?? const <Expense>[];
    final balances = _balancesForGroup(group, participants, expenses);
    ParticipantBalance? mine;
    for (final b in balances) {
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
    final expenses = snap.expensesByGroupId[group.id] ?? const <Expense>[];
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
      final rate = ratesByPair['${row.currencyCode}|$displayCurrency'];
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

  return ProfileDashboardData(
    kpis: ProfileKpis(
      sharedGroups: shared.length,
      personalLists: personal.length,
      archived: snap.archived.length,
      pendingDrafts: snap.pendingDrafts,
      unreadNotifications: snap.unreadNotifications,
    ),
    balanceRows: balanceRows,
    personalBudgets: personalBudgets,
    groups: snap.groups,
    globalNet: globalNet,
  );
}

final profileDashboardProvider = Provider<AsyncValue<ProfileDashboardData>>((
  ref,
) {
  final snapAsync = ref.watch(profileDataSnapshotProvider);
  final displayCurrency = ref.watch(displayCurrencyProvider);

  return snapAsync.when(
    loading: () => const AsyncValue.loading(),
    error: AsyncValue.error,
    data: (snap) {
      final withoutRates = _buildDashboard(
        snap,
        displayCurrency: displayCurrency,
        ratesByPair: const {},
      );
      final rates = <String, double?>{};
      if (displayCurrency.isNotEmpty) {
        for (final row in withoutRates.balanceRows) {
          if (row.currencyCode == displayCurrency) continue;
          final key = '${row.currencyCode}|$displayCurrency';
          rates[key] = ref
              .watch(displayCurrencyRateProvider(key))
              .asData
              ?.value;
        }
      }
      return AsyncValue.data(
        rates.isEmpty
            ? withoutRates
            : _buildDashboard(
                snap,
                displayCurrency: displayCurrency,
                ratesByPair: rates,
              ),
      );
    },
  );
});
