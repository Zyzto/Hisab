import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../layout/layout_breakpoints.dart';
import '../layout/responsive_sheet.dart';
import '../pwa/pwa_capabilities.dart';
import 'sheet_helpers.dart';

/// Opens platform-specific "Add to Home Screen" / install instructions.
Future<void> showPwaInstallGuide(BuildContext context) {
  final iosGuide = useIosInstallGuide(mode: pwaInstallMode, isIos: isPwaIos);
  final title = 'install_app_how_to_title'.tr();
  final isTablet = LayoutBreakpoints.isTabletOrWider(context);

  return showResponsiveSheet<void>(
    context: context,
    title: title,
    maxHeight: MediaQuery.of(context).size.height * 0.7,
    isScrollControlled: true,
    centerInFullViewport: true,
    child: Builder(
      builder: (ctx) => buildSheetShell(
        ctx,
        title: title,
        showTitleInBody: !isTablet,
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                iosGuide
                    ? 'install_app_ios_intro'.tr()
                    : 'install_app_android_intro'.tr(),
                style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              ..._stepsFor(iosGuide).asMap().entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _InstallStepRow(
                    index: entry.key + 1,
                    text: entry.value,
                    highlightShare: iosGuide && entry.key == 0,
                  ),
                );
              }),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('install_app_got_it'.tr()),
          ),
        ],
      ),
    ),
  );
}

List<String> _stepsFor(bool iosGuide) {
  if (iosGuide) {
    return [
      'install_app_ios_step_1'.tr(),
      'install_app_ios_step_2'.tr(),
      'install_app_ios_step_3'.tr(),
    ];
  }
  return [
    'install_app_android_step_1'.tr(),
    'install_app_android_step_2'.tr(),
    'install_app_android_step_3'.tr(),
  ];
}

class _InstallStepRow extends StatelessWidget {
  const _InstallStepRow({
    required this.index,
    required this.text,
    this.highlightShare = false,
  });

  final int index;
  final String text;
  final bool highlightShare;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '$index',
            style: TextStyle(
              color: colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (highlightShare) ...[
                  Icon(
                    Icons.ios_share_rounded,
                    size: 18,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: Text(
                    text,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(height: 1.35),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
