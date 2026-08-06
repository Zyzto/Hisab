import 'dart:async';
import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:flutter_logging_service/flutter_logging_service.dart';
import 'package:powersync/powersync.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../constants/supabase_config.dart';
import '../utils/user_text.dart';
import '../../domain/domain.dart';
import 'group_repository.dart';
import 'participant_repository.dart';
import 'expense_repository.dart';
import 'tag_repository.dart';
import 'group_member_repository.dart';
import 'group_invite_repository.dart';
import 'user_notification_repository.dart';

part 'powersync_repository_shared.dart';
part 'powersync_group_repository.dart';
part 'powersync_participant_repository.dart';
part 'powersync_expense_repository.dart';
part 'powersync_tag_repository.dart';
part 'powersync_group_member_repository.dart';
part 'powersync_group_invite_repository.dart';
part 'powersync_user_notification_repository.dart';
