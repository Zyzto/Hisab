import 'dart:async';

import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter_logging_service/flutter_logging_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/database_providers.dart';
import '../../../core/repository/repository_providers.dart';
import '../../../domain/domain.dart';
import '../../settings/providers/settings_framework_providers.dart';
import '../../settings/settings_definitions.dart';
import '../domain/draft_transaction.dart';
import '../domain/sender_rule.dart';
import '../domain/scanner_pattern.dart';
import '../repository/scanner_repository.dart';
import '../services/duplicate_detector.dart';
import '../services/notification_bridge.dart';
import '../services/transaction_parser.dart';

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

/// All pending draft transactions.
final pendingDraftsProvider =
    FutureProvider<List<DraftTransaction>>((ref) async {
  final repo = ref.watch(scannerRepositoryProvider);
  return repo.getPendingDrafts();
});

/// All sender rules.
final senderRulesProvider = FutureProvider<List<SenderRule>>((ref) async {
  final repo = ref.watch(scannerRepositoryProvider);
  return repo.getSenderRules();
});

/// All scanner patterns.
final scannerPatternsProvider =
    FutureProvider<List<ScannerPattern>>((ref) async {
  final repo = ref.watch(scannerRepositoryProvider);
  return repo.getPatterns();
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
          name: 'Bank SMS (EN)',
          senderMatch: '*',
          amountRegex: r'(?:SAR|USD|EUR|GBP|AED)\s*(\d{1,3}(?:,\d{3})*(?:\.\d{1,2})?)',
          currencyRegex: r'\b(SAR|USD|EUR|GBP|AED|KWD|BHD|OMR|QAR|EGP)\b',
          cardRegex: r'\*(\d{4})',
          merchantRegex: r'(?:at|from|to)\s+(.+?)(?:\s+on\s|\.\s|$)',
          isBuiltIn: true,
          createdAt: now,
        ),
        ScannerPattern(
          id: 'builtin_bank_ar_1',
          name: 'Bank SMS (AR)',
          senderMatch: '*',
          amountRegex: r'(\d{1,3}(?:,\d{3})*(?:\.\d{1,2})?)\s*(?:\u0631\.\u0633|\u0631\u064A\u0627\u0644|\u062F\.\u0625|\u062F\u0631\u0647\u0645)',
          currencyRegex: r'(\u0631\.\u0633|\u0631\u064A\u0627\u0644|\u062F\.\u0625|\u062F\u0631\u0647\u0645|\u062F\.\u0643|\u062F\.\u0628|\u0631\.\u0639|\u0631\.\u0642|\u062C\.\u0645)',
          cardRegex: r'\*(\d{4})',
          merchantRegex: r'(?:\u0639\u0646\u062F|\u0641\u064A|\u0644\u062F\u0649)\s+(.+?)(?:\s|$)',
          isBuiltIn: true,
          createdAt: now,
        ),
        ScannerPattern(
          id: 'builtin_amount_generic',
          name: 'Generic Amount',
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
      final existingDrafts = await repo.getRecentDrafts(limit: 50);
      final flushedIds = <int>[];

      for (final notif in notifications) {
        final result = TransactionParser.parse(
          notif.body,
          customPatterns: patterns,
          notificationDate: notif.postedAt,
        );

        if (result.amountCents == null || result.amountCents == 0) {
          flushedIds.add(notif.nativeId);
          continue;
        }

        final draft = DraftTransaction(
          id: _uuid.v4(),
          amountCents: result.amountCents!,
          currencyCode: result.currencyCode ?? 'SAR',
          cardLastFour: result.cardLastFour,
          merchantName: result.merchantName,
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

        if (result.matchedPatternId != null) {
          await repo.incrementPatternSuccess(result.matchedPatternId!);
        }
        await repo.incrementSenderMatchCount(notif.senderPackage);

        flushedIds.add(notif.nativeId);
      }

      if (flushedIds.isNotEmpty) {
        await NotificationBridge.markFlushed(flushedIds);
      }

      _ref.invalidate(pendingDraftCountProvider);
      _ref.invalidate(pendingDraftsProvider);
    } catch (e, st) {
      Log.error('Scanner flush failed', error: e, stackTrace: st);
    }
  }

  /// Confirm a draft and create a real expense in the personal budget.
  ///
  /// If [personalGroupId] is null, the first personal group is used.
  /// If [overrideMerchant] or [overrideAmountCents] are provided, they
  /// replace the parsed values.
  Future<void> confirmDraft(
    String draftId, {
    String? personalGroupId,
    String? overrideMerchant,
    int? overrideAmountCents,
  }) async {
    try {
      final scannerRepo = _ref.read(scannerRepositoryProvider);
      final drafts = await scannerRepo.getRecentDrafts(limit: 500);
      final draft = drafts.firstWhere(
        (d) => d.id == draftId,
        orElse: () => throw StateError('Draft $draftId not found'),
      );

      String? groupId = personalGroupId ?? draft.personalGroupId;
      if (groupId == null) {
        final groupRepo = _ref.read(groupRepositoryProvider);
        final groups = await groupRepo.getAll();
        final personal = groups.where((g) => g.isPersonal).toList();
        if (personal.isNotEmpty) {
          groupId = personal.first.id;
        }
      }

      if (groupId == null) {
        Log.warning('No personal group found for scanner draft confirm');
        await scannerRepo.updateDraftStatus(draftId, DraftStatus.confirmed);
        _ref.invalidate(pendingDraftCountProvider);
        _ref.invalidate(pendingDraftsProvider);
        return;
      }

      final participantRepo = _ref.read(participantRepositoryProvider);
      final participants = await participantRepo.getByGroupId(groupId);
      if (participants.isEmpty) {
        Log.warning('No participant in personal group $groupId');
        await scannerRepo.updateDraftStatus(draftId, DraftStatus.confirmed);
        _ref.invalidate(pendingDraftCountProvider);
        _ref.invalidate(pendingDraftsProvider);
        return;
      }

      final merchant =
          overrideMerchant ?? draft.merchantName ?? draft.displayTitle;
      final cents = overrideAmountCents ?? draft.amountCents;

      final expense = Expense(
        id: '',
        groupId: groupId,
        payerParticipantId: participants.first.id,
        amountCents: cents.abs(),
        currencyCode: draft.currencyCode,
        title: merchant,
        date: draft.transactionDate,
        splitType: SplitType.equal,
        splitShares: {participants.first.id: cents.abs()},
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        transactionType:
            cents < 0 ? TransactionType.income : TransactionType.expense,
        tag: draft.merchantCategory,
      );

      final expenseRepo = _ref.read(expenseRepositoryProvider);
      final expenseId = await expenseRepo.create(expense);
      await scannerRepo.updateDraftStatus(
        draftId,
        DraftStatus.confirmed,
        createdExpenseId: expenseId,
      );
    } catch (e, st) {
      Log.error('Failed to confirm draft $draftId', error: e, stackTrace: st);
    }
    _ref.invalidate(pendingDraftCountProvider);
    _ref.invalidate(pendingDraftsProvider);
  }

  Future<void> dismissDraft(String draftId) async {
    final repo = _ref.read(scannerRepositoryProvider);
    await repo.updateDraftStatus(draftId, DraftStatus.dismissed);
    _ref.invalidate(pendingDraftCountProvider);
    _ref.invalidate(pendingDraftsProvider);
  }

  Future<void> syncSendersToNative() async {
    final repo = _ref.read(scannerRepositoryProvider);
    final rules = await repo.getEnabledSenderRules();
    await NotificationBridge.setSenders(
      rules.map((r) => r.packageName).toList(),
    );
  }

  void dispose() {
    _eventSub?.cancel();
  }
}
