import 'package:currency_picker/currency_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_logging_service/flutter_logging_service.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../core/repository/repository_providers.dart';
import '../../../core/navigation/route_paths.dart';
import '../../../core/telemetry/telemetry_service.dart';
import '../../../core/utils/currency_helpers.dart';
import '../../settings/providers/settings_framework_providers.dart';

class GroupCreatePage extends ConsumerStatefulWidget {
  const GroupCreatePage({super.key});

  @override
  ConsumerState<GroupCreatePage> createState() => _GroupCreatePageState();
}

class _GroupCreatePageState extends ConsumerState<GroupCreatePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  late Currency _selectedCurrency;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selectedCurrency = CurrencyHelpers.defaultCurrencyForLocale();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _openCurrencyPicker() {
    showCurrencyPicker(
      context: context,
      favorite: CurrencyHelpers.favoriteCurrencies,
      showFlag: true,
      showSearchField: true,
      showCurrencyName: true,
      showCurrencyCode: true,
      onSelect: (Currency currency) {
        setState(() => _selectedCurrency = currency);
      },
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final name = _nameController.text.trim();
      final currencyCode = _selectedCurrency.code;
      final repo = ref.read(groupRepositoryProvider);
      final id = await repo.create(name, currencyCode);
      Log.info(
        'Group created: id=$id name="$name" currencyCode=$currencyCode',
      );
      try {
        TelemetryService.sendEvent('group_created', {
          'groupId': id,
          'currencyCode': currencyCode,
        }, enabled: ref.read(telemetryEnabledProvider));
      } catch (_) {}
      if (mounted) context.go(RoutePaths.groupDetail(id));
    } catch (e, st) {
      Log.warning('Group create failed', error: e, stackTrace: st);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('create_group'.tr()),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'group_name'.tr(),
                border: const OutlineInputBorder(),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            Text(
              'currency'.tr(),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            InkWell(
              onTap: _openCurrencyPicker,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: theme.colorScheme.outline),
                  borderRadius: BorderRadius.circular(12),
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
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text('create_group'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}
