import 'package:flutter/material.dart';

import '../theme/accent_style.dart';
import 'group_section_header.dart';
import 'user_text.dart';

/// A tappable section header that expands/collapses to show [child].
/// Used to indicate "there's something here" for optional or secondary content.
class ExpandableSection extends StatefulWidget {
  final String title;
  final String? trailingSummary;
  final bool initiallyExpanded;
  final Widget child;

  const ExpandableSection({
    super.key,
    required this.title,
    this.trailingSummary,
    required this.initiallyExpanded,
    required this.child,
  });

  @override
  State<ExpandableSection> createState() => _ExpandableSectionState();
}

class _ExpandableSectionState extends State<ExpandableSection> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  @override
  void didUpdateWidget(ExpandableSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initiallyExpanded != widget.initiallyExpanded &&
        _expanded == oldWidget.initiallyExpanded) {
      _expanded = widget.initiallyExpanded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final summary = widget.trailingSummary;
    final semanticsLabel = summary != null && summary.isNotEmpty
        ? '${widget.title}, $summary'
        : widget.title;

    return Container(
      width: double.infinity,
      decoration: AccentSurfaces.flatPanel(colorScheme),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            label: semanticsLabel,
            button: true,
            expanded: _expanded,
            child: InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 14,
                ),
                child: GroupSectionHeader(
                  label: widget.title,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (summary != null && summary.isNotEmpty) ...[
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 160),
                          child: UserText(
                            summary,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Icon(
                        _expanded ? Icons.expand_less : Icons.expand_more,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_expanded) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: widget.child,
            ),
          ],
        ],
      ),
    );
  }
}
