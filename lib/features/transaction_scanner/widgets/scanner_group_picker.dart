import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../core/widgets/user_text.dart';
import '../../../domain/group.dart';

class ScannerGroupPicker extends StatelessWidget {
  final List<Group> groups;
  final String? selectedId;
  final ValueChanged<String> onSelected;

  const ScannerGroupPicker({
    super.key,
    required this.groups,
    required this.selectedId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final usable = groups.where((g) => !g.isArchived).toList();
    if (usable.isEmpty) {
      return Text('scanner_no_groups'.tr());
    }
    return Column(
      children: usable.map((g) {
        return RadioListTile<String>(
          value: g.id,
          groupValue: selectedId,
          onChanged: (v) {
            if (v != null) onSelected(v);
          },
          title: UserText(g.name),
          subtitle: Text(
            g.isPersonal
                ? 'scanner_dest_personal'.tr()
                : 'scanner_dest_shared'.tr(),
          ),
        );
      }).toList(),
    );
  }
}
