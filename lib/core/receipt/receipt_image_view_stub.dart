import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../layout/layout_breakpoints.dart';
import '../layout/responsive_sheet.dart';
import '../widgets/sheet_helpers.dart';
import 'receipt_utils.dart';

void showExpenseImageFullScreen(BuildContext context, String imagePath) {
  showResponsiveSheet<void>(
    context: context,
    title: LayoutBreakpoints.isTabletOrWider(context) ? 'image'.tr() : null,
    centerInFullViewport: true,
    child: Builder(
      builder: (context) => buildSheetShell(
        context,
        title: 'image'.tr(),
        body: Text(
          isImageUrl(imagePath)
              ? 'image_unavailable'.tr()
              : 'image_preview_web'.tr(),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('ok'.tr()),
          ),
        ],
      ),
    ),
  );
}

Widget buildExpenseImageView(
  BuildContext context,
  String? imagePath, {
  double? maxHeight,
  double? width,
  BoxFit fit = BoxFit.cover,
  EdgeInsetsGeometry padding = const EdgeInsets.only(top: 8),
  BorderRadius? borderRadius,
}) {
  if (imagePath == null || imagePath.isEmpty) return const SizedBox.shrink();
  final colors = Theme.of(context).colorScheme;
  return Padding(
    padding: padding,
    child: Container(
      width: width,
      height: maxHeight ?? 200,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: borderRadius ?? BorderRadius.circular(12),
      ),
      child: Icon(Icons.image_outlined, color: colors.onSurfaceVariant),
    ),
  );
}
