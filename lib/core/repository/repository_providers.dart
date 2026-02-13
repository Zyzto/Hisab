import 'package:flutter_logging_service/flutter_logging_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/supabase_config.dart';
import '../database/database_providers.dart';
import '../services/connectivity_service.dart';
import '../../features/settings/providers/settings_framework_providers.dart';
import 'group_repository.dart';
import 'group_member_repository.dart';
import 'group_invite_repository.dart';
import 'participant_repository.dart';
import 'expense_repository.dart';
import 'tag_repository.dart';
import 'powersync_repository.dart';

part 'repository_providers.g.dart';

/// Helper: get SupabaseClient if available and not local-only.
SupabaseClient? _clientIfOnline(bool localOnly) {
  if (localOnly || !supabaseConfigAvailable) return null;
  try {
    return Supabase.instance.client;
  } catch (_) {
    return null;
  }
}

@riverpod
IGroupRepository groupRepository(Ref ref) {
  final localOnly = ref.watch(effectiveLocalOnlyProvider);
  final isOnline = ref.watch(connectivityProvider);
  Log.debug(
    'Providing group repository (localOnly=$localOnly, online=$isOnline)',
  );
  return PowerSyncGroupRepository(
    ref.watch(powerSyncDatabaseProvider),
    client: _clientIfOnline(localOnly),
    isOnline: isOnline,
    isLocalOnly: localOnly,
  );
}

@riverpod
IParticipantRepository participantRepository(Ref ref) {
  final localOnly = ref.watch(effectiveLocalOnlyProvider);
  final isOnline = ref.watch(connectivityProvider);
  return PowerSyncParticipantRepository(
    ref.watch(powerSyncDatabaseProvider),
    client: _clientIfOnline(localOnly),
    isOnline: isOnline,
    isLocalOnly: localOnly,
  );
}

@riverpod
IExpenseRepository expenseRepository(Ref ref) {
  final localOnly = ref.watch(effectiveLocalOnlyProvider);
  final isOnline = ref.watch(connectivityProvider);
  return PowerSyncExpenseRepository(
    ref.watch(powerSyncDatabaseProvider),
    client: _clientIfOnline(localOnly),
    isOnline: isOnline,
    isLocalOnly: localOnly,
  );
}

@riverpod
ITagRepository tagRepository(Ref ref) {
  final localOnly = ref.watch(effectiveLocalOnlyProvider);
  final isOnline = ref.watch(connectivityProvider);
  return PowerSyncTagRepository(
    ref.watch(powerSyncDatabaseProvider),
    client: _clientIfOnline(localOnly),
    isOnline: isOnline,
    isLocalOnly: localOnly,
  );
}

@riverpod
IGroupMemberRepository groupMemberRepository(Ref ref) {
  final localOnly = ref.watch(effectiveLocalOnlyProvider);
  return PowerSyncGroupMemberRepository(
    ref.watch(powerSyncDatabaseProvider),
    isLocalOnly: localOnly,
  );
}

@riverpod
IGroupInviteRepository groupInviteRepository(Ref ref) {
  final localOnly = ref.watch(effectiveLocalOnlyProvider);
  return PowerSyncGroupInviteRepository(
    ref.watch(powerSyncDatabaseProvider),
    supabaseClient: _clientIfOnline(localOnly),
  );
}
