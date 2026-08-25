import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:safaeh/safaeh.dart';

export 'package:safaeh/safaeh.dart' show scrollToPageSection;

/// One jump target in a long scrolling page.
class PageSectionIndexEntry {
  const PageSectionIndexEntry({
    required this.id,
    required this.labelKey,
    required this.key,
    this.icon,
  });

  final String id;

  /// easy_localization key — translated inside the index so locale changes
  /// refresh labels without waiting for a parent [setState].
  final String labelKey;
  final GlobalKey key;
  final IconData? icon;
}

List<SafaehPageIndexEntry> _safaehEntries(List<PageSectionIndexEntry> entries) {
  return [
    for (final entry in entries)
      SafaehPageIndexEntry(
        id: entry.id,
        label: entry.labelKey.tr(),
        key: entry.key,
        icon: entry.icon,
      ),
  ];
}

void _forward(
  List<PageSectionIndexEntry> entries,
  SafaehPageIndexEntry selected,
  ValueChanged<PageSectionIndexEntry> onSelect,
) {
  for (final entry in entries) {
    if (entry.id == selected.id) {
      onSelect(entry);
      return;
    }
  }
}

/// GitBook-style "On this page" index for wide layouts (side rail).
class PageSectionIndex extends StatelessWidget {
  const PageSectionIndex({
    super.key,
    required this.entries,
    required this.activeId,
    required this.onSelect,
  });

  final List<PageSectionIndexEntry> entries;
  final String? activeId;
  final ValueChanged<PageSectionIndexEntry> onSelect;

  @override
  Widget build(BuildContext context) {
    context.locale;
    return SafaehPageIndex(
      title: 'page_index_title'.tr(),
      entries: _safaehEntries(entries),
      activeId: activeId,
      onSelect: (selected) => _forward(entries, selected, onSelect),
    );
  }
}

/// Floating overlay control for narrow layouts. Does not consume scroll space.
class PageSectionIndexOverlay extends StatelessWidget {
  const PageSectionIndexOverlay({
    super.key,
    required this.entries,
    required this.activeId,
    required this.onSelect,
  });

  final List<PageSectionIndexEntry> entries;
  final String? activeId;
  final ValueChanged<PageSectionIndexEntry> onSelect;

  @override
  Widget build(BuildContext context) {
    context.locale;
    return SafaehPageIndexOverlay(
      title: 'page_index_title'.tr(),
      entries: _safaehEntries(entries),
      activeId: activeId,
      onSelect: (selected) => _forward(entries, selected, onSelect),
    );
  }
}

/// Resolve the active section from scroll position (section tops vs viewport).
String? activePageSectionId({
  required List<PageSectionIndexEntry> entries,
  required BuildContext scrollContext,
  double activationOffset = 96,
}) {
  return safaehActivePageSectionId(
    sections: [for (final entry in entries) (entry.id, entry.key)],
    scrollContext: scrollContext,
    activationOffset: activationOffset,
  );
}
