import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_settings_framework/flutter_settings_framework.dart';
import 'package:flutter_logging_service/flutter_logging_service.dart';

import '../../../core/receipt/receipt_nano_service.dart';
import '../../../core/receipt/receipt_scan_capability.dart';
import '../../../core/widgets/sheet_helpers.dart';
import '../../../core/widgets/toast.dart';
import '../settings_definitions.dart';
import '../providers/settings_framework_providers.dart';

/// Callback to show the API key dialog. Called when user taps a Gemini/OpenAI key tile.
typedef ShowApiKeyDialogCallback =
    Future<void> Function({
      required BuildContext context,
      required WidgetRef ref,
      required String titleKey,
      required String currentValue,
      required StringSetting settingDef,
    });

const _modeLabelKeys = {
  ReceiptScanMode.off: 'receipt_scan_mode_off',
  ReceiptScanMode.local: 'receipt_scan_mode_local',
  ReceiptScanMode.nano: 'receipt_scan_mode_nano',
  ReceiptScanMode.cloud: 'receipt_scan_mode_cloud',
};

const _providerLabelKeys = {
  'gemini': 'receipt_ai_provider_gemini',
  'openai': 'receipt_ai_provider_openai',
  'hisab': 'receipt_ai_provider_hisab',
};

/// Returns the list of tiles for the Receipt AI section.
List<Widget> buildReceiptAiSectionTiles(
  BuildContext context,
  WidgetRef ref,
  SettingsProviders settings,
  ShowApiKeyDialogCallback showApiKeyDialog, {
  SettingAnchorRegistry? anchors,
}) {
  Widget wrap(String key, Widget tile) => anchors?.wrap(key, tile) ?? tile;
  final mode = ref.watch(receiptScanModeProvider);
  final provider = ref.watch(receiptAiProviderProvider);

  return [
    wrap(
      receiptScanModeSettingDef.key,
      _receiptScanModeTile(context, ref, settings, mode),
    ),
    if (mode == ReceiptScanMode.nano && ReceiptScanCapability.supportsNano)
      wrap('receipt_nano_status', _NanoStatusTile()),
    if (mode == ReceiptScanMode.nano && !ReceiptScanCapability.supportsNano)
      ListTile(
        leading: const Icon(Icons.info_outline),
        title: Text('receipt_nano_android_only'.tr()),
        subtitle: Text('receipt_nano_falls_back_local'.tr()),
      ),
    if (mode == ReceiptScanMode.cloud) ...[
      wrap(
        receiptAiProviderSettingDef.key,
        _receiptAiProviderTile(context, ref, settings, provider),
      ),
      if (provider == 'gemini' ||
          ref.watch(geminiApiKeyProvider).isNotEmpty)
        wrap(
          geminiApiKeySettingDef.key,
          ListTile(
            leading: const Icon(Icons.key),
            title: Text('gemini_api_key'.tr()),
            subtitle: Text(
              ref.watch(geminiApiKeyProvider).isEmpty
                  ? 'receipt_ai_key_not_set'.tr()
                  : 'receipt_ai_key_set'.tr(),
            ),
            onTap: () => showApiKeyDialog(
              context: context,
              ref: ref,
              titleKey: 'gemini_api_key',
              currentValue: ref.read(geminiApiKeyProvider),
              settingDef: geminiApiKeySettingDef,
            ),
          ),
        ),
      if (provider == 'openai' ||
          ref.watch(openaiApiKeyProvider).isNotEmpty)
        wrap(
          openaiApiKeySettingDef.key,
          ListTile(
            leading: const Icon(Icons.key),
            title: Text('openai_api_key'.tr()),
            subtitle: Text(
              ref.watch(openaiApiKeyProvider).isEmpty
                  ? 'receipt_ai_key_not_set'.tr()
                  : 'receipt_ai_key_set'.tr(),
            ),
            onTap: () => showApiKeyDialog(
              context: context,
              ref: ref,
              titleKey: 'openai_api_key',
              currentValue: ref.read(openaiApiKeyProvider),
              settingDef: openaiApiKeySettingDef,
            ),
          ),
        ),
    ],
  ];
}

Widget _receiptScanModeTile(
  BuildContext context,
  WidgetRef ref,
  SettingsProviders settings,
  String value,
) {
  final modes = ReceiptScanCapability.availableModes();
  // Keep showing the stored mode label even if this platform can't offer it
  // in the picker (e.g. Nano on iOS) — the note tile explains the fallback.
  final labelKey = _modeLabelKeys[value] ?? _modeLabelKeys[ReceiptScanMode.off]!;
  final pickerSelected = modes.contains(value)
      ? value
      : ReceiptScanMode.local;
  return ListTile(
    leading: Icon(receiptScanModeSettingDef.icon),
    title: Text('receipt_scan_mode'.tr()),
    subtitle: Text(labelKey.tr()),
    onTap: () async {
      final chosen = await showOptionPickerSheet<String>(
        context,
        title: 'receipt_scan_mode'.tr(),
        centerInFullViewport: false,
        selected: pickerSelected,
        options: [
          for (final option in modes)
            SheetPickerOption(
              value: option,
              label: (_modeLabelKeys[option] ?? option).tr(),
            ),
        ],
      );
      if (chosen != null && context.mounted) {
        ref
            .read(settings.provider(receiptScanModeSettingDef).notifier)
            .set(chosen);
        Log.info('Setting changed: ${receiptScanModeSettingDef.key}=$chosen');
      }
    },
  );
}

Widget _receiptAiProviderTile(
  BuildContext context,
  WidgetRef ref,
  SettingsProviders settings,
  String value,
) {
  final effective = value == 'none' || value.isEmpty ? 'gemini' : value;
  final labelKey = _providerLabelKeys[effective] ?? effective;
  return ListTile(
    leading: Icon(receiptAiProviderSettingDef.icon),
    title: Text('receipt_ai_provider'.tr()),
    subtitle: Text(
      '${labelKey.tr()} · ${'receipt_ai_provider_hisab_coming_soon'.tr()}',
    ),
    onTap: () async {
      final chosen = await showOptionPickerSheet<String>(
        context,
        title: 'receipt_ai_provider'.tr(),
        centerInFullViewport: false,
        selected: effective == 'hisab' ? 'gemini' : effective,
        options: [
          for (final option in const ['gemini', 'openai'])
            SheetPickerOption(
              value: option,
              label: (_providerLabelKeys[option] ?? option).tr(),
            ),
        ],
      );
      if (chosen != null && context.mounted) {
        ref
            .read(settings.provider(receiptAiProviderSettingDef).notifier)
            .set(chosen);
        Log.info(
          'Setting changed: ${receiptAiProviderSettingDef.key}=$chosen',
        );
      }
    },
  );
}

class _NanoStatusTile extends StatefulWidget {
  @override
  State<_NanoStatusTile> createState() => _NanoStatusTileState();
}

class _NanoStatusTileState extends State<_NanoStatusTile> {
  NanoFeatureStatus? _status;
  bool _busy = false;

  String _statusLabel(NanoFeatureStatus? status) {
    switch (status) {
      case NanoFeatureStatus.available:
        return 'receipt_nano_status_available'.tr();
      case NanoFeatureStatus.downloadable:
        return 'receipt_nano_status_downloadable'.tr();
      case NanoFeatureStatus.downloading:
        return 'receipt_nano_status_downloading'.tr();
      case NanoFeatureStatus.unavailable:
        return 'receipt_nano_status_unavailable'.tr();
      case null:
        return 'receipt_nano_status_unknown'.tr();
    }
  }

  Future<void> _check() async {
    setState(() => _busy = true);
    try {
      final status = await checkNanoStatus();
      if (!mounted) return;
      setState(() {
        _status = status;
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = NanoFeatureStatus.unavailable;
        _busy = false;
      });
      context.showError('receipt_nano_check_failed'.tr());
    }
  }

  Future<void> _download() async {
    setState(() {
      _busy = true;
      _status = NanoFeatureStatus.downloading;
    });
    try {
      await downloadNanoFeature();
      final status = await checkNanoStatus();
      if (!mounted) return;
      setState(() {
        _status = status;
        _busy = false;
      });
      if (status == NanoFeatureStatus.available) {
        context.showSuccess('receipt_nano_download_done'.tr());
      } else {
        context.showToast('receipt_nano_download_pending'.tr());
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = NanoFeatureStatus.downloadable;
        _busy = false;
      });
      context.showError('receipt_nano_download_failed'.tr());
    }
  }

  @override
  Widget build(BuildContext context) {
    final canDownload = _status == NanoFeatureStatus.downloadable && !_busy;
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.memory),
          title: Text('receipt_nano_status'.tr()),
          subtitle: Text(_statusLabel(_status)),
          trailing: _busy
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : TextButton(
                  onPressed: _check,
                  child: Text('receipt_nano_check_device'.tr()),
                ),
        ),
        if (canDownload)
          ListTile(
            leading: const Icon(Icons.download),
            title: Text('receipt_nano_download'.tr()),
            onTap: _download,
          ),
      ],
    );
  }
}
