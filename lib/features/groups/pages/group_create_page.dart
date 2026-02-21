import 'package:currency_picker/currency_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_logging_service/flutter_logging_service.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../core/repository/repository_providers.dart';
import '../../../core/navigation/route_paths.dart';
import '../../../core/telemetry/telemetry_service.dart';
import '../../../core/widgets/toast.dart';
import '../../../core/theme/theme_config.dart';
import '../../../core/utils/currency_helpers.dart';
import '../../settings/providers/settings_framework_providers.dart';
import '../utils/group_icon_utils.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Wizard entry point (keeps the same class name for router compatibility)
// ─────────────────────────────────────────────────────────────────────────────

class GroupCreatePage extends ConsumerStatefulWidget {
  const GroupCreatePage({super.key});

  @override
  ConsumerState<GroupCreatePage> createState() => _GroupCreatePageState();
}

class _GroupCreatePageState extends ConsumerState<GroupCreatePage> {
  static const _pageCount = 4;

  late final PageController _pageController;
  int _currentPage = 0;

  // ── Step 1 state ──
  final _nameFormKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  late Currency _selectedCurrency;

  // ── Step 2 state ──
  final _participantController = TextEditingController();
  final _participantFocusNode = FocusNode();
  final List<String> _participants = [];

  // ── Step 3 state ──
  String? _selectedIcon;
  Color _selectedColor = groupColors.first;

  // ── Step 4 state ──
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _selectedCurrency = CurrencyHelpers.defaultCurrency();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _participantController.dispose();
    _participantFocusNode.dispose();
    super.dispose();
  }

  // ── Navigation ──────────────────────────────────────────────────────────

  void _goNext() {
    // Validate before advancing from step 1
    if (_currentPage == 0 && !_nameFormKey.currentState!.validate()) return;
    if (_currentPage < _pageCount - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _goBack() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      context.pop();
    }
  }

  // ── Participant helpers ─────────────────────────────────────────────────

  void _addParticipant() {
    final name = _participantController.text.trim();
    if (name.isEmpty) return;
    setState(() {
      _participants.add(name);
      _participantController.clear();
    });
    _participantFocusNode.requestFocus();
  }

  void _removeParticipant(int index) {
    setState(() => _participants.removeAt(index));
  }

  // ── Create ──────────────────────────────────────────────────────────────

  Future<void> _createGroup() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final name = _nameController.text.trim();
      final currencyCode = _selectedCurrency.code;
      final repo = ref.read(groupRepositoryProvider);
      final id = await repo.create(
        name,
        currencyCode,
        icon: _selectedIcon,
        color: _selectedColor.toARGB32(),
        initialParticipants: _participants,
      );
      Log.info(
        'Group created via wizard: id=$id name="$name" currency=$currencyCode participants=${_participants.length}',
      );
      try {
        TelemetryService.sendEvent('group_created', {
          'groupId': id,
          'currencyCode': currencyCode,
          'participantCount': _participants.length,
          'hasIcon': _selectedIcon != null,
        }, enabled: ref.read(telemetryEnabledProvider));
      } catch (_) {}
      if (mounted) context.go(RoutePaths.groupDetail(id));
    } catch (e, st) {
      Log.warning('Group create failed', error: e, stackTrace: st);
      if (mounted) {
        context.showError('create_group_failed'.tr());
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('create_group'.tr()),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _goBack,
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _currentPage = i),
                children: [
                  _buildStep1NameCurrency(context),
                  _buildStep2Participants(context),
                  _buildStep3IconColor(context),
                  _buildStep4Summary(context),
                ],
              ),
            ),
            _buildPageIndicator(context),
            _buildBottomBar(context, colorScheme),
          ],
        ),
      ),
    );
  }

  // ── Page indicator ──────────────────────────────────────────────────────

  Widget _buildPageIndicator(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: ThemeConfig.spacingS),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(_pageCount, (index) {
          final isActive = index == _currentPage;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: isActive ? 24 : 8,
            height: 8,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: isActive
                  ? colorScheme.primary
                  : colorScheme.outline.withValues(alpha: 0.4),
            ),
          );
        }),
      ),
    );
  }

  // ── Bottom navigation bar ───────────────────────────────────────────────

  Widget _buildBottomBar(BuildContext context, ColorScheme colorScheme) {
    final isLastPage = _currentPage == _pageCount - 1;
    return Container(
      padding: const EdgeInsets.all(ThemeConfig.spacingM),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Back button
          Expanded(
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: _goBack,
                icon: const Icon(Icons.arrow_back),
                label: Text(
                  _currentPage == 0 ? 'cancel'.tr() : 'wizard_back'.tr(),
                ),
              ),
            ),
          ),
          // Step label
          Text(
            '${_currentPage + 1} / $_pageCount',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          // Next / Create button
          Expanded(
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: isLastPage
                  ? FilledButton.icon(
                      onPressed: _saving ? null : _createGroup,
                      icon: _saving
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check),
                      label: Text('create_group'.tr()),
                    )
                  : FilledButton.icon(
                      onPressed: _goNext,
                      icon: const Icon(Icons.arrow_forward),
                      label: Text(_currentPage == 1
                          ? (_participants.isEmpty
                              ? 'wizard_skip'.tr()
                              : 'wizard_next'.tr())
                          : 'wizard_next'.tr()),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // STEP 1 — Name & Currency
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildStep1NameCurrency(BuildContext context) {
    final theme = Theme.of(context);
    return Form(
      key: _nameFormKey,
      child: ListView(
        padding: const EdgeInsets.all(ThemeConfig.spacingM),
        children: [
          const SizedBox(height: ThemeConfig.spacingM),
          Text(
            'wizard_step1_title'.tr(),
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: ThemeConfig.spacingS),
          Text(
            'wizard_step1_subtitle'.tr(),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: ThemeConfig.spacingXL),
          TextFormField(
            controller: _nameController,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'group_name'.tr(),
              hintText: 'wizard_name_hint'.tr(),
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.group_outlined),
            ),
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'required'.tr() : null,
            textInputAction: TextInputAction.next,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: ThemeConfig.spacingL),
          Text(
            'currency'.tr(),
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: ThemeConfig.spacingS),
          InkWell(
            onTap: _openCurrencyPicker,
            borderRadius: BorderRadius.circular(ThemeConfig.radiusL),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                border: Border.all(color: theme.colorScheme.outline),
                borderRadius: BorderRadius.circular(ThemeConfig.radiusL),
              ),
              child: Row(
                children: [
                  Text(
                    CurrencyUtils.currencyToEmoji(_selectedCurrency),
                    style: const TextStyle(fontSize: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      CurrencyHelpers.displayLabel(_selectedCurrency),
                      style: theme.textTheme.bodyLarge,
                    ),
                  ),
                  Icon(
                    Icons.arrow_drop_down,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openCurrencyPicker() {
    final stored = ref.read(favoriteCurrenciesProvider);
    final favorites = CurrencyHelpers.getEffectiveFavorites(stored);
    CurrencyHelpers.showPicker(
      context: context,
      favorite: favorites,
      onSelect: (Currency currency) {
        setState(() => _selectedCurrency = currency);
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // STEP 2 — Participants
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildStep2Participants(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListView(
      padding: const EdgeInsets.all(ThemeConfig.spacingM),
      children: [
        const SizedBox(height: ThemeConfig.spacingM),
        Text(
          'wizard_step2_title'.tr(),
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: ThemeConfig.spacingS),
        Text(
          'wizard_step2_subtitle'.tr(),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: ThemeConfig.spacingL),

        // Owner card (non-removable)
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ThemeConfig.radiusL),
            side: BorderSide(color: colorScheme.primary.withValues(alpha: 0.3)),
          ),
          color: colorScheme.primaryContainer.withValues(alpha: 0.2),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: colorScheme.primary,
              child: const Icon(Icons.person, color: Colors.white),
            ),
            title: Text(
              'wizard_you'.tr(),
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text('wizard_owner'.tr()),
          ),
        ),
        const SizedBox(height: ThemeConfig.spacingS),

        // Added participants
        ...List.generate(_participants.length, (i) {
          return Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(ThemeConfig.radiusL),
              side: BorderSide(
                color: colorScheme.outline.withValues(alpha: 0.2),
              ),
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: colorScheme.surfaceContainerHighest,
                child: Text(
                  _participants[i][0].toUpperCase(),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
              title: Text(_participants[i]),
              trailing: IconButton(
                icon: Icon(Icons.close, color: colorScheme.error),
                onPressed: () => _removeParticipant(i),
                tooltip: 'remove'.tr(),
              ),
            ),
          );
        }),

        const SizedBox(height: ThemeConfig.spacingM),

        // Add participant input
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _participantController,
                focusNode: _participantFocusNode,
                decoration: InputDecoration(
                  hintText: 'wizard_participant_hint'.tr(),
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.person_add_outlined),
                ),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _addParticipant(),
              ),
            ),
            const SizedBox(width: ThemeConfig.spacingS),
            FilledButton.tonal(
              onPressed: _addParticipant,
              child: Text('wizard_add'.tr()),
            ),
          ],
        ),
        const SizedBox(height: ThemeConfig.spacingS),
        Text(
          'wizard_participants_hint'.tr(),
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // STEP 3 — Icon & Color
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildStep3IconColor(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListView(
      padding: const EdgeInsets.all(ThemeConfig.spacingM),
      children: [
        const SizedBox(height: ThemeConfig.spacingM),
        Text(
          'wizard_step3_title'.tr(),
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: ThemeConfig.spacingS),
        Text(
          'wizard_step3_subtitle'.tr(),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: ThemeConfig.spacingL),

        // Icon grid
        Text(
          'wizard_icon_label'.tr(),
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: ThemeConfig.spacingM),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1,
          ),
          itemCount: groupIcons.length,
          itemBuilder: (context, index) {
            final opt = groupIcons[index];
            final isSelected = _selectedIcon == opt.key;
            return Material(
              color: isSelected
                  ? _selectedColor.withValues(alpha: 0.15)
                  : colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(ThemeConfig.radiusL),
              child: InkWell(
                borderRadius: BorderRadius.circular(ThemeConfig.radiusL),
                onTap: () => setState(() => _selectedIcon = opt.key),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(ThemeConfig.radiusL),
                    border: Border.all(
                      color: isSelected
                          ? _selectedColor
                          : colorScheme.outline.withValues(alpha: 0.2),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        opt.icon,
                        size: 28,
                        color: isSelected
                            ? _selectedColor
                            : colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        opt.labelKey.tr(),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: isSelected
                              ? _selectedColor
                              : colorScheme.onSurfaceVariant,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),

        const SizedBox(height: ThemeConfig.spacingXL),

        // Color palette
        Text(
          'wizard_color_label'.tr(),
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: ThemeConfig.spacingM),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: groupColors.map((color) {
            final isSelected = _selectedColor == color;
            return GestureDetector(
              onTap: () => setState(() => _selectedColor = color),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? colorScheme.onSurface : Colors.transparent,
                    width: 3,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: color.withValues(alpha: 0.4),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
                child: isSelected
                    ? const Icon(Icons.check, color: Colors.white, size: 22)
                    : null,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // STEP 4 — Summary
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildStep4Summary(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final iconDef = groupIcons.where((g) => g.key == _selectedIcon).firstOrNull;
    final totalParticipants = 1 + _participants.length; // owner + added

    return ListView(
      padding: const EdgeInsets.all(ThemeConfig.spacingM),
      children: [
        const SizedBox(height: ThemeConfig.spacingM),
        Text(
          'wizard_step4_title'.tr(),
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: ThemeConfig.spacingS),
        Text(
          'wizard_step4_subtitle'.tr(),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: ThemeConfig.spacingL),

        // Summary card
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ThemeConfig.radiusXL),
            side: BorderSide(
              color: colorScheme.outline.withValues(alpha: 0.2),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(ThemeConfig.spacingL),
            child: Column(
              children: [
                // Group avatar
                CircleAvatar(
                  radius: 36,
                  backgroundColor: _selectedColor,
                  child: iconDef != null && iconDef.key != groupIconLetterKey
                      ? Icon(iconDef.icon, size: 36, color: Colors.white)
                      : Text(
                          _nameController.text.trim().isNotEmpty
                              ? _nameController.text.trim()[0].toUpperCase()
                              : '?',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
                const SizedBox(height: ThemeConfig.spacingM),
                // Group name
                Text(
                  _nameController.text.trim(),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: ThemeConfig.spacingL),
                const Divider(),
                const SizedBox(height: ThemeConfig.spacingS),

                // Currency row
                _SummaryRow(
                  icon: Icons.attach_money,
                  label: 'currency'.tr(),
                  value: CurrencyHelpers.shortLabel(_selectedCurrency),
                  onEdit: () => _goToPage(0),
                ),
                const SizedBox(height: ThemeConfig.spacingM),

                // Participants row
                _SummaryRow(
                  icon: Icons.people_outline,
                  label: 'participants'.tr(),
                  value: '$totalParticipants',
                  onEdit: () => _goToPage(1),
                ),
                if (_participants.isNotEmpty) ...[
                  const SizedBox(height: ThemeConfig.spacingS),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _participants
                        .map((p) => Chip(
                              label: Text(p),
                              visualDensity: VisualDensity.compact,
                            ))
                        .toList(),
                  ),
                ],
                const SizedBox(height: ThemeConfig.spacingM),

                // Icon row
                if (_selectedIcon != null) ...[
                  _SummaryRow(
                    icon: iconDef?.icon ?? Icons.grid_view_rounded,
                    label: 'wizard_icon_label'.tr(),
                    value: iconDef?.labelKey.tr() ?? '',
                    onEdit: () => _goToPage(2),
                  ),
                  const SizedBox(height: ThemeConfig.spacingM),
                ],

                // Color row
                Row(
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: _selectedColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: ThemeConfig.spacingS),
                    Text(
                      'wizard_color_label'.tr(),
                      style: theme.textTheme.bodyMedium,
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      onPressed: () => _goToPage(2),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _goToPage(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Summary row widget
// ─────────────────────────────────────────────────────────────────────────────

class _SummaryRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onEdit;

  const _SummaryRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: ThemeConfig.spacingS),
        Text(label, style: theme.textTheme.bodyMedium),
        const Spacer(),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 4),
        IconButton(
          icon: const Icon(Icons.edit_outlined, size: 18),
          onPressed: onEdit,
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }
}
