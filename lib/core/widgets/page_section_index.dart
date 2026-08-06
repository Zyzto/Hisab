import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// One jump target in a long scrolling page.
class PageSectionIndexEntry {
  const PageSectionIndexEntry({
    required this.id,
    required this.label,
    required this.key,
    this.icon,
  });

  final String id;
  final String label;
  final GlobalKey key;
  final IconData? icon;
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
    if (entries.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Align(
      alignment: Alignment.topCenter,
      child: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.fromSTEB(12, 20, 16, 16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 220),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'page_index_title'.tr().toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 10),
              for (final entry in entries)
                _IndexLink(
                  entry: entry,
                  selected: entry.id == activeId,
                  onTap: () => onSelect(entry),
                  dense: false,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Floating overlay control for narrow layouts. Does not consume scroll space.
///
/// Place inside a [Stack]. Tap expands the index panel directly above the pill.
class PageSectionIndexOverlay extends StatefulWidget {
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
  State<PageSectionIndexOverlay> createState() =>
      _PageSectionIndexOverlayState();
}

class _PageSectionIndexOverlayState extends State<PageSectionIndexOverlay>
    with SingleTickerProviderStateMixin {
  bool _open = false;
  late final AnimationController _anim;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(_fade);
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  void _setOpen(bool open) {
    if (open) {
      if (_open && _anim.status == AnimationStatus.completed) return;
      setState(() => _open = true);
      _anim.forward();
      return;
    }
    if (!_open && _anim.isDismissed) return;
    _anim.reverse().whenComplete(() {
      if (mounted) setState(() => _open = false);
    });
    // Keep [_open] true until reverse finishes so the close icon stays.
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (widget.entries.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final showPanel = _open || _anim.status == AnimationStatus.reverse;
    PageSectionIndexEntry? active;
    for (final entry in widget.entries) {
      if (entry.id == widget.activeId) {
        active = entry;
        break;
      }
    }
    active ??= widget.entries.first;

    // Must expand to fill the parent [Stack]; otherwise the dismiss layer only
    // covers the pill itself and taps "outside" still hit the page underneath.
    return SizedBox.expand(
      child: Stack(
        children: [
          if (showPanel)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _setOpen(false),
                child: const ColoredBox(color: Color(0x00000000)),
              ),
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsetsDirectional.only(end: 16, bottom: 16),
              child: Align(
                alignment: AlignmentDirectional.bottomEnd,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (showPanel) ...[
                      FadeTransition(
                        opacity: _fade,
                        child: SlideTransition(
                          position: _slide,
                          child: IgnorePointer(
                            ignoring: _anim.status == AnimationStatus.reverse,
                            child: _PopoverPanel(
                              entries: widget.entries,
                              activeId: widget.activeId,
                              onSelect: (entry) {
                                _setOpen(false);
                                widget.onSelect(entry);
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    Material(
                      elevation: showPanel ? 6 : 4,
                      shadowColor: cs.shadow.withValues(alpha: 0.28),
                      color: cs.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(28),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(28),
                        onTap: () => _setOpen(!showPanel),
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 220),
                          padding: const EdgeInsetsDirectional.fromSTEB(
                            12,
                            10,
                            14,
                            10,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color: cs.outlineVariant.withValues(alpha: 0.55),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: cs.primaryContainer,
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: Icon(
                                  showPanel
                                      ? Icons.close_rounded
                                      : Icons.list_alt_rounded,
                                  size: 18,
                                  color: cs.onPrimaryContainer,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Flexible(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'page_index_title'.tr(),
                                      style: theme.textTheme.labelMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                    Text(
                                      active.label,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: cs.onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PopoverPanel extends StatelessWidget {
  const _PopoverPanel({
    required this.entries,
    required this.activeId,
    required this.onSelect,
  });

  final List<PageSectionIndexEntry> entries;
  final String? activeId;
  final ValueChanged<PageSectionIndexEntry> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final maxH = MediaQuery.sizeOf(context).height * 0.45;

    return Material(
      elevation: 8,
      shadowColor: cs.shadow.withValues(alpha: 0.3),
      color: cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(16),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 260, maxHeight: maxH),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
                    child: Text(
                      'page_index_title'.tr().toUpperCase(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.7,
                      ),
                    ),
                  ),
                  for (final entry in entries)
                    _IndexLink(
                      entry: entry,
                      selected: entry.id == activeId,
                      onTap: () => onSelect(entry),
                      dense: true,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _IndexLink extends StatelessWidget {
  const _IndexLink({
    required this.entry,
    required this.selected,
    required this.onTap,
    required this.dense,
  });

  final PageSectionIndexEntry entry;
  final bool selected;
  final VoidCallback onTap;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: dense ? 1 : 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: dense ? 8 : 10,
              vertical: dense ? 10 : 7,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border(
                left: BorderSide(
                  width: 2.5,
                  color: selected ? cs.primary : Colors.transparent,
                ),
              ),
              color: selected
                  ? cs.primaryContainer.withValues(alpha: 0.45)
                  : null,
            ),
            child: Row(
              children: [
                if (entry.icon != null) ...[
                  Icon(
                    entry.icon,
                    size: 16,
                    color: selected ? cs.primary : cs.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    entry.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: selected ? cs.primary : cs.onSurface,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      height: 1.25,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Scroll helper: jump to a section key inside a scrollable ancestor.
///
/// [ListView] disposes off-screen children, so [key.currentContext] is often
/// null for sections above/below the cache window. Pass [controller] so we can
/// reposition (via [jumpTo], not animated probes) until the target builds, then
/// run a single [Scrollable.ensureVisible] animation.
///
/// Optional [knownOffset] (scroll pixels of the section top) skips probing.
Future<void> scrollToPageSection(
  GlobalKey key, {
  double alignment = 0.08,
  ScrollController? controller,
  double? knownOffset,
  Duration ensureDuration = const Duration(milliseconds: 280),
}) async {
  Future<bool> ensure() async {
    final ctx = key.currentContext;
    if (ctx == null) return false;
    await Scrollable.ensureVisible(
      ctx,
      duration: ensureDuration,
      curve: Curves.easeOutCubic,
      alignment: alignment,
    );
    return true;
  }

  // Already in the tree — one smooth ensureVisible, no probing.
  if (await ensure()) return;

  final c = controller;
  if (c == null || !c.hasClients) return;

  final max = c.position.maxScrollExtent;

  void jump(double offset) {
    c.jumpTo(offset.clamp(0.0, max));
  }

  // Instant reposition (no animateTo chain — that caused visible flicker).
  if (knownOffset != null) {
    jump(knownOffset);
  } else {
    for (final frac in const [0.0, 0.3, 0.6, 1.0]) {
      jump(max * frac);
      await WidgetsBinding.instance.endOfFrame;
      if (key.currentContext != null) break;
    }
  }

  await WidgetsBinding.instance.endOfFrame;
  if (await ensure()) return;

  // Stale offset / still not built: one more quiet scan, then ensure.
  for (final frac in const [0.0, 0.2, 0.4, 0.6, 0.8, 1.0]) {
    jump(max * frac);
    await WidgetsBinding.instance.endOfFrame;
    if (key.currentContext != null) {
      await ensure();
      return;
    }
  }
}

/// Resolve the active section from scroll position (section tops vs viewport).
String? activePageSectionId({
  required List<PageSectionIndexEntry> entries,
  required BuildContext scrollContext,
  double activationOffset = 96,
}) {
  if (entries.isEmpty) return null;
  final scrollBox = scrollContext.findRenderObject();
  if (scrollBox is! RenderBox || !scrollBox.hasSize) {
    return entries.first.id;
  }

  final viewportTop = scrollBox.localToGlobal(Offset.zero).dy;
  String? active = entries.first.id;
  for (final entry in entries) {
    final ctx = entry.key.currentContext;
    if (ctx == null) continue;
    final box = ctx.findRenderObject();
    if (box is! RenderBox || !box.hasSize) continue;
    final sectionTop = box.localToGlobal(Offset.zero).dy;
    if (sectionTop - viewportTop <= activationOffset) {
      active = entry.id;
    }
  }
  return active;
}
