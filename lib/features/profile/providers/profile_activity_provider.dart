import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart' show StateProvider;

import '../../../core/widgets/amount_with_secondary_display.dart';
import '../../../domain/domain.dart';
import '../../groups/providers/group_analytics_provider.dart';
import '../../settings/providers/display_currency_rate_provider.dart';
import 'package:hisab/core/settings/providers/settings_framework_providers.dart';
import 'profile_my_expenses_provider.dart';

export 'profile_my_expenses_provider.dart' show ProfileExpenseItem;

class ProfileTagSpend {
  const ProfileTagSpend({required this.tagKey, required this.amountCents});

  final String tagKey;
  final int amountCents;
}

class ProfileAnalytics {
  const ProfileAnalytics({
    required this.range,
    required this.mySpendCents,
    required this.transactionCount,
    required this.averagePerDayCents,
    required this.displayCurrencyCode,
    required this.isPartial,
    required this.byTag,
  });

  final AnalyticsRangePreset range;

  /// Net my-share spend in display currency (expenses − income shares).
  final int mySpendCents;
  final int transactionCount;
  final int averagePerDayCents;
  final String displayCurrencyCode;
  final bool isPartial;
  final List<ProfileTagSpend> byTag;
}

class ProfileActivityData {
  const ProfileActivityData({required this.expenses, required this.analytics});

  final List<ProfileExpenseItem> expenses;
  final ProfileAnalytics analytics;
}

final profileAnalyticsRangeProvider = StateProvider<AnalyticsRangePreset>(
  (ref) => AnalyticsRangePreset.days90,
);

final profileActivityProvider = Provider<AsyncValue<ProfileActivityData>>((
  ref,
) {
  final expensesAsync = ref.watch(profileMyExpensesProvider);
  final range = ref.watch(profileAnalyticsRangeProvider);
  final displayCurrency = ref.watch(displayCurrencyProvider);

  return expensesAsync.when(
    loading: () => const AsyncValue.loading(),
    error: AsyncValue.error,
    data: (items) {
      DateTime? earliest;
      DateTime? latest;
      for (final item in items) {
        final localDate = item.expense.date.isUtc
            ? item.expense.date.toLocal()
            : item.expense.date;
        earliest = earliest == null || localDate.isBefore(earliest)
            ? localDate
            : earliest;
        latest = latest == null || localDate.isAfter(latest)
            ? localDate
            : latest;
      }

      final activityEnd = latest ?? DateTime.now();
      final rangeStart = _rangeStart(range, activityEnd);
      final inRange = items.where((item) {
        final localDate = item.expense.date.isUtc
            ? item.expense.date.toLocal()
            : item.expense.date;
        if (rangeStart != null && localDate.isBefore(rangeStart)) return false;
        return true;
      }).toList();

      var anyMissingRate = false;
      var convertedSpend = 0;
      var daySpan = 1;
      final tagTotals = <String, int>{};
      String? fallbackSpendCurrency;

      for (final item in inRange) {
        final signed = item.expense.transactionType == TransactionType.income
            ? -item.myShareCents
            : item.myShareCents;
        final currency = item.group.currencyCode;
        final int displayCents;
        if (displayCurrency.isEmpty) {
          fallbackSpendCurrency ??= currency;
          if (currency != fallbackSpendCurrency) {
            anyMissingRate = true;
            continue;
          }
          displayCents = signed;
        } else if (currency != displayCurrency) {
          final rate = ref
              .watch(displayCurrencyRateProvider('$currency|$displayCurrency'))
              .asData
              ?.value;
          if (rate == null || rate == 0) {
            anyMissingRate = true;
            continue;
          }
          displayCents = AmountWithSecondaryDisplay.toDisplayCents(
            signed,
            currency,
            displayCurrency,
            rate,
          );
        } else {
          displayCents = signed;
        }
        convertedSpend += displayCents;
        final tag = item.expense.hasBlankTag ? 'untagged' : item.expense.tag!;
        tagTotals[tag] = (tagTotals[tag] ?? 0) + displayCents;
      }

      if (inRange.isNotEmpty) {
        final earliestDay = earliest ?? activityEnd;
        final start =
            rangeStart ??
            DateTime(earliestDay.year, earliestDay.month, earliestDay.day);
        final endDay = DateTime(
          activityEnd.year,
          activityEnd.month,
          activityEnd.day,
        );
        daySpan = endDay.difference(start).inDays + 1;
        if (daySpan < 1) daySpan = 1;
      }

      final byTag =
          tagTotals.entries
              .map((e) => ProfileTagSpend(tagKey: e.key, amountCents: e.value))
              .toList()
            ..sort((a, b) => b.amountCents.compareTo(a.amountCents));

      return AsyncValue.data(
        ProfileActivityData(
          expenses: inRange,
          analytics: ProfileAnalytics(
            range: range,
            mySpendCents: convertedSpend,
            transactionCount: inRange.length,
            averagePerDayCents: inRange.isEmpty
                ? 0
                : (convertedSpend / daySpan).round(),
            displayCurrencyCode: displayCurrency.isEmpty
                ? (fallbackSpendCurrency ??
                      (inRange.isEmpty
                          ? 'USD'
                          : inRange.first.group.currencyCode))
                : displayCurrency,
            isPartial: anyMissingRate,
            byTag: byTag,
          ),
        ),
      );
    },
  );
});

DateTime? _rangeStart(AnalyticsRangePreset range, DateTime activityEnd) {
  final end = DateTime(activityEnd.year, activityEnd.month, activityEnd.day);
  switch (range) {
    case AnalyticsRangePreset.days30:
      return end.subtract(const Duration(days: 29));
    case AnalyticsRangePreset.days90:
      return end.subtract(const Duration(days: 89));
    case AnalyticsRangePreset.all:
      return null;
  }
}
