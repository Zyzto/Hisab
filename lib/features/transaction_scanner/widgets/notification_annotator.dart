import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../core/utils/user_text.dart';
import '../domain/field_span.dart';
import '../services/transaction_parser.dart';

Color fieldRoleColor(FieldRole role, ColorScheme cs) {
  switch (role) {
    case FieldRole.amount:
      return const Color(0xFF2EAD5B);
    case FieldRole.currency:
      return const Color(0xFF0D9488);
    case FieldRole.merchant:
      return const Color(0xFFEA580C);
    case FieldRole.place:
      return const Color(0xFF2563EB);
    case FieldRole.date:
      return const Color(0xFF7C3AED);
    case FieldRole.card:
      return const Color(0xFF64748B);
    case FieldRole.ignore:
      return cs.outline;
  }
}

String fieldRoleLabelKey(FieldRole role) {
  switch (role) {
    case FieldRole.amount:
      return 'scanner_role_amount';
    case FieldRole.currency:
      return 'scanner_role_currency';
    case FieldRole.merchant:
      return 'scanner_role_merchant';
    case FieldRole.place:
      return 'scanner_role_place';
    case FieldRole.date:
      return 'scanner_role_date';
    case FieldRole.card:
      return 'scanner_role_card';
    case FieldRole.ignore:
      return 'scanner_role_ignore';
  }
}

/// Tappable notification body with color-coded field spans.
class NotificationAnnotator extends StatelessWidget {
  final String title;
  final String body;
  final List<FieldSpan> spans;
  final ValueChanged<List<FieldSpan>> onSpansChanged;

  const NotificationAnnotator({
    super.key,
    required this.title,
    required this.body,
    required this.spans,
    required this.onSpansChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.notifications_outlined, color: cs.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _AnnotatedBody(
              body: body,
              spans: spans,
              onTapToken: (start, end) => _pickRole(context, start, end),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: FieldRole.values
                  .where((r) => r != FieldRole.ignore)
                  .map((role) {
                    return Chip(
                      visualDensity: VisualDensity.compact,
                      avatar: CircleAvatar(
                        backgroundColor: fieldRoleColor(role, cs),
                        radius: 6,
                      ),
                      label: Text(fieldRoleLabelKey(role).tr()),
                    );
                  })
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickRole(BuildContext context, int start, int end) async {
    final existing = spans
        .where((s) => s.start < end && s.end > start)
        .firstOrNull;
    final role = await showModalBottomSheet<FieldRole>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'scanner_assign_field'.tr(),
                  style: Theme.of(ctx).textTheme.titleMedium,
                ),
              ),
              ...FieldRole.values.map((r) {
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: fieldRoleColor(
                      r,
                      Theme.of(ctx).colorScheme,
                    ),
                    radius: 8,
                  ),
                  title: Text(fieldRoleLabelKey(r).tr()),
                  selected: existing?.role == r,
                  onTap: () => Navigator.pop(ctx, r),
                );
              }),
            ],
          ),
        );
      },
    );
    if (role == null) return;
    final next = [
      ...spans.where((s) => !(s.start < end && s.end > start)),
      if (role != FieldRole.ignore)
        FieldSpan(role: role, start: start, end: end),
    ];
    onSpansChanged(next);
  }
}

class _AnnotatedBody extends StatelessWidget {
  final String body;
  final List<FieldSpan> spans;
  final void Function(int start, int end) onTapToken;

  const _AnnotatedBody({
    required this.body,
    required this.spans,
    required this.onTapToken,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tokens = RegExp(r'\S+').allMatches(body).toList();
    final children = <InlineSpan>[];
    var cursor = 0;
    for (final token in tokens) {
      if (token.start > cursor) {
        children.add(TextSpan(text: body.substring(cursor, token.start)));
      }
      final covering = spans
          .where((s) => s.start < token.end && s.end > token.start)
          .firstOrNull;
      children.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: GestureDetector(
            onTap: () => onTapToken(token.start, token.end),
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 1),
              padding: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: covering == null
                    ? null
                    : fieldRoleColor(covering.role, cs).withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(token.group(0)!, style: theme.textTheme.bodyMedium),
            ),
          ),
        ),
      );
      cursor = token.end;
    }
    if (cursor < body.length) {
      children.add(TextSpan(text: body.substring(cursor)));
    }

    return Text.rich(
      TextSpan(children: children),
      textDirection: resolveUserTextDirection(body),
    );
  }
}

/// Apply labeled spans back onto extracted field values.
({
  int? amountCents,
  String? currency,
  String? merchant,
  String? place,
  String? card,
})
valuesFromSpans(String body, List<FieldSpan> spans) {
  String? textFor(FieldRole role) {
    final span = spans.where((s) => s.role == role).firstOrNull;
    if (span == null) return null;
    if (span.start < 0 || span.end > body.length || span.end <= span.start) {
      return null;
    }
    return body.substring(span.start, span.end).trim();
  }

  final amountRaw = textFor(FieldRole.amount);
  final currencyRaw = textFor(FieldRole.currency);
  return (
    amountCents: amountRaw == null
        ? null
        : TransactionParser.parseAmountToCents(amountRaw),
    currency: currencyRaw == null
        ? null
        : TransactionParser.extractCurrencyCode(currencyRaw) ??
              (RegExp(r'^[A-Za-z]{3}$').hasMatch(currencyRaw)
                  ? currencyRaw.toUpperCase()
                  : currencyRaw),
    merchant: textFor(FieldRole.merchant),
    place: textFor(FieldRole.place),
    card: textFor(FieldRole.card),
  );
}
