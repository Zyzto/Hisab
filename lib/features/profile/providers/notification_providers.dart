import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/supabase_config.dart';
import '../../../core/database/database_providers.dart';
import '../../../core/repository/powersync_repository.dart';
import '../../../core/repository/user_notification_repository.dart';
import '../../../core/services/connectivity_service.dart';
import '../../../domain/domain.dart';
import 'package:hisab/core/settings/providers/settings_framework_providers.dart';

final userNotificationRepositoryProvider =
    Provider<IUserNotificationRepository>((ref) {
      final localOnly = ref.watch(effectiveLocalOnlyProvider);
      final isOnline = ref.watch(connectivityProvider);
      return PowerSyncUserNotificationRepository(
        ref.watch(powerSyncDatabaseProvider),
        client: (localOnly || !supabaseConfigAvailable)
            ? null
            : supabaseClientIfConfigured,
        isOnline: isOnline,
        isLocalOnly: localOnly,
      );
    });

final userNotificationsProvider = StreamProvider<List<UserNotification>>((ref) {
  return ref.watch(userNotificationRepositoryProvider).watchRecent();
});

final unreadNotificationCountProvider = StreamProvider<int>((ref) {
  return ref.watch(userNotificationRepositoryProvider).watchUnreadCount();
});
