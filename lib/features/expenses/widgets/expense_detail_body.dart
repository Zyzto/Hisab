import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import '../../../core/navigation/nav_back.dart';
import '../../../core/platform/ui_perf.dart';
import '../../../core/receipt/receipt_image_view.dart';
import '../../../core/theme/accent_style.dart';
import '../../../core/widgets/amount_with_secondary_display.dart';
import '../../../core/widgets/participant_avatar.dart';
import 'package:hisab/core/settings/providers/settings_framework_providers.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/expense_display_title.dart';
import '../../../core/widgets/missing_route_page.dart';
import '../../../core/widgets/user_text.dart';
import '../../../domain/domain.dart';
import '../../groups/providers/groups_provider.dart';
import '../category_icons.dart';

/// Body content for a single expense in the detail shell (no Scaffold).
class ExpenseDetailBody extends ConsumerWidget {
  final String groupId;
  final String expenseId;

  const ExpenseDetailBody({
    super.key,
    required this.groupId,
    required this.expenseId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Prefer the group list stream so PageView neighbors share one DB watch
    // instead of N× watchById polls (especially costly on web).
    final expensesAsync = ref.watch(expensesByGroupProvider(groupId));
    final AsyncValue<Expense?> expenseAsync;
    if (expensesAsync.hasValue) {
      final list = expensesAsync.requireValue;
      Expense? found;
      for (final e in list) {
        if (e.id == expenseId) {
          found = e;
          break;
        }
      }
      expenseAsync = AsyncValue.data(found);
    } else {
      expenseAsync = ref.watch(futureExpenseProvider(expenseId));
    }
    final participantsAsync = ref.watch(participantsByGroupProvider(groupId));
    final groupAsync = ref.watch(futureGroupProvider(groupId));
    final tagsAsync = ref.watch(tagsByGroupProvider(groupId));

    return expenseAsync.when(
      data: (expense) {
        if (expense == null || expense.groupId != groupId) {
          // In-stack (e.g. just deleted): pop back. Cold deep link: error → home.
          if (routerCanPop(context)) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!context.mounted || !routerCanPop(context)) return;
              if (GoRouter.maybeOf(context) != null) {
                context.pop();
              } else {
                Navigator.of(context).pop();
              }
            });
            return const SizedBox.shrink();
          }
          return const MissingRoutePage(
            titleKey: 'expense_not_found',
            messageKey: 'expense_not_found_message',
            asBody: true,
          );
        }
        return participantsAsync.when(
          data: (participants) {
            // Wait for group so personal lists don't briefly flash Paid By/Split.
            final group = groupAsync.asData?.value;
            if (group == null && groupAsync.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            final nameOf = {for (final p in participants) p.id: p.name};
            final avatarOf = {for (final p in participants) p.id: p.avatarId};
            final customTags = tagsAsync.asData?.value ?? const <ExpenseTag>[];
            final isPersonal = group?.isPersonal == true;
            final groupCurrencyCode = group?.currencyCode;
            final useGroupCurrency =
                groupCurrencyCode != null &&
                groupCurrencyCode.isNotEmpty &&
                expense.currencyCode != groupCurrencyCode;
            final totalCents = useGroupCurrency
                ? expense.effectiveBaseAmountCents
                : expense.amountCents;
            final displayCurrencyCode = useGroupCurrency
                ? groupCurrencyCode
                : expense.currencyCode;
            final isTransfer =
                expense.transactionType == TransactionType.transfer;
            // Personal lists are single-person: "who paid" / split of self is noise.
            final showPeopleSections = !isPersonal || isTransfer;
            final hasDescription =
                expense.description != null &&
                expense.description!.trim().isNotEmpty;
            final hasLineItems =
                expense.lineItems != null && expense.lineItems!.isNotEmpty;
            final shares = _participantShares(
              expense,
              participants,
              nameOf,
              avatarOf,
              useGroupCurrency ? groupCurrencyCode : null,
            );
            final showSplit =
                showPeopleSections &&
                shares.isNotEmpty &&
                (isTransfer ||
                    shares.length > 1 ||
                    shares.first.participantId != expense.payerParticipantId);
            final isSparse =
                !hasDescription && !hasLineItems && !showPeopleSections;

            final header = ExpenseDetailBodyHeader(
              expense: expense,
              use24HourFormat: ref.watch(use24HourFormatProvider),
              customTags: customTags,
              amountCents: totalCents,
              displayCurrencyCode: displayCurrencyCode,
              showOriginalCurrency: useGroupCurrency,
              fromName: nameOf[expense.payerParticipantId],
              toName: expense.toParticipantId == null
                  ? null
                  : nameOf[expense.toParticipantId!],
            );

            final children = <Widget>[
              header,
              if (hasDescription) ...[
                const SizedBox(height: 20),
                _DetailSection(
                  label: 'expense_description'.tr(),
                  child: UserText(
                    expense.description!.trim(),
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(height: 1.45),
                  ),
                ),
              ],
              if (hasLineItems) ...[
                const SizedBox(height: 16),
                _DetailSection(
                  label: 'bill_breakdown'.tr(),
                  child: Column(
                    children: [
                      for (var i = 0; i < expense.lineItems!.length; i++) ...[
                        if (i > 0)
                          Divider(
                            height: 20,
                            color: Theme.of(
                              context,
                            ).colorScheme.outlineVariant.withValues(alpha: 0.5),
                          ),
                        _LineItemRow(
                          description:
                              expense.lineItems![i].description.trim().isEmpty
                              ? 'item_description'.tr()
                              : expense.lineItems![i].description.trim(),
                          amountCents:
                              useGroupCurrency && expense.amountCents > 0
                              ? (expense.lineItems![i].amountCents *
                                        expense.effectiveBaseAmountCents /
                                        expense.amountCents)
                                    .round()
                              : expense.lineItems![i].amountCents,
                          currencyCode: displayCurrencyCode,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              if (showPeopleSections) ...[
                const SizedBox(height: 20),
                _SectionLabel(label: _payerSectionLabel(expense)),
                const SizedBox(height: 10),
                _PersonCard(
                  name:
                      nameOf[expense.payerParticipantId] ??
                      expense.payerParticipantId,
                  avatarId: avatarOf[expense.payerParticipantId],
                  emphasized: true,
                ),
                if (showSplit) ...[
                  const SizedBox(height: 20),
                  _SplitSectionHeader(
                    isTransfer: isTransfer,
                    splitType: expense.splitType,
                  ),
                  const SizedBox(height: 10),
                  ...shares.map(
                    (e) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _PersonCard(
                        name: e.name,
                        avatarId: e.avatarId,
                        subtitle: e.percentLabel,
                        amountCents: e.cents,
                        currencyCode: e.currencyCode,
                        amountWidget: AmountWithSecondaryDisplay(
                          amountCents: e.cents,
                          groupCurrencyCode: e.currencyCode,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
              const SizedBox(height: 12),
            ];

            if (isSparse) {
              // Center short personal details so the page doesn't feel empty.
              return LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight - 36,
                      ),
                      child: Center(child: header),
                    ),
                  );
                },
              );
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: children,
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => const Center(child: CircularProgressIndicator()),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => const Center(child: CircularProgressIndicator()),
    );
  }

  static String _payerSectionLabel(Expense expense) {
    switch (expense.transactionType) {
      case TransactionType.transfer:
        return 'from'.tr();
      case TransactionType.income:
        return 'received_by_label'.tr();
      case TransactionType.expense:
        return 'paid_by_label'.tr();
    }
  }

  static List<_ShareEntry> _participantShares(
    Expense expense,
    List<Participant> participants,
    Map<String, String> nameOf,
    Map<String, String?> avatarOf,
    String? groupCurrencyCode,
  ) {
    final useGroupCurrency =
        groupCurrencyCode != null &&
        groupCurrencyCode.isNotEmpty &&
        expense.currencyCode != groupCurrencyCode;
    final conversionFactor = useGroupCurrency && expense.amountCents > 0
        ? expense.effectiveBaseAmountCents / expense.amountCents
        : 1.0;
    final displayCode = useGroupCurrency
        ? groupCurrencyCode
        : expense.currencyCode;

    int toDisplayCents(int cents) {
      if (!useGroupCurrency) return cents;
      return (cents * conversionFactor).round();
    }

    if (expense.transactionType == TransactionType.transfer) {
      final toId = expense.toParticipantId;
      if (toId == null) return [];
      return [
        _ShareEntry(
          participantId: toId,
          name: nameOf[toId] ?? toId,
          avatarId: avatarOf[toId],
          cents: toDisplayCents(expense.amountCents),
          currencyCode: displayCode,
          percentLabel: null,
        ),
      ];
    }
    final shares = expense.splitShares;
    if (shares.isEmpty) return [];
    final included = participants
        .where((p) => shares.containsKey(p.id) && (shares[p.id] ?? 0) > 0)
        .toList();
    // Percent of what's shown (ignore orphan share keys for removed members).
    final totalShareCents = included.fold<int>(
      0,
      (sum, p) => sum + (shares[p.id] ?? 0),
    );
    return included.map((p) {
      final cents = shares[p.id]!;
      final percent = totalShareCents > 0
          ? ((cents * 100) / totalShareCents).round()
          : null;
      return _ShareEntry(
        participantId: p.id,
        name: nameOf[p.id] ?? p.id,
        avatarId: avatarOf[p.id] ?? p.avatarId,
        cents: toDisplayCents(cents),
        currencyCode: displayCode,
        percentLabel: percent != null ? '$percent%' : null,
      );
    }).toList();
  }
}

class _ShareEntry {
  final String participantId;
  final String name;
  final String? avatarId;
  final int cents;
  final String currencyCode;
  final String? percentLabel;
  _ShareEntry({
    required this.participantId,
    required this.name,
    this.avatarId,
    required this.cents,
    required this.currencyCode,
    required this.percentLabel,
  });
}

class ExpenseDetailBodyHeader extends StatelessWidget {
  final Expense expense;
  final bool use24HourFormat;
  final List<ExpenseTag> customTags;
  final int? amountCents;
  final String? displayCurrencyCode;
  final bool showOriginalCurrency;
  final String? fromName;
  final String? toName;

  const ExpenseDetailBodyHeader({
    super.key,
    required this.expense,
    this.use24HourFormat = false,
    this.customTags = const [],
    this.amountCents,
    this.displayCurrencyCode,
    this.showOriginalCurrency = false,
    this.fromName,
    this.toName,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final accent = _accentForType(colorScheme, expense.transactionType);
    final icon = iconForExpenseTag(expense.tag, customTags);
    final categoryLabel = _categoryLabel(expense.tag, customTags);
    final typeLabel = _typeLabel(expense.transactionType);
    final subtle = context.subtleAccents;
    // Blend against the hero panel so chip contrast matches what the eye sees.
    final headerSurface = subtle
        ? colorScheme.surfaceContainerLow
        : Color.alphaBlend(
            accent.container.withValues(alpha: 0.55),
            colorScheme.surface,
          );
    final tagChrome = chromeForExpenseTag(
      expense.tag,
      brightness: theme.brightness,
      surface: headerSurface,
      customTags: customTags,
    );
    final dateFormat = use24HourFormat
        ? DateFormat('EEE, MMM d, yyyy').add_Hm()
        : DateFormat('EEE, MMM d, yyyy').add_jm();
    // Display in device timezone: stored date is UTC, convert for display.
    final localDate = expense.date.isUtc
        ? expense.date.toLocal()
        : expense.date;
    final cents = amountCents ?? expense.amountCents;
    final currency = displayCurrencyCode ?? expense.currencyCode;
    final imageUrls = expense.effectiveImageUrls;
    final typeChipBg = Color.alphaBlend(
      accent.color.withValues(alpha: subtle ? 0.08 : 0.14),
      colorScheme.surface,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: AccentSurfaces.panel(
        colorScheme,
        subtle: subtle,
        accentContainer: accent.container,
        accentBorder: accent.color,
        radius: 20,
      ),
      // Side-spread: title + meta on start, amount on end (list-tile rhythm).
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (categoryLabel != null) ...[
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: tagChrome.container,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: tagChrome.accent.withValues(alpha: 0.35),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Icon(icon, size: 24, color: tagChrome.onContainer),
                    ),
                    const SizedBox(height: 6),
                    _MetaChip(
                      label: categoryLabel,
                      background: tagChrome.container,
                      foreground: tagChrome.onContainer,
                      borderColor: tagChrome.accent,
                      compact: true,
                    ),
                  ],
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    UserText(
                      expenseDisplayTitle(
                        expense,
                        fromName: fromName,
                        toName: toName,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                        letterSpacing: -0.3,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      dateFormat.format(localDate),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (typeLabel != null) ...[
                      const SizedBox(height: 8),
                      _MetaChip(
                        label: typeLabel,
                        background: typeChipBg,
                        foreground: readableOnBackground(
                          accent.color,
                          typeChipBg,
                        ),
                        borderColor: accent.color,
                        compact: true,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  AmountWithSecondaryDisplay(
                    amountCents: cents,
                    groupCurrencyCode: currency,
                    primaryStyle: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                      color: colorScheme.onSurface,
                    ),
                    secondaryStyle: theme.textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                    secondaryOnSameRow: false,
                  ),
                  if (showOriginalCurrency &&
                      expense.currencyCode != currency) ...[
                    const SizedBox(height: 2),
                    Text(
                      CurrencyFormatter.formatCents(
                        expense.amountCents,
                        expense.currencyCode,
                      ),
                      textDirection: TextDirection.ltr,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          if (imageUrls.isNotEmpty) ...[
            const SizedBox(height: 12),
            _ReceiptThumbnailStrip(urls: imageUrls),
          ],
        ],
      ),
    );
  }

  static ({Color color, Color container}) _accentForType(
    ColorScheme scheme,
    TransactionType type,
  ) {
    switch (type) {
      case TransactionType.income:
        return (color: scheme.tertiary, container: scheme.tertiaryContainer);
      case TransactionType.transfer:
        return (color: scheme.secondary, container: scheme.secondaryContainer);
      case TransactionType.expense:
        return (color: scheme.primary, container: scheme.primaryContainer);
    }
  }

  static String? _categoryLabel(String? tagId, List<ExpenseTag> customTags) {
    if (tagId == null || tagId.isEmpty) return null;
    for (final preset in presetCategoryTags) {
      if (preset.id == tagId) return 'category_${preset.id}'.tr();
    }
    final custom = customTags.where((t) => t.id == tagId).firstOrNull;
    return custom?.label ?? tagId;
  }

  static String? _typeLabel(TransactionType type) {
    switch (type) {
      case TransactionType.expense:
        // Default type — avoid cluttering every detail with "Expenses".
        return null;
      case TransactionType.income:
        return 'income'.tr();
      case TransactionType.transfer:
        return 'transfer'.tr();
    }
  }
}

/// Compact receipt strip shown in the expense header card.
class _ReceiptThumbnailStrip extends StatelessWidget {
  final List<String> urls;

  const _ReceiptThumbnailStrip({required this.urls});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Claim horizontal drags (including at scroll edges) so the expense-detail
    // page swipe does not steal gestures from the photo strip.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragUpdate: (_) {},
      onHorizontalDragEnd: (_) {},
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var i = 0; i < urls.length; i++)
              Padding(
                padding: EdgeInsetsDirectional.only(
                  end: i == urls.length - 1 ? 0 : 8,
                ),
                child: GestureDetector(
                  onTap: () => showExpenseImageFullScreen(context, urls[i]),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant.withValues(
                          alpha: 0.55,
                        ),
                      ),
                      boxShadow: UiPerf.preferCheapShadows
                          ? null
                          : [
                              BoxShadow(
                                color: theme.colorScheme.shadow.withValues(
                                  alpha: 0.08,
                                ),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                    ),
                    child: buildExpenseImageView(
                      context,
                      urls[i],
                      width: 92,
                      maxHeight: 92,
                      padding: EdgeInsets.zero,
                      borderRadius: BorderRadius.circular(12),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SplitSectionHeader extends StatelessWidget {
  final bool isTransfer;
  final SplitType splitType;

  const _SplitSectionHeader({
    required this.isTransfer,
    required this.splitType,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = isTransfer ? 'to'.tr() : 'split'.tr();
    final typeLabel = isTransfer ? null : _splitTypeLabel(splitType);
    return Row(
      children: [
        Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurface,
          ),
        ),
        if (typeLabel != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: theme.colorScheme.secondaryContainer.withValues(
                alpha: 0.65,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              typeLabel,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSecondaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ],
    );
  }

  static String _splitTypeLabel(SplitType type) {
    switch (type) {
      case SplitType.equal:
        return 'equal'.tr();
      case SplitType.parts:
        return 'parts'.tr();
      case SplitType.amounts:
        return 'amounts'.tr();
    }
  }
}

class _MetaChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color background;
  final Color foreground;
  final Color borderColor;
  final bool compact;

  const _MetaChip({
    required this.label,
    required this.background,
    required this.foreground,
    required this.borderColor,
    this.icon,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 5 : 7,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: compact ? 14 : 15, color: foreground),
            SizedBox(width: compact ? 5 : 6),
          ],
          UserText(
            label,
            style:
                (compact
                        ? theme.textTheme.labelMedium
                        : theme.textTheme.labelLarge)
                    ?.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                    ),
          ),
        ],
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  final String label;
  final Widget child;

  const _DetailSection({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel(label: label),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _LineItemRow extends StatelessWidget {
  final String description;
  final int amountCents;
  final String currencyCode;

  const _LineItemRow({
    required this.description,
    required this.amountCents,
    required this.currencyCode,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: UserText(description, style: theme.textTheme.bodyMedium),
        ),
        const SizedBox(width: 12),
        Text(
          CurrencyFormatter.formatCents(amountCents, currencyCode),
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;

  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(
            color: AccentSurfaces.sectionBar(
              theme.colorScheme,
              subtle: context.subtleAccents,
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}

class _PersonCard extends StatelessWidget {
  final String name;
  final String? avatarId;
  final String? subtitle;
  final int? amountCents;
  final String? currencyCode;
  final bool emphasized;

  /// When set, shown instead of the default formatted amount (e.g. [AmountWithSecondaryDisplay]).
  final Widget? amountWidget;

  const _PersonCard({
    required this.name,
    this.avatarId,
    this.subtitle,
    this.amountCents,
    this.currencyCode,
    this.amountWidget,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final trailing =
        amountWidget ??
        (amountCents != null && currencyCode != null
            ? Text(
                CurrencyFormatter.formatCents(amountCents!, currencyCode!),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.primary,
                ),
              )
            : null);

    final subtle = context.subtleAccents;
    final showAccent = emphasized && !subtle;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: showAccent
            ? AccentSurfaces.emphasizedFill(colorScheme, subtle: false)
            : colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: showAccent
              ? AccentSurfaces.emphasizedBorder(colorScheme, subtle: false)
              : colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Row(
        children: [
          ParticipantAvatar(
            name: name,
            avatarId: avatarId,
            backgroundColor: showAccent
                ? colorScheme.primary.withValues(alpha: 0.16)
                : colorScheme.secondaryContainer.withValues(alpha: 0.7),
            foregroundColor: showAccent
                ? colorScheme.primary
                : colorScheme.onSecondaryContainer,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                UserText(
                  name,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withValues(
                        alpha: 0.8,
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      subtitle!,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
