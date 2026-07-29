import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../expenses/widgets/filtered_expenses_sheet.dart';
import '../providers/profile_my_expenses_provider.dart';

/// Profile-scoped expense row (my share) built on the shared [AppExpenseTile].
class ProfileExpenseTile extends StatelessWidget {
  const ProfileExpenseTile({
    super.key,
    required this.item,
    this.showManageMenu = false,
  });

  final ProfileExpenseItem item;
  final bool showManageMenu;

  @override
  Widget build(BuildContext context) {
    final paidLine = item.iPaid
        ? 'profile_expense_you_paid'.tr()
        : 'paid_by'.tr(namedArgs: {'name': item.payerName});

    return AppExpenseTile(
      row: FilteredExpenseRow(
        expense: item.expense,
        payerName: item.payerName,
        groupId: item.group.id,
        groupCurrencyCode: item.group.currencyCode,
        amountCentsOverride: item.myShareCents,
        detailLine:
            '${item.group.name} · ${'profile_your_share'.tr()} · $paidLine',
        showManageMenu: showManageMenu,
      ),
    );
  }
}
