import 'dart:async';

import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter_logging_service/flutter_logging_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/database/database_providers.dart';
import '../../../core/repository/repository_providers.dart';
import '../../../domain/domain.dart';
import 'package:hisab/core/settings/providers/settings_framework_providers.dart';
import 'package:hisab/core/settings/settings_definitions.dart';
import '../domain/draft_transaction.dart';
import '../domain/scanner_category_rule.dart';
import '../domain/scanner_notification_log.dart';
import '../domain/scanner_pattern.dart';
import '../domain/sender_rule.dart';
import '../repository/scanner_repository.dart';
import '../services/category_rules.dart';
import '../services/duplicate_detector.dart';
import '../services/notification_bridge.dart';
import '../services/scanner_ai_service.dart';
import '../services/transaction_parser.dart';
import '../utils/scanner_destination.dart';

const _uuid = Uuid();

/// Whether the scanner feature is available on this platform.
bool get scannerAvailable =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

/// Repository instance.
final scannerRepositoryProvider = Provider<ScannerRepository>((ref) {
  final db = ref.watch(powerSyncDatabaseProvider);
  return ScannerRepository(db);
});

/// Whether the scanner is enabled in settings.
final scannerEnabledProvider = Provider<bool>((ref) {
  final settings = ref.watch(hisabSettingsProvidersProvider);
  if (settings == null) return false;
  final value = ref.watch(settings.provider(scannerEnabledSettingDef));
  return value == true;
});

/// Number of pending draft transactions (for badge display).
final pendingDraftCountProvider = FutureProvider<int>((ref) async {
  final repo = ref.watch(scannerRepositoryProvider);
  return repo.getPendingCount();
});

/// Pending draft counts keyed by destination group id.
final pendingDraftCountByGroupProvider = FutureProvider<Map<String, int>>((
  ref,
) async {
  final repo = ref.watch(scannerRepositoryProvider);
  final counts = await repo.getPendingCountByGroup();
  final settings = ref.watch(hisabSettingsProvidersProvider);
  var fallback =
      (settings?.controller.get(scannerDefaultGroupIdSettingDef) ?? '')
          .toString();
  if (fallback.isEmpty) {
    final groups = await ref.watch(groupRepositoryProvider).getAll();
    fallback =
        groups.where((g) => g.isPersonal).firstOrNull?.id ??
        groups.firstOrNull?.id ??
        '';
  }
  if (fallback.isNotEmpty && counts.containsKey('')) {
    counts[fallback] = (counts[fallback] ?? 0) + (counts[''] ?? 0);
    counts.remove('');
  }
  return counts;
});

/// All pending draft transactions.
final pendingDraftsProvider = FutureProvider<List<DraftTransaction>>((
  ref,
) async {
  final repo = ref.watch(scannerRepositoryProvider);
  return repo.getPendingDrafts();
});

/// All sender rules.
final senderRulesProvider = FutureProvider<List<SenderRule>>((ref) async {
  final repo = ref.watch(scannerRepositoryProvider);
  return repo.getSenderRules();
});

/// All scanner patterns.
final scannerPatternsProvider = FutureProvider<List<ScannerPattern>>((
  ref,
) async {
  final repo = ref.watch(scannerRepositoryProvider);
  return repo.getPatterns();
});

final scannerCategoryRulesProvider = FutureProvider<List<ScannerCategoryRule>>((
  ref,
) async {
  return ref.watch(scannerRepositoryProvider).getCategoryRules();
});

final scannerLogSummaryProvider =
    FutureProvider<({int added, int ignored, int pending})>((ref) async {
      return ref.watch(scannerRepositoryProvider).getLogSummary();
    });

final scannerNotificationLogProvider =
    FutureProvider.family<
      List<ScannerNotificationLog>,
      ({String? packageName, String filter})
    >((ref, query) async {
      final repo = ref.watch(scannerRepositoryProvider);
      switch (query.filter) {
        case 'added':
          return repo.getNotificationLog(
            packageName: query.packageName,
            outcome: ScannerLogOutcome.added,
          );
        case 'pending':
          return repo.getNotificationLog(
            packageName: query.packageName,
            outcome: ScannerLogOutcome.pending,
          );
        case 'ignored':
          return repo.getIgnoredLogs(packageName: query.packageName);
        default:
          return repo.getNotificationLog(packageName: query.packageName);
      }
    });

/// Controller that bridges notification capture -> parsing -> draft creation.
final scannerControllerProvider = Provider<ScannerController>((ref) {
  final controller = ScannerController(ref);
  ref.onDispose(controller.dispose);
  return controller;
});

class ScannerController {
  final Ref _ref;
  StreamSubscription<void>? _eventSub;
  bool _seeded = false;
  bool _listening = false;
  bool _retentionRan = false;

  ScannerController(this._ref) {
    _init();
  }

  void _init() {
    if (!scannerAvailable) return;

    _seedAndListen();

    _ref.listen<bool>(scannerEnabledProvider, (prev, next) {
      if (next && !_listening) _startListening();
    });
  }

  Future<void> _seedAndListen() async {
    await _seedBuiltInPatterns();
    await syncSendersToNative();
    if (!_retentionRan) {
      _retentionRan = true;
      unawaited(_ref.read(scannerRepositoryProvider).deleteOldDismissed());
    }

    final enabled = _ref.read(scannerEnabledProvider);
    if (!enabled) return;

    _startListening();
  }

  void _startListening() {
    if (_listening) return;
    _listening = true;

    _eventSub = NotificationBridge.onNewNotification.listen((_) {
      _flushPending();
    });

    _flushPending();
  }

  Future<void> _seedBuiltInPatterns() async {
    if (_seeded) return;
    try {
      final repo = _ref.read(scannerRepositoryProvider);
      final existing = await repo.getPatterns();
      if (existing.any((p) => p.isBuiltIn)) {
        _seeded = true;
        return;
      }

      final now = DateTime.now();
      final builtIns = <ScannerPattern>[
        ScannerPattern(
          id: 'builtin_bank_en_1',
          name: 'scanner_pattern_bank_en',
          senderMatch: '*',
          amountRegex:
              r'(?:SAR|USD|EUR|GBP|AED)\s*(\d{1,3}(?:,\d{3})*(?:\.\d{1,2})?)',
          currencyRegex: r'\b(SAR|USD|EUR|GBP|AED|KWD|BHD|OMR|QAR|EGP)\b',
          cardRegex: r'\*(\d{4})',
          merchantRegex: r'(?:at|from|to)\s+(.+?)(?:\s+on\s|\s+in\s|\.\s|$)',
          isBuiltIn: true,
          createdAt: now,
        ),
        ScannerPattern(
          id: 'builtin_bank_ar_1',
          name: 'scanner_pattern_bank_ar',
          senderMatch: '*',
          amountRegex:
              r'(\d{1,3}(?:,\d{3})*(?:\.\d{1,2})?)\s*(?:\u0631\.\u0633|\u0631\u064A\u0627\u0644|\u062F.\u0625|\u062F\u0631\u0647\u0645)',
          currencyRegex:
              r'(\u0631.\u0633|\u0631\u064A\u0627\u0644|\u062F.\u0625|\u062F\u0631\u0647\u0645|\u062F.\u0643|\u062F.\u0628|\u0631.\u0639|\u0631.\u0642|\u062C.\u0645)',
          cardRegex: r'\*(\d{4})',
          merchantRegex:
              r'(?:\u0639\u0646\u062F|\u0641\u064A|\u0644\u062F\u0649)\s+(.+?)(?:\s|$)',
          isBuiltIn: true,
          createdAt: now,
        ),
        ScannerPattern(
          id: 'builtin_amount_generic',
          name: 'scanner_pattern_generic_amount',
          senderMatch: '*',
          amountRegex: r'(\d{1,3}(?:,\d{3})*\.\d{2})',
          isBuiltIn: true,
          createdAt: now,
        ),
      ];

      for (final p in builtIns) {
        await repo.upsertPattern(p);
      }
      _seeded = true;
    } catch (e, st) {
      Log.warning('Failed to seed built-in patterns', error: e, stackTrace: st);
    }
  }

  Future<void> _flushPending() async {
    try {
      final notifications = await NotificationBridge.getPendingNotifications();
      if (notifications.isEmpty) return;

      final repo = _ref.read(scannerRepositoryProvider);
      final patterns = await repo.getEnabledPatterns();
      final extraRules = await repo.getCategoryRules();
      final senderRules = await repo.getSenderRules();
      final existingDrafts = await repo.getRecentDrafts(limit: 50);
      final settings = _ref.read(hisabSettingsProvidersProvider);
      final categorize =
          settings?.controller.get(scannerCategorizeEnabledSettingDef) == true;
      final defaultGroupId =
          (settings?.controller.get(scannerDefaultGroupIdSettingDef) ?? '')
              .toString();

      for (final notif in notifications) {
        final alreadyLogged = await repo.hasNotificationLog(
          senderPackage: notif.senderPackage,
          postedAt: notif.postedAt,
          rawText: notif.body,
        );
        if (alreadyLogged) {
          await NotificationBridge.markFlushed([notif.nativeId]);
          continue;
        }

        var result = TransactionParser.parse(
          notif.body,
          customPatterns: patterns,
          notificationDate: notif.postedAt,
          senderPackage: notif.senderPackage,
        );

        if (result.skipReason == ParseSkipReason.otp) {
          await repo.insertLog(
            ScannerNotificationLog(
              id: _uuid.v4(),
              senderPackage: notif.senderPackage,
              senderTitle: notif.senderTitle,
              rawText: notif.body,
              postedAt: notif.postedAt,
              capturedAt: notif.capturedAt,
              outcome: ScannerLogOutcome.ignoredOtp,
              reason: 'otp',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );
          await NotificationBridge.markFlushed([notif.nativeId]);
          continue;
        }

        result = await _maybeEnrichWithAi(notif.body, result);

        final category = categorize
            ? (result.suggestedCategory ??
                  suggestCategory(
                    merchant: result.merchantName,
                    place: result.placeName,
                    senderTitle: notif.senderTitle,
                    rawText: notif.body,
                    extraRules: extraRules,
                  ))
            : null;

        if (result.amountCents == null || result.amountCents == 0) {
          await repo.insertLog(
            ScannerNotificationLog(
              id: _uuid.v4(),
              senderPackage: notif.senderPackage,
              senderTitle: notif.senderTitle,
              rawText: notif.body,
              postedAt: notif.postedAt,
              capturedAt: notif.capturedAt,
              outcome: ScannerLogOutcome.ignoredNoAmount,
              reason: 'no_amount',
              merchantName: result.merchantName,
              placeName: result.placeName,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );
          await NotificationBridge.markFlushed([notif.nativeId]);
          continue;
        }

        final sender = senderRules
            .where((r) => r.packageName == notif.senderPackage)
            .firstOrNull;
        final groups = await _ref.read(groupRepositoryProvider).getAll();
        final targetId = resolveScannerDestination(
          senderTargetGroupId: sender?.targetGroupId,
          draftTargetGroupId: null,
          defaultGroupId: defaultGroupId,
          groups: groups,
        );

        final draft = DraftTransaction(
          id: _uuid.v4(),
          targetGroupId: targetId,
          amountCents: result.amountCents!,
          currencyCode: result.currencyCode ?? 'SAR',
          cardLastFour: result.cardLastFour,
          merchantName: result.merchantName,
          merchantCategory: category,
          placeName: result.placeName,
          fieldSpans: result.fieldSpans,
          transactionDate: result.transactionDate ?? notif.postedAt,
          capturedAt: notif.capturedAt,
          rawNotificationText: notif.body,
          senderPackage: notif.senderPackage,
          senderTitle: notif.senderTitle,
          matchedPatternId: result.matchedPatternId,
          confidence: result.confidence,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final isDupe = DuplicateDetector.isDuplicate(draft, existingDrafts);
        final saved = await repo.insertDraft(
          isDupe ? draft.copyWith(status: DraftStatus.duplicate) : draft,
        );
        existingDrafts.add(saved);

        await repo.insertLog(
          ScannerNotificationLog(
            id: _uuid.v4(),
            senderPackage: notif.senderPackage,
            senderTitle: notif.senderTitle,
            rawText: notif.body,
            postedAt: notif.postedAt,
            capturedAt: notif.capturedAt,
            outcome: isDupe
                ? ScannerLogOutcome.ignoredDuplicate
                : ScannerLogOutcome.pending,
            reason: isDupe ? 'duplicate' : null,
            amountCents: draft.amountCents,
            currencyCode: draft.currencyCode,
            merchantName: draft.merchantName,
            placeName: draft.placeName,
            draftId: saved.id,
            targetGroupId: targetId,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

        if (result.matchedPatternId != null) {
          await repo.incrementPatternSuccess(result.matchedPatternId!);
        }
        await repo.incrementSenderMatchCount(notif.senderPackage);

        await NotificationBridge.markFlushed([notif.nativeId]);
      }

      _invalidateScanner();
    } catch (e, st) {
      Log.error('Scanner flush failed', error: e, stackTrace: st);
    }
  }

  Future<ParseResult> _maybeEnrichWithAi(String body, ParseResult result) async {
    final settings = _ref.read(hisabSettingsProvidersProvider);
    if (settings == null) return result;
    final mode =
        settings.controller.get(scannerAiModeSettingDef) as String? ?? 'off';
    if (mode == 'off') return result;
    final categorize =
        settings.controller.get(scannerCategorizeEnabledSettingDef) == true;
    final missingField =
        result.amountCents == null ||
        result.merchantName == null ||
        result.placeName == null;
    if (!categorize && !missingField && result.confidence >= 0.5) {
      return result;
    }
    if (result.confidence >= 0.7 && !missingField) return result;

    final provider =
        settings.controller.get(receiptAiProviderSettingDef) as String?;
    final apiKey = provider == 'openai'
        ? settings.controller.get(openaiApiKeySettingDef) as String?
        : settings.controller.get(geminiApiKeySettingDef) as String?;

    final ai = await classifyNotification(
      body: body,
      mode: mode,
      provider: provider,
      apiKey: apiKey,
    ).timeout(const Duration(seconds: 8), onTimeout: () => null);
    if (ai == null) return result;
    return mergeAiIntoParse(result, ai);
  }

  /// Confirm a draft and create a real expense in the chosen group.
  ///
  /// Returns `false` when the expense could not be created.
  Future<bool> confirmDraft(
    String draftId, {
    String? personalGroupId,
    String? targetGroupId,
    String? overrideMerchant,
    int? overrideAmountCents,
    String? overridePlace,
    String? overrideCategory,
  }) async {
    var ok = false;
    try {
      final scannerRepo = _ref.read(scannerRepositoryProvider);
      final draft = await scannerRepo.getDraftById(draftId);
      if (draft == null) {
        throw StateError('Draft $draftId not found');
      }

      final senderRules = await scannerRepo.getSenderRules();
      final sender = senderRules
          .where((r) => r.packageName == draft.senderPackage)
          .firstOrNull;
      final settings = _ref.read(hisabSettingsProvidersProvider);
      final defaultGroupId =
          (settings?.controller.get(scannerDefaultGroupIdSettingDef) ?? '')
              .toString();
      final groups = await _ref.read(groupRepositoryProvider).getAll();
      final groupId = resolveScannerDestination(
        explicitGroupId: targetGroupId ?? personalGroupId,
        senderTargetGroupId: sender?.targetGroupId,
        draftTargetGroupId: draft.targetGroupId,
        defaultGroupId: defaultGroupId,
        groups: groups,
      );

      if (groupId == null) {
        Log.warning('No destination group found for scanner draft confirm');
        return false;
      }

      final group = groups.where((g) => g.id == groupId).firstOrNull;
      if (group == null) return false;

      final currentUserId = _ref.read(authServiceProvider).currentUser?.id;
      final isOwner = group.ownerId != null && group.ownerId == currentUserId;
      if (!canAddScannerExpense(group, isOwner: isOwner)) {
        Log.warning('Cannot add scanner expense to group $groupId');
        return false;
      }

      final participantRepo = _ref.read(participantRepositoryProvider);
      final participants = (await participantRepo.getByGroupId(groupId))
          .where((p) => p.leftAt == null)
          .toList();
      if (participants.isEmpty) {
        Log.warning('No participant in group $groupId');
        return false;
      }

      var payerId = participants
          .where((p) => currentUserId != null && p.userId == currentUserId)
          .firstOrNull
          ?.id;
      if (payerId == null && currentUserId != null) {
        final member = await _ref
            .read(groupMemberRepositoryProvider)
            .getMyMember(groupId);
        final pid = member?.participantId;
        if (pid != null && participants.any((p) => p.id == pid)) {
          payerId = pid;
        }
      }
      payerId ??= participants.first.id;

      final merchant =
          overrideMerchant ?? draft.merchantName ?? draft.displayTitle;
      final cents = overrideAmountCents ?? draft.amountCents;
      final place = overridePlace ?? draft.placeName;
      final category = overrideCategory ?? draft.merchantCategory;
      final absCents = cents.abs();
      final shares = equalSplitShares(
        participants.map((p) => p.id).toList(),
        absCents,
      );

      if (category != null &&
          merchant.isNotEmpty &&
          category != draft.merchantCategory) {
        await scannerRepo.upsertCategoryRule(
          ScannerCategoryRule(
            id: _uuid.v4(),
            merchantPattern: merchant,
            categoryId: category,
            source: CategoryRuleSource.learned,
            createdAt: DateTime.now(),
          ),
        );
      }

      final expense = Expense(
        id: '',
        groupId: groupId,
        payerParticipantId: payerId,
        amountCents: absCents,
        currencyCode: draft.currencyCode,
        title: merchant,
        description: place,
        date: draft.transactionDate,
        splitType: SplitType.equal,
        splitShares: shares,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        transactionType: cents < 0
            ? TransactionType.income
            : TransactionType.expense,
        tag: category,
      );

      final expenseRepo = _ref.read(expenseRepositoryProvider);
      final expenseId = await expenseRepo.create(expense);
      await scannerRepo.updateDraftStatus(
        draftId,
        DraftStatus.confirmed,
        createdExpenseId: expenseId,
      );
      await scannerRepo.updateLogOutcomeForDraft(
        draftId,
        ScannerLogOutcome.added,
        createdExpenseId: expenseId,
        targetGroupId: groupId,
      );
      ok = true;
    } catch (e, st) {
      Log.error('Failed to confirm draft $draftId', error: e, stackTrace: st);
    }
    _invalidateScanner();
    return ok;
  }

  Future<void> dismissDraft(String draftId) async {
    final repo = _ref.read(scannerRepositoryProvider);
    await repo.updateDraftStatus(draftId, DraftStatus.dismissed);
    await repo.updateLogOutcomeForDraft(draftId, ScannerLogOutcome.dismissed);
    _invalidateScanner();
  }

  Future<void> promoteLogToDraft(ScannerNotificationLog log) async {
    if (log.amountCents == null || log.amountCents == 0) return;
    final repo = _ref.read(scannerRepositoryProvider);
    final now = DateTime.now();
    final draft = await repo.insertDraft(
      DraftTransaction(
        id: _uuid.v4(),
        targetGroupId: log.targetGroupId,
        amountCents: log.amountCents!,
        currencyCode: log.currencyCode ?? 'SAR',
        merchantName: log.merchantName,
        placeName: log.placeName,
        transactionDate: log.postedAt,
        capturedAt: log.capturedAt,
        rawNotificationText: log.rawText,
        senderPackage: log.senderPackage,
        senderTitle: log.senderTitle,
        createdAt: now,
        updatedAt: now,
      ),
    );
    await repo.updateLog(
      log.copyWith(
        outcome: ScannerLogOutcome.pending,
        draftId: draft.id,
        updatedAt: now,
      ),
    );
    _invalidateScanner();
  }

  Future<void> syncSendersToNative() async {
    if (!scannerAvailable) return;
    final repo = _ref.read(scannerRepositoryProvider);
    final rules = await repo.getEnabledSenderRules();
    // Always require a whitelist. An empty list captures nothing — including
    // before setup, when leftover native prefs would otherwise ingest every app.
    await NotificationBridge.setRequireSenders(true);
    await NotificationBridge.setSenders(
      rules.map((r) => r.packageName).toList(),
    );
  }

  void _invalidateScanner() {
    _ref.invalidate(pendingDraftCountProvider);
    _ref.invalidate(pendingDraftsProvider);
    _ref.invalidate(pendingDraftCountByGroupProvider);
    _ref.invalidate(scannerLogSummaryProvider);
    _ref.invalidate(scannerNotificationLogProvider);
    _ref.invalidate(scannerCategoryRulesProvider);
  }

  void dispose() {
    _eventSub?.cancel();
  }
}
