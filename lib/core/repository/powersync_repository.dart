import 'dart:async';
import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:flutter_logging_service/flutter_logging_service.dart';
import 'package:powersync/powersync.dart';
import 'package:uuid/uuid.dart';

import '../utils/user_text.dart';
import '../services/household_service.dart';
import '../../domain/domain.dart';
import 'group_repository.dart';
import 'participant_repository.dart';
import 'expense_repository.dart';
import 'tag_repository.dart';
import 'group_member_repository.dart';
import 'household_balance_reassignment_repository.dart';

part 'powersync_repository_shared.dart';
part 'powersync_group_repository.dart';
part 'powersync_participant_repository.dart';
part 'powersync_expense_repository.dart';
part 'powersync_tag_repository.dart';
part 'powersync_group_member_repository.dart';
part 'powersync_household_balance_reassignment_repository.dart';
