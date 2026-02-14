import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../../core/theme/theme_config.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('privacy_policy'.tr()),
      ),
      body: ListView(
        padding: const EdgeInsets.all(ThemeConfig.spacingM),
        children: [
          Text(
            'privacy_policy_last_updated'.tr(),
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: ThemeConfig.spacingL),
          _buildSection(
            context,
            title: 'privacy_policy_intro_title'.tr(),
            body: 'privacy_policy_intro_body'.tr(),
          ),
          _buildSection(
            context,
            title: 'privacy_policy_permissions_title'.tr(),
            body: 'privacy_policy_permissions_body'.tr(),
          ),
          _buildSection(
            context,
            title: 'privacy_policy_data_collection_title'.tr(),
            body: 'privacy_policy_data_collection_body'.tr(),
          ),
          _buildSection(
            context,
            title: 'privacy_policy_data_storage_title'.tr(),
            body: 'privacy_policy_data_storage_body'.tr(),
          ),
          _buildSection(
            context,
            title: 'privacy_policy_data_usage_title'.tr(),
            body: 'privacy_policy_data_usage_body'.tr(),
          ),
          _buildSection(
            context,
            title: 'privacy_policy_third_party_title'.tr(),
            body: 'privacy_policy_third_party_body'.tr(),
          ),
          _buildSection(
            context,
            title: 'privacy_policy_data_sharing_title'.tr(),
            body: 'privacy_policy_data_sharing_body'.tr(),
          ),
          _buildSection(
            context,
            title: 'privacy_policy_data_security_title'.tr(),
            body: 'privacy_policy_data_security_body'.tr(),
          ),
          _buildSection(
            context,
            title: 'privacy_policy_user_rights_title'.tr(),
            body: 'privacy_policy_user_rights_body'.tr(),
          ),
          _buildSection(
            context,
            title: 'privacy_policy_data_retention_title'.tr(),
            body: 'privacy_policy_data_retention_body'.tr(),
          ),
          _buildSection(
            context,
            title: 'privacy_policy_children_title'.tr(),
            body: 'privacy_policy_children_body'.tr(),
          ),
          _buildSection(
            context,
            title: 'privacy_policy_changes_title'.tr(),
            body: 'privacy_policy_changes_body'.tr(),
          ),
          _buildSection(
            context,
            title: 'privacy_policy_contact_title'.tr(),
            body: 'privacy_policy_contact_body'.tr(),
          ),
          const SizedBox(height: ThemeConfig.spacingXL),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required String body,
  }) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: ThemeConfig.spacingL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: ThemeConfig.spacingS),
          Text(
            body,
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
