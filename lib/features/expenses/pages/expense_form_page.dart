import 'dart:typed_data';

import 'package:currency_picker/currency_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_logging_service/flutter_logging_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:custom_sliding_segmented_control/custom_sliding_segmented_control.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../../../core/receipt/receipt_image_compress.dart';
import '../../../core/receipt/receipt_image_cache.dart';
import '../../../core/receipt/receipt_ocr.dart';
import '../../../core/receipt/receipt_scan_capability.dart';
import '../../../core/receipt/receipt_scan_service.dart';
import '../../../core/receipt/receipt_storage_upload.dart';
import '../../../core/platform_utils.dart';
import '../../../core/services/connectivity_service.dart';
import '../../../core/services/permission_service.dart';
import '../../../core/auth/auth_providers.dart';
import '../../../core/celebration/celebration_controller.dart';
import '../../../core/celebration/celebration_kind.dart';
import '../../../core/repository/repository_providers.dart';
import '../../../core/services/exchange_rate_service.dart';
import '../../../core/telemetry/telemetry_service.dart';
import '../../../core/layout/content_aligned_app_bar.dart';
import '../../../core/layout/constrained_content.dart';
import '../../../core/layout/layout_breakpoints.dart';
import '../../../core/layout/responsive_sheet.dart';
import '../../../core/navigation/last_route_restore.dart';
import '../../../core/navigation/nav_back.dart';
import '../../../core/navigation/route_paths.dart';
import '../../../core/navigation/route_transition_ready.dart';
import '../../../core/widgets/missing_route_page.dart';
import '../../../core/theme/accent_style.dart';
import '../../../core/utils/currency_helpers.dart';
import '../../../core/utils/error_report_helper.dart';
import '../../../core/utils/form_validators.dart';
import '../../../core/widgets/error_content.dart';
import '../../../core/widgets/expandable_section.dart';
import '../../../core/widgets/participant_avatar.dart';
import '../../../core/widgets/sheet_helpers.dart';
import '../../../core/widgets/toast.dart';
import '../../../core/widgets/user_text.dart';
import 'package:hisab/core/settings/providers/settings_framework_providers.dart';
import 'package:hisab/core/settings/settings_definitions.dart';
import '../../balance/providers/balance_provider.dart';
import '../../groups/providers/group_member_provider.dart';
import '../../groups/providers/groups_provider.dart';
import '../camera/receipt_camera_debug.dart';
import '../camera/show_receipt_camera.dart';
import '../category_icons.dart';
import '../constants/expense_form_constants.dart';
import '../widgets/create_tag_sheet.dart';
import '../widgets/expense_amount_section.dart';
import '../widgets/expense_bill_breakdown_section.dart';
import '../widgets/expense_title_section.dart';
import '../widgets/date_time_picker_dialog.dart';
import '../widgets/expense_photo_gallery.dart';
import '../widgets/expense_form_photos_section.dart';
import '../widgets/expense_split_section.dart';
import '../../../domain/domain.dart';

part 'expense_form_exchange.dart';
part 'expense_form_photo_actions.dart';
part 'expense_form_split_logic.dart';

/// Height of the floating submit bar (button + padding) for ListView bottom padding.
const double _kSubmitBarHeight = 76.0;
const double _kSubmitBarExtraBottomPadding = 20.0;

class ExpenseFormPage extends ConsumerStatefulWidget {
  final String groupId;
  final String? expenseId;

  const ExpenseFormPage({super.key, required this.groupId, this.expenseId});

  @override
  ConsumerState<ExpenseFormPage> createState() => _ExpenseFormPageState();
}

class _ExpenseFormPageState extends ConsumerState<ExpenseFormPage>
    with
        RouteTransitionReady,
        _ExpenseFormExchangeMixin,
        _ExpenseFormPhotoActionsMixin,
        _ExpenseFormSplitLogicMixin {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  String _currencyCode = 'USD';
  String _groupCurrencyCode = 'USD';
  DateTime _date = DateTime.now();
  String? _payerParticipantId;
  String? _toParticipantId;
  SplitType _splitType = SplitType.equal;
  TransactionType _transactionType = TransactionType.expense;

  /// Stable seed for [CustomSlidingSegmentedControl.initialValue]. The package
  /// ignores the controller's constructor value and defaults the thumb to the
  /// first segment unless [initialValue] is set.
  late TransactionType _transactionTypeSegmentInitial;
  late final CustomSegmentedController<TransactionType>
  _transactionTypeSegmentController;
  bool _saving = false;

  bool _groupCurrencyInitialized = false;

  /// When editing, the loaded expense (for id and createdAt on update).
  Expense? _initialExpense;
  bool _editLoaded = false;

  /// Participant ids included in the split (default all). Unchecking excludes them.
  final Set<String> _includedInSplitIds = {};

  /// Participant ids we've already seen (so we only auto-include newly added participants).
  Set<String> _previousParticipantIds = {};

  /// Selected category/tag: preset id (e.g. 'food') or custom tag id (ExpenseTag.id).
  String? _selectedTag;

  /// Optional bill/receipt breakdown (description + amount per line).
  List<ReceiptLineItem> _lineItems = [];

  /// Controllers for bill breakdown rows (one desc + amount per line).
  final List<({TextEditingController desc, TextEditingController amount})>
  _lineItemControllers = [];

  /// One soft retry when group stream briefly yields null (e.g. after camera kill).
  bool _nullGroupRetryDone = false;

  String get _formBackPath {
    final expenseId = widget.expenseId;
    if (expenseId != null) {
      return RoutePaths.groupExpenseDetail(widget.groupId, expenseId);
    }
    return RoutePaths.groupExpenses(widget.groupId);
  }

  String get _formRoutePath {
    final expenseId = widget.expenseId;
    if (expenseId != null) {
      return RoutePaths.groupExpenseEdit(widget.groupId, expenseId);
    }
    return RoutePaths.groupExpenseAdd(widget.groupId);
  }

  void _popForm() => popOrGo(context, _formBackPath);

  @override
  void initState() {
    super.initState();
    _transactionTypeSegmentInitial = _transactionType;
    _transactionTypeSegmentController =
        CustomSegmentedController<TransactionType>(value: _transactionType);
    _initExchangeAmountListener();
    if (widget.expenseId != null) {
      _loadExpenseForEdit();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      seedParentHistoryForBrowserBack(
        context: context,
        parentPath: _formBackPath,
        currentPath: _formRoutePath,
      );
      // Backup if the first build had no ModalRoute yet.
      ensureRouteReady(context, onReady: _recoverLostPickerImage);
    });
  }

  Future<void> _loadExpenseForEdit() async {
    final expense = await ref
        .read(expenseRepositoryProvider)
        .getById(widget.expenseId!);
    if (!mounted || expense == null || expense.groupId != widget.groupId) {
      return;
    }
    final group = await ref
        .read(groupRepositoryProvider)
        .getById(widget.groupId);
    final participants = await ref
        .read(participantRepositoryProvider)
        .getByGroupId(widget.groupId);
    if (!mounted) return;
    _amountController.removeListener(_amountListener);
    setState(() {
      _initialExpense = expense;
      _currencyCode = expense.currencyCode;
      _exchangeRate = expense.exchangeRate;
      if (expense.exchangeRate != 1.0) {
        _exchangeRateController.text = expense.exchangeRate.toStringAsFixed(4);
      }
      if (expense.baseAmountCents != null) {
        _baseAmountController.text = (expense.baseAmountCents! / 100)
            .toStringAsFixed(2);
      }
      _titleController.text = expense.title;
      _descriptionController.text = expense.description ?? '';
      _amountController.text = (expense.amountCents / 100).toStringAsFixed(2);
      _date = expense.date.toLocal();
      _payerParticipantId = expense.payerParticipantId;
      _transactionType =
          (group?.isPersonal == true &&
              expense.transactionType == TransactionType.transfer)
          ? TransactionType.expense
          : expense.transactionType;
      _transactionTypeSegmentInitial = _transactionType;
      _transactionTypeSegmentController.value = _transactionType;
      _splitType = expense.splitType;
      _toParticipantId = expense.toParticipantId;
      _includedInSplitIds.addAll(expense.splitShares.keys);
      _previousParticipantIds = participants.map((p) => p.id).toSet();
      final total = expense.amountCents;
      if (expense.splitType == SplitType.amounts) {
        for (final entry in expense.splitShares.entries) {
          _customSplitValues[entry.key] = (entry.value / 100).toStringAsFixed(
            2,
          );
        }
      } else if (expense.splitType == SplitType.parts && total > 0) {
        final sum = expense.splitShares.values.fold<int>(0, (a, b) => a + b);
        if (sum > 0) {
          for (final entry in expense.splitShares.entries) {
            final part = (entry.value * 10 / sum).round().clamp(1, 999);
            _customSplitValues[entry.key] = part.toString();
          }
        }
      }
      _amountsFieldsTouched = true;
      _selectedTag = expense.tag;
      _lineItems = expense.lineItems != null
          ? List.from(expense.lineItems!)
          : [];
      for (final item in _lineItems) {
        _lineItemControllers.add((
          desc: TextEditingController(text: item.description),
          amount: TextEditingController(
            text: item.amountCents > 0
                ? (item.amountCents / 100).toStringAsFixed(2)
                : '',
          ),
        ));
      }
      _expenseImages.clear();
      for (final url in expense.effectiveImageUrls) {
        _expenseImages.add((bytes: null, url: url));
      }
      _editLoaded = true;
    });
    _amountController.addListener(_amountListener);
  }

  @override
  void dispose() {
    disposeRouteReady();
    _scanCancel?.cancel();
    _scanCancel = null;
    cancelReceiptOcr();
    _disposeExchangeControllers();
    _titleController.dispose();
    _descriptionController.dispose();
    _amountController.dispose();
    _disposeSplitControllers();
    for (final c in _lineItemControllers) {
      c.desc.dispose();
      c.amount.dispose();
    }
    _lineItemControllers.clear();
    _transactionTypeSegmentController.dispose();
    super.dispose();
  }

  void _syncLineItemControllersFromItems() {
    for (final c in _lineItemControllers) {
      c.desc.dispose();
      c.amount.dispose();
    }
    _lineItemControllers
      ..clear()
      ..addAll(
        _lineItems.map(
          (item) => (
            desc: TextEditingController(text: item.description),
            amount: TextEditingController(
              text: item.amountCents > 0
                  ? (item.amountCents / 100).toStringAsFixed(2)
                  : '',
            ),
          ),
        ),
      );
  }

  Widget _formPanel(BuildContext context, {required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: AccentSurfaces.flatPanel(Theme.of(context).colorScheme),
      child: child,
    );
  }

  void _defocusFormInputs() {
    FocusManager.instance.primaryFocus?.unfocus();
  }

  void _openExpenseCurrencyPicker() {
    _defocusFormInputs();
    final stored = ref.read(favoriteCurrenciesProvider);
    final favorites = CurrencyHelpers.getEffectiveFavorites(stored);
    CurrencyHelpers.showPicker(
      context: context,
      favorite: favorites,
      onSelect: (Currency currency) {
        if (currency.code == _currencyCode) return;
        setState(() {
          _currencyCode = currency.code;
          if (_isDifferentCurrency) {
            _fetchLiveRate();
          } else {
            _exchangeRate = 1.0;
            _exchangeRateController.clear();
            _baseAmountController.clear();
          }
        });
      },
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final amountText = _amountController.text.trim();
    final amount = (double.tryParse(amountText) ?? 0) * 100;
    if (amount <= 0) {
      context.showToast('amount_positive'.tr());
      return;
    }
    final participants = await ref
        .read(participantRepositoryProvider)
        .getByGroupId(widget.groupId);
    if (!mounted) return;
    if (participants.isEmpty) {
      context.showToast('add_participants_first'.tr());
      return;
    }

    final group = await ref
        .read(groupRepositoryProvider)
        .getById(widget.groupId);
    if (!mounted || group == null) return;
    final localOnly = ref.read(effectiveLocalOnlyProvider);
    final myRole = await ref.read(myRoleInGroupProvider(widget.groupId).future);
    if (!mounted) return;
    final isOwnerOrAdmin =
        localOnly || myRole == GroupRole.owner || myRole == GroupRole.admin;
    final canAddExpense = isOwnerOrAdmin || group.allowMemberAddExpense;
    if (!canAddExpense) {
      context.showToast('add_expense_restricted'.tr());
      return;
    }
    if (group.isArchived) {
      context.showToast('add_expense_blocked_archived'.tr());
      return;
    }
    final restrictPayerToSelf =
        !group.allowExpenseAsOtherParticipant && !isOwnerOrAdmin;
    final currentUserId = ref.read(authServiceProvider).currentUser?.id;
    var myParticipantId = participants
        .where((p) => p.userId == currentUserId)
        .firstOrNull
        ?.id;
    if (myParticipantId == null) {
      final myMember = await ref.read(
        myMemberInGroupProvider(widget.groupId).future,
      );
      final pid = myMember?.participantId;
      if (pid != null && participants.any((p) => p.id == pid)) {
        myParticipantId = pid;
      }
    }
    final payerId = restrictPayerToSelf
        ? (myParticipantId ?? participants.first.id)
        : (_payerParticipantId ?? participants.first.id);
    final effectiveTransactionType =
        group.isPersonal && _transactionType == TransactionType.transfer
        ? TransactionType.expense
        : _transactionType;
    final isTransfer = effectiveTransactionType == TransactionType.transfer;
    if (isTransfer) {
      if (_toParticipantId == null || _toParticipantId == payerId) {
        if (!mounted) return;
        context.showToast('choose_different_to'.tr());
        return;
      }
    }

    final included = participants
        .where((p) => _includedInSplitIds.contains(p.id))
        .toList();
    if (!isTransfer && included.isEmpty) {
      if (!mounted) return;
      context.showToast('include_at_least_one'.tr());
      return;
    }

    Map<String, int> splitShares;
    if (isTransfer) {
      splitShares = {};
    } else {
      final n = included.length;
      switch (_splitType) {
        case SplitType.equal:
          final each = (amount / n).round();
          final remainder = amount.toInt() - each * n;
          splitShares = {};
          for (var i = 0; i < n; i++) {
            splitShares[included[i].id] = each + (i < remainder ? 1 : 0);
          }
          break;
        case SplitType.parts:
          splitShares = {};
          double sumParts = 0;
          for (final p in included) {
            final text = _customSplitValues[p.id]?.trim() ?? '';
            final part = double.tryParse(text);
            sumParts += (part != null && part >= 0) ? part : 0;
          }
          if (sumParts <= 0) {
            final each = amount.toInt() ~/ n;
            final remainder = amount.toInt() - each * n;
            for (var i = 0; i < n; i++) {
              splitShares[included[i].id] = each + (i < remainder ? 1 : 0);
            }
          } else {
            var assigned = 0;
            for (var i = 0; i < included.length; i++) {
              final p = included[i];
              final text = _customSplitValues[p.id]?.trim() ?? '';
              final part = double.tryParse(text);
              final v = (part != null && part >= 0) ? part : 0.0;
              final cents = (amount * v / sumParts).round();
              splitShares[p.id] = cents;
              assigned += cents;
            }
            final diff = amount.toInt() - assigned;
            if (diff != 0 && included.isNotEmpty) {
              splitShares[included[0].id] = splitShares[included[0].id]! + diff;
            }
          }
          break;
        case SplitType.amounts:
          splitShares = {};
          final totalCents = amount.toInt();
          var sumCents = 0;
          for (final p in included) {
            final text = _customSplitValues[p.id]?.trim() ?? '';
            final value = double.tryParse(text);
            final cents = value != null && value >= 0
                ? (value * 100).round()
                : 0;
            sumCents += cents;
            splitShares[p.id] = cents;
          }
          if (sumCents != totalCents) {
            if (mounted) {
              context.showToast('amounts_must_equal_total'.tr());
              setState(() => _saving = false);
            }
            return;
          }
          break;
      }
    }

    setState(() => _saving = true);
    var didPop = false;
    try {
      final title = isTransfer ? 'transfer'.tr() : _titleController.text.trim();
      if (!isTransfer && FormValidators.expenseTitle(title) != null) {
        if (mounted) {
          setState(() => _saving = false);
          _formKey.currentState?.validate();
        }
        return;
      }
      final desc = _descriptionController.text.trim();

      // Compute base amount in group currency when currencies differ
      int? baseAmountCents;
      double exchangeRate = 1.0;
      if (_isDifferentCurrency && _exchangeRate > 0) {
        exchangeRate = _exchangeRate;
        final baseAmountText = _baseAmountController.text.trim();
        final baseAmount = double.tryParse(baseAmountText);
        if (baseAmount != null && baseAmount > 0) {
          baseAmountCents = (baseAmount * 100).round();
        } else {
          // Fallback: compute from amount and rate
          baseAmountCents = (amount / _exchangeRate).round();
        }
      }

      final existingExpenseId = _initialExpense?.id ?? '';
      final localOnly = ref.read(effectiveLocalOnlyProvider);
      final isOnline = ref.read(connectivityProvider);
      final shouldUploadPhotos = !localOnly && isOnline;

      final List<String> imageUrls = [];
      for (final item in _expenseImages) {
        // Prefer pending bytes (e.g. after rotate) over a stale stored URL.
        if (item.bytes != null && shouldUploadPhotos) {
          final uploadId = existingExpenseId.isNotEmpty
              ? existingExpenseId
              : '';
          if (uploadId.isEmpty) {
            // New expense: upload after create (below). Keep URL fallback.
            if (item.url != null && item.url!.isNotEmpty) {
              imageUrls.add(item.url!);
            }
            continue;
          }
          final url = await uploadExpenseImageBytesToStorage(
            item.bytes!,
            widget.groupId,
            uploadId,
            fileExt: 'jpg',
          );
          if (url != null) {
            imageUrls.add(url);
            await warmReceiptImageCacheForUrl(url, item.bytes!, fileExt: 'jpg');
          } else if (item.url != null && item.url!.isNotEmpty) {
            imageUrls.add(item.url!);
          }
        } else if (item.url != null && item.url!.isNotEmpty) {
          imageUrls.add(item.url!);
        }
      }
      final imagePaths = imageUrls.isEmpty ? null : imageUrls;
      final imagePath = imageUrls.isNotEmpty ? imageUrls.first : null;

      final expense = Expense(
        id: existingExpenseId,
        groupId: widget.groupId,
        payerParticipantId: payerId,
        amountCents: amount.toInt(),
        currencyCode: _currencyCode,
        exchangeRate: exchangeRate,
        baseAmountCents: baseAmountCents,
        title: title,
        description: desc.isEmpty ? null : desc,
        date: _date,
        splitType: isTransfer ? SplitType.equal : _splitType,
        splitShares: splitShares,
        createdAt: _initialExpense?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
        transactionType: effectiveTransactionType,
        toParticipantId: isTransfer ? _toParticipantId : null,
        tag: _selectedTag,
        lineItems: _effectiveLineItemsForSave(),
        imagePath: imagePath,
        imagePaths: imagePaths,
      );
      if (_initialExpense != null) {
        await ref.read(expenseRepositoryProvider).update(expense);
        ref.invalidate(futureExpenseProvider(expense.id));
        Log.info(
          'Expense updated: id=${expense.id} title="${expense.title}" amountCents=${expense.amountCents}',
        );
      } else {
        final isTransferExpense =
            effectiveTransactionType == TransactionType.transfer;
        var isFirstExpense = false;
        if (!isTransferExpense) {
          final existing = await ref
              .read(expenseRepositoryProvider)
              .getByGroupId(widget.groupId);
          isFirstExpense = existing.every(
            (e) => e.transactionType == TransactionType.transfer,
          );
        }
        final id = await ref.read(expenseRepositoryProvider).create(expense);
        final createdUrls = <String>[];
        for (final item in _expenseImages) {
          if (item.bytes != null && shouldUploadPhotos) {
            final url = await uploadExpenseImageBytesToStorage(
              item.bytes!,
              widget.groupId,
              id,
              fileExt: 'jpg',
            );
            if (url != null) {
              createdUrls.add(url);
              await warmReceiptImageCacheForUrl(
                url,
                item.bytes!,
                fileExt: 'jpg',
              );
            } else if (item.url != null && item.url!.isNotEmpty) {
              createdUrls.add(item.url!);
            }
          } else if (item.url != null && item.url!.isNotEmpty) {
            createdUrls.add(item.url!);
          }
        }
        if (createdUrls.isNotEmpty) {
          await ref
              .read(expenseRepositoryProvider)
              .update(
                expense.copyWith(
                  id: id,
                  imagePath: createdUrls.first,
                  imagePaths: createdUrls,
                ),
              );
        }
        Log.info(
          'Expense created: id=$id groupId=${expense.groupId} title="${expense.title}" amountCents=${expense.amountCents} currencyCode=${expense.currencyCode}',
        );
        try {
          TelemetryService.sendEvent('expense_created', {
            'groupId': expense.groupId,
            'amountCents': expense.amountCents,
          }, enabled: ref.read(telemetryEnabledProvider));
        } catch (e) {
          Log.debug('Telemetry expense_created failed', error: e);
        }
        if (!isTransferExpense && isFirstExpense) {
          await fireCelebration(
            ref,
            CelebrationKind.firstExpense,
            dedupeKey: CelebrationKeys.firstExpense(widget.groupId),
          );
        }
      }
      ref.invalidate(expensesByGroupProvider(widget.groupId));
      ref.invalidate(groupBalanceProvider(widget.groupId));
      if (!mounted) return;
      _popForm();
      didPop = true;
    } catch (e, st) {
      Log.warning('Expense save failed', error: e, stackTrace: st);
    } finally {
      if (!didPop && mounted) setState(() => _saving = false);
    }
  }

  /// Per-participant share in cents for preview (equal split among included only).
  List<int> _splitSharesPreview(
    int totalCents,
    List<Participant> participants,
  ) {
    final included = participants
        .where((p) => _includedInSplitIds.contains(p.id))
        .toList();
    if (included.isEmpty || totalCents <= 0) {
      return List.filled(participants.length, 0);
    }
    final n = included.length;
    final each = totalCents ~/ n;
    final remainder = totalCents - each * n;
    final shareById = <String, int>{};
    for (var i = 0; i < n; i++) {
      shareById[included[i].id] = each + (i < remainder ? 1 : 0);
    }
    return participants.map((p) => shareById[p.id] ?? 0).toList();
  }

  /// Shares in cents: parts = totalCents * (part / sumOfParts), amounts = direct currency entry.
  List<int> _customSharesPreview(
    int totalCents,
    List<Participant> participants,
  ) {
    final result = <int>[];
    if (_splitType == SplitType.parts) {
      double sumParts = 0;
      final parts = <String, double>{};
      for (final p in participants) {
        final text = _customSplitValues[p.id]?.trim() ?? '';
        final part = double.tryParse(text);
        final v = part != null && part >= 0 ? part : 0.0;
        parts[p.id] = v;
        sumParts += v;
      }
      if (sumParts <= 0) {
        return List.filled(participants.length, 0);
      }
      for (final p in participants) {
        result.add((totalCents * (parts[p.id]! / sumParts)).round());
      }
      return result;
    }
    if (_splitType == SplitType.amounts) {
      for (final p in participants) {
        final text = _customSplitValues[p.id]?.trim() ?? '';
        final value = double.tryParse(text);
        result.add(value != null && value >= 0 ? (value * 100).round() : 0);
      }
      return result;
    }
    return List.filled(participants.length, 0);
  }

  /// Sum of amount fields in cents (for amounts split type validation).
  int _amountsSumCents(List<Participant> participants) {
    var sum = 0;
    for (final p in participants) {
      if (!_includedInSplitIds.contains(p.id)) continue;
      final v = double.tryParse(_customSplitValues[p.id]?.trim() ?? '');
      if (v != null && v >= 0) sum += (v * 100).round();
    }
    return sum;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final groupAsync = ref.watch(futureGroupProvider(widget.groupId));
    // New expense: only active participants (left/archived do not count).
    // Edit: all participants so existing payer/to/split names resolve.
    final participantsAsync = ref.watch(
      widget.expenseId == null
          ? activeParticipantsByGroupProvider(widget.groupId)
          : participantsByGroupProvider(widget.groupId),
    );

    return groupAsync.when(
      data: (group) {
        if (group == null) {
          // Do not auto-pop: a brief null after returning from the camera
          // (process pressure / provider reload) was kicking users to the group page.
          if (!_nullGroupRetryDone) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted || _nullGroupRetryDone) return;
              setState(() => _nullGroupRetryDone = true);
              Future<void>.delayed(const Duration(milliseconds: 300), () {
                if (!mounted) return;
                ref.invalidate(futureGroupProvider(widget.groupId));
              });
            });
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          return MissingRoutePage(
            titleKey: 'group_not_found',
            messageKey: 'group_not_found_message',
            fallbackPath: _formBackPath,
          );
        }
        if (group.isSettlementFrozen && widget.expenseId == null) {
          return LayoutBuilder(
            builder: (context, layoutConstraints) {
              return Scaffold(
                appBar: ContentAlignedAppBar(
                  contentAreaWidth: layoutConstraints.maxWidth,
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: _popForm,
                  ),
                  title: Text('add_expense'.tr()),
                ),
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.pause_circle_outline,
                          size: 64,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          (group.isArchived
                                  ? 'add_expense_blocked_archived'
                                  : 'add_expense_blocked_frozen')
                              .tr(),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: _popForm,
                          child: Text('done'.tr()),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        }
        final currencyCode = group.currencyCode;

        return participantsAsync.when(
          data: (participants) {
            // Set group currency once; don't override user's expense currency selection
            if (!_groupCurrencyInitialized) {
              _groupCurrencyCode = group.currencyCode;
              if (widget.expenseId == null) {
                _currencyCode = group.currencyCode;
              }
              _groupCurrencyInitialized = true;
            }
            if (widget.expenseId != null && !_editLoaded) {
              return LayoutBuilder(
                builder: (context, layoutConstraints) {
                  return Scaffold(
                    appBar: ContentAlignedAppBar(
                      contentAreaWidth: layoutConstraints.maxWidth,
                      leading: IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: _popForm,
                      ),
                      title: Text('edit_expense'.tr()),
                    ),
                    body: const Center(child: CircularProgressIndicator()),
                  );
                },
              );
            }
            if (participants.isEmpty) {
              return LayoutBuilder(
                builder: (context, layoutConstraints) {
                  return Scaffold(
                    appBar: ContentAlignedAppBar(
                      contentAreaWidth: layoutConstraints.maxWidth,
                      title: Text(
                        (widget.expenseId != null
                                ? 'edit_expense'
                                : 'add_expense')
                            .tr(),
                      ),
                      leading: IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: _popForm,
                      ),
                    ),
                    body: Center(child: Text('add_participants_first'.tr())),
                  );
                },
              );
            }
            ensureRouteReady(context, onReady: _recoverLostPickerImage);
            final localOnly = ref.watch(effectiveLocalOnlyProvider);
            final myRole = ref
                .watch(myRoleInGroupProvider(widget.groupId))
                .value;
            final restrictPayerToSelf =
                group.isPersonal ||
                (!group.allowExpenseAsOtherParticipant &&
                    (localOnly ||
                        (myRole != GroupRole.owner &&
                            myRole != GroupRole.admin)));
            final currentUserId = ref.read(authServiceProvider).currentUser?.id;
            // Resolve "my" participant: by userId on participant, or by group_members.participant_id (more reliable when joined via invite)
            var myParticipantId = participants
                .where((p) => p.userId == currentUserId)
                .firstOrNull
                ?.id;
            final myMemberAsync = ref.watch(
              myMemberInGroupProvider(widget.groupId),
            );
            if (myParticipantId == null) {
              final pid = myMemberAsync.value?.participantId;
              if (pid != null && participants.any((p) => p.id == pid)) {
                myParticipantId = pid;
              }
            }
            // Sync create defaults on first / updated participants (no post-frame setState).
            final currentIds = participants.map((p) => p.id).toSet();
            final newIds = currentIds.difference(_previousParticipantIds);
            if (newIds.isNotEmpty) {
              _previousParticipantIds = Set.from(currentIds);
              _includedInSplitIds.addAll(newIds);
            } else {
              _previousParticipantIds = Set.from(currentIds);
            }
            if (widget.expenseId == null &&
                _payerParticipantId == null &&
                participants.isNotEmpty) {
              if (myParticipantId != null) {
                _payerParticipantId = myParticipantId;
              } else if (!myMemberAsync.isLoading) {
                _payerParticipantId = participants.first.id;
              }
            }
            final payerId = _payerParticipantId ?? participants.first.id;
            final effectivePayerId = restrictPayerToSelf
                ? (myParticipantId ?? participants.first.id)
                : payerId;

            if (!routeReady) {
              return LayoutBuilder(
                builder: (context, layoutConstraints) {
                  return Scaffold(
                    appBar: ContentAlignedAppBar(
                      contentAreaWidth: layoutConstraints.maxWidth,
                      leading: IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: _popForm,
                      ),
                      title: Text(
                        (widget.expenseId != null
                                ? 'edit_expense'
                                : 'add_expense')
                            .tr(),
                      ),
                    ),
                    body: const SizedBox.shrink(),
                  );
                },
              );
            }

            final isTransfer = _transactionType == TransactionType.transfer;
            final toId =
                _toParticipantId ??
                (participants.length > 1
                    ? participants
                          .firstWhere(
                            (p) => p.id != effectivePayerId,
                            orElse: () => participants.first,
                          )
                          .id
                    : participants.first.id);
            final tagsAsync = ref.watch(tagsByGroupProvider(widget.groupId));
            final customTags = tagsAsync.value ?? [];
            final fullFeatures = ref.watch(expenseFormFullFeaturesProvider);
            final showSimpleForm = !fullFeatures && widget.expenseId == null;
            final expandDescription = ref.watch(
              expenseFormExpandDescriptionProvider,
            );
            final expandBillBreakdown = ref.watch(
              expenseFormExpandBillBreakdownProvider,
            );

            return LayoutBuilder(
              builder: (context, layoutConstraints) {
                return Scaffold(
                  appBar: ContentAlignedAppBar(
                    contentAreaWidth: layoutConstraints.maxWidth,
                    leading: IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: _saving ? null : _popForm,
                    ),
                    title: Text(
                      (widget.expenseId != null
                              ? 'edit_expense'
                              : 'add_expense')
                          .tr(),
                    ),
                    actions: showSimpleForm
                        ? [
                            Tooltip(
                              message:
                                  (group.isPersonal
                                          ? 'expense_form_full_features_tooltip_personal'
                                          : 'expense_form_full_features_tooltip')
                                      .tr(),
                              child: IconButton(
                                icon: const Icon(Icons.info_outline),
                                onPressed: () =>
                                    _showExpenseFormInfoDialog(context, group),
                              ),
                            ),
                          ]
                        : null,
                  ),
                  body: AbsorbPointer(
                    absorbing: _saving,
                    child: ConstrainedContent(
                      child: Form(
                        key: _formKey,
                        child: FocusTraversalGroup(
                          child: ListView(
                            padding: EdgeInsets.only(
                              left: 16,
                              right: 16,
                              top: 12,
                              bottom:
                                  12 +
                                  _kSubmitBarHeight +
                                  _kSubmitBarExtraBottomPadding,
                            ),
                            children: [
                              if (!showSimpleForm) ...[
                                Theme(
                                  data: Theme.of(context).copyWith(
                                    splashFactory: NoSplash.splashFactory,
                                    highlightColor: Colors.transparent,
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Builder(
                                      builder: (context) {
                                        if (group.isPersonal &&
                                            _transactionType ==
                                                TransactionType.transfer) {
                                          WidgetsBinding.instance.addPostFrameCallback((
                                            _,
                                          ) {
                                            if (mounted) {
                                              setState(() {
                                                _transactionType =
                                                    TransactionType.expense;
                                                _transactionTypeSegmentInitial =
                                                    TransactionType.expense;
                                                _transactionTypeSegmentController
                                                        .value =
                                                    TransactionType.expense;
                                              });
                                            }
                                          });
                                          return const SizedBox(height: 52);
                                        }
                                        final theme = Theme.of(context);
                                        final colorScheme = theme.colorScheme;
                                        final segmentChildren =
                                            <TransactionType, Widget>{
                                              TransactionType.expense: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 4,
                                                    ),
                                                child: Text(
                                                  'expenses'.tr(),
                                                  style: theme
                                                      .textTheme
                                                      .titleSmall
                                                      ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color:
                                                            _transactionType ==
                                                                TransactionType
                                                                    .expense
                                                            ? colorScheme
                                                                  .primary
                                                            : colorScheme
                                                                  .onSurfaceVariant,
                                                      ),
                                                ),
                                              ),
                                              TransactionType.income: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 4,
                                                    ),
                                                child: Text(
                                                  'income'.tr(),
                                                  style: theme
                                                      .textTheme
                                                      .titleSmall
                                                      ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color:
                                                            _transactionType ==
                                                                TransactionType
                                                                    .income
                                                            ? colorScheme
                                                                  .primary
                                                            : colorScheme
                                                                  .onSurfaceVariant,
                                                      ),
                                                ),
                                              ),
                                            };
                                        if (!group.isPersonal) {
                                          segmentChildren[TransactionType
                                              .transfer] = Padding(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 4,
                                            ),
                                            child: Text(
                                              'transfer'.tr(),
                                              style: theme.textTheme.titleSmall
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w600,
                                                    color:
                                                        _transactionType ==
                                                            TransactionType
                                                                .transfer
                                                        ? colorScheme.primary
                                                        : colorScheme
                                                              .onSurfaceVariant,
                                                  ),
                                            ),
                                          );
                                        }
                                        // Package indexes [initialValue] into
                                        // children; missing keys throw on -1.
                                        final segmentInitial =
                                            segmentChildren.containsKey(
                                              _transactionTypeSegmentInitial,
                                            )
                                            ? _transactionTypeSegmentInitial
                                            : segmentChildren.keys.first;
                                        return CustomSlidingSegmentedControl<
                                          TransactionType
                                        >(
                                          controller:
                                              _transactionTypeSegmentController,
                                          initialValue: segmentInitial,
                                          children: segmentChildren,
                                          height: 52,
                                          padding: 16,
                                          innerPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 6,
                                              ),
                                          decoration: BoxDecoration(
                                            color: colorScheme
                                                .surfaceContainerHighest
                                                .withValues(alpha: 0.6),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          thumbDecoration: BoxDecoration(
                                            color: colorScheme.surface,
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: colorScheme.shadow
                                                    .withValues(alpha: 0.1),
                                                blurRadius: 3,
                                                offset: const Offset(0, 1),
                                              ),
                                            ],
                                          ),
                                          isStretch: true,
                                          duration: const Duration(
                                            milliseconds: 200,
                                          ),
                                          curve: Curves.easeInOut,
                                          onValueChanged: (type) {
                                            setState(() {
                                              _transactionType = type;
                                              if (type ==
                                                      TransactionType
                                                          .transfer &&
                                                  _toParticipantId == null) {
                                                final participants = ref
                                                    .read(
                                                      activeParticipantsByGroupProvider(
                                                        widget.groupId,
                                                      ),
                                                    )
                                                    .when(
                                                      data: (d) => d,
                                                      loading: () =>
                                                          <Participant>[],
                                                      error: (_, _) =>
                                                          <Participant>[],
                                                    );
                                                final payerId =
                                                    _payerParticipantId ??
                                                    (participants.isNotEmpty
                                                        ? participants.first.id
                                                        : null);
                                                if (participants.length > 1 &&
                                                    payerId != null) {
                                                  _toParticipantId =
                                                      participants
                                                          .firstWhere(
                                                            (p) =>
                                                                p.id != payerId,
                                                            orElse: () =>
                                                                participants
                                                                    .first,
                                                          )
                                                          .id;
                                                }
                                              }
                                            });
                                          },
                                        );
                                      },
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 24),
                              ],
                              if (!isTransfer) ...[
                                _formPanel(
                                  context,
                                  child: Builder(
                                    builder: (context) {
                                      final scanEnabled =
                                          ReceiptScanCapability.scanUiEnabled(
                                            ref.watch(receiptScanModeProvider),
                                          );
                                      final photosEmpty =
                                          _expenseImages.isEmpty;
                                      return ExpenseTitleSection(
                                        controller: _titleController,
                                        selectedTag: _selectedTag,
                                        customTags: customTags,
                                        onTagPicker: () =>
                                            _showTagPicker(customTags),
                                        onPickImage:
                                            photosEmpty && !_scanningReceipt
                                            ? () => _addPhoto()
                                            : null,
                                        onScanReceipt:
                                            photosEmpty &&
                                                scanEnabled &&
                                                !_scanningReceipt
                                            ? _scanReceiptAction
                                            : null,
                                      );
                                    },
                                  ),
                                ),
                                if (_expenseImages.isNotEmpty)
                                  ExpenseFormPhotosSection(
                                    images: _expenseImages,
                                    scanningImageIndex: _scanningImageIndex,
                                    scanEnabled:
                                        ReceiptScanCapability.scanUiEnabled(
                                          ref.watch(receiptScanModeProvider),
                                        ),
                                    onAddPhoto: () => _addPhoto(),
                                    onScanReceipt: _scanReceiptAction,
                                    onStopScan: _stopReceiptScan,
                                    onOpenGallery: _showPhotoGallery,
                                    onRemoveAt: _removeExpenseImageAt,
                                  ),
                                const SizedBox(height: 20),
                                ListenableBuilder(
                                  listenable: _descriptionController,
                                  builder: (context, _) {
                                    final desc = _descriptionController.text
                                        .trim();
                                    return ExpandableSection(
                                      title: 'expense_description'.tr(),
                                      // Pixel ellipsis in ExpandableSection; no
                                      // code-unit cut (breaks emoji / RTL).
                                      trailingSummary: desc.isNotEmpty
                                          ? desc
                                          : null,
                                      initiallyExpanded: expandDescription,
                                      child: _buildDescriptionSection(
                                        context,
                                        showLabel: false,
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 20),
                              ],
                              _formPanel(
                                context,
                                child: ExpenseAmountSection(
                                  controller: _amountController,
                                  currencyCode: _currencyCode,
                                  onCurrencyTap: _openExpenseCurrencyPicker,
                                  groupCurrencyCode: _groupCurrencyCode,
                                  exchangeRateController:
                                      _exchangeRateController,
                                  baseAmountController: _baseAmountController,
                                  fetchingRate: _fetchingRate,
                                  onExchangeRateChanged: _onExchangeRateChanged,
                                  onBaseAmountChanged: _onBaseAmountChanged,
                                ),
                              ),
                              const SizedBox(height: 20),
                              if (isTransfer) ...[
                                _formPanel(
                                  context,
                                  child: _buildTransferFromToRow(
                                    context,
                                    participants,
                                    effectivePayerId,
                                    toId,
                                    payerReadOnly: restrictPayerToSelf,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                _formPanel(
                                  context,
                                  child: _buildWhenSection(context),
                                ),
                              ] else
                                _formPanel(
                                  context,
                                  child: group.isPersonal
                                      ? _buildWhenSection(context)
                                      : _buildPaidByAndWhenRow(
                                          context,
                                          participants,
                                          effectivePayerId,
                                          payerReadOnly: restrictPayerToSelf,
                                        ),
                                ),
                              if (!isTransfer) ...[
                                const SizedBox(height: 20),
                                ExpandableSection(
                                  title: 'bill_breakdown'.tr(),
                                  trailingSummary: _lineItems.isNotEmpty
                                      ? (_lineItems.length == 1
                                            ? 'bill_breakdown_item'.tr()
                                            : 'bill_breakdown_items'.tr(
                                                args: ['${_lineItems.length}'],
                                              ))
                                      : null,
                                  initiallyExpanded: expandBillBreakdown,
                                  child: ExpenseBillBreakdownSection(
                                    lineItems: _lineItems,
                                    lineItemControllers: _lineItemControllers,
                                    onAddItem: () {
                                      setState(() {
                                        _lineItems.add(
                                          const ReceiptLineItem(
                                            description: '',
                                            amountCents: 0,
                                          ),
                                        );
                                        _lineItemControllers.add((
                                          desc: TextEditingController(),
                                          amount: TextEditingController(),
                                        ));
                                      });
                                    },
                                    onRemoveItem: (i) {
                                      setState(() {
                                        _lineItemControllers[i].desc.dispose();
                                        _lineItemControllers[i].amount
                                            .dispose();
                                        _lineItemControllers.removeAt(i);
                                        _lineItems.removeAt(i);
                                      });
                                    },
                                    onItemChanged: (i, desc, amountCents) {
                                      setState(() {
                                        _lineItems[i] = ReceiptLineItem(
                                          description: desc,
                                          amountCents: amountCents,
                                        );
                                      });
                                    },
                                  ),
                                ),
                                if (!group.isPersonal) ...[
                                  const SizedBox(height: 24),
                                  ListenableBuilder(
                                    listenable: _amountController,
                                    builder: (context, _) {
                                      final amountCents =
                                          (double.tryParse(
                                                _amountController.text.trim(),
                                              ) ??
                                              0) *
                                          100;
                                      final amountCentsInt = amountCents
                                          .toInt();
                                      if (_splitType == SplitType.parts ||
                                          _splitType == SplitType.amounts) {
                                        _ensureCustomSplitValues(
                                          amountCentsInt,
                                          participants,
                                        );
                                      }
                                      final shares = amountCentsInt > 0
                                          ? (_splitType == SplitType.equal
                                                ? _splitSharesPreview(
                                                    amountCentsInt,
                                                    participants,
                                                  )
                                                : _customSharesPreview(
                                                    amountCentsInt,
                                                    participants,
                                                  ))
                                          : <int>[];
                                      final participantIds = participants
                                          .map((e) => e.id)
                                          .toSet();
                                      for (final id in List.from(
                                        _splitEditControllers.keys,
                                      )) {
                                        if (!participantIds.contains(id)) {
                                          _splitEditControllers[id]?.dispose();
                                          _splitEditControllers.remove(id);
                                          _splitFocusNodes[id]?.dispose();
                                          _splitFocusNodes.remove(id);
                                        }
                                      }
                                      return Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          ExpenseSplitSection(
                                            participants: participants,
                                            sharesCents: shares,
                                            amountCents: amountCentsInt,
                                            currencyCode: currencyCode,
                                            splitType: _splitType,
                                            includedInSplitIds:
                                                _includedInSplitIds,
                                            customSplitValues:
                                                _customSplitValues,
                                            splitEditControllers:
                                                _splitEditControllers,
                                            splitFocusNodes: _splitFocusNodes,
                                            getOrCreateController: (p) {
                                              var c =
                                                  _splitEditControllers[p.id];
                                              if (c == null &&
                                                  (_splitType ==
                                                          SplitType.parts ||
                                                      _splitType ==
                                                          SplitType.amounts)) {
                                                c = TextEditingController(
                                                  text:
                                                      _customSplitValues[p
                                                          .id] ??
                                                      '1',
                                                );
                                                _splitEditControllers[p.id] = c;
                                                if (!_splitFocusNodes
                                                    .containsKey(p.id)) {
                                                  final node = FocusNode();
                                                  node.addListener(() {
                                                    if (!node.hasFocus) {
                                                      _handleAmountFieldUnfocused(
                                                        p,
                                                      );
                                                    }
                                                  });
                                                  _splitFocusNodes[p.id] = node;
                                                }
                                              }
                                              return c;
                                            },
                                            getOrCreateFocusNode: (p) =>
                                                _splitFocusNodes[p.id],
                                            onSplitTypeTap: () =>
                                                _showSplitTypePicker(context),
                                            onIncludeChanged: (p, included) {
                                              setState(() {
                                                if (included) {
                                                  _includedInSplitIds.add(p.id);
                                                } else {
                                                  _includedInSplitIds.remove(
                                                    p.id,
                                                  );
                                                  _amountsManuallySetIds.remove(
                                                    p.id,
                                                  );
                                                  _customSplitValues.remove(
                                                    p.id,
                                                  );
                                                  _splitEditControllers[p.id]
                                                      ?.dispose();
                                                  _splitEditControllers.remove(
                                                    p.id,
                                                  );
                                                  _splitFocusNodes[p.id]
                                                      ?.dispose();
                                                  _splitFocusNodes.remove(p.id);
                                                }
                                              });
                                            },
                                            onAmountChanged:
                                                (p, v, includedList, ctrl) {
                                                  setState(() {
                                                    _applyAmountsChange(
                                                      p,
                                                      v,
                                                      amountCentsInt,
                                                      includedList,
                                                      ctrl,
                                                    );
                                                  });
                                                },
                                            onPartsChanged: (p, v) {
                                              setState(
                                                () => _customSplitValues[p.id] =
                                                    v,
                                              );
                                            },
                                            amountsSumCents: () =>
                                                _amountsSumCents(participants),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ],
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Bound height before [ConstrainedContent]: its tablet Row uses
                  // CrossAxisAlignment.stretch and will otherwise expand to the
                  // Scaffold's loose max height (full screen) in landscape.
                  bottomNavigationBar: SafeArea(
                    top: false,
                    child: SizedBox(
                      height: _kSubmitBarHeight,
                      child: ConstrainedContent(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: ListenableBuilder(
                            listenable: _amountController,
                            builder: (context, _) {
                              final amountCentsInt =
                                  ((double.tryParse(
                                                _amountController.text.trim(),
                                              ) ??
                                              0) *
                                          100)
                                      .toInt();
                              return SizedBox(
                                height: 52,
                                width: double.infinity,
                                child: FilledButton(
                                  onPressed:
                                      (_saving ||
                                          (_splitType == SplitType.amounts &&
                                              _amountsSumCents(participants) !=
                                                  amountCentsInt))
                                      ? null
                                      : _save,
                                  child: _saving
                                      ? const SizedBox(
                                          height: 24,
                                          width: 24,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : Text(
                                          (widget.expenseId != null
                                                  ? 'submit'
                                                  : 'add_expense')
                                              .tr(),
                                        ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
          loading: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (e, st) {
            sendErrorTelemetryIfOnline(
              ref,
              message: e.toString(),
              details: e.toString(),
            );
            return Scaffold(
              body: Center(
                child: ErrorContentWidget(
                  message: e.toString(),
                  details: e.toString(),
                  stackTrace: st,
                  onRetry: () {
                    ref.invalidate(futureGroupProvider(widget.groupId));
                    ref.invalidate(participantsByGroupProvider(widget.groupId));
                  },
                ),
              ),
            );
          },
        );
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, st) {
        sendErrorTelemetryIfOnline(
          ref,
          message: e.toString(),
          details: e.toString(),
        );
        return Scaffold(
          body: Center(
            child: ErrorContentWidget(
              message: e.toString(),
              details: e.toString(),
              stackTrace: st,
              onRetry: () {
                ref.invalidate(futureGroupProvider(widget.groupId));
                ref.invalidate(participantsByGroupProvider(widget.groupId));
              },
            ),
          ),
        );
      },
    );
  }

  void _showExpenseFormInfoDialog(BuildContext context, Group group) {
    _defocusFormInputs();
    final tooltipKey = group.isPersonal
        ? 'expense_form_full_features_tooltip_personal'
        : 'expense_form_full_features_tooltip';
    showResponsiveSheet<void>(
      context: context,
      title: 'expense_form_full_features_tooltip_title'.tr(),
      maxHeight: MediaQuery.of(context).size.height * 0.5,
      isScrollControlled: true,
      centerInFullViewport: true,
      child: Builder(
        builder: (ctx) => buildSheetShell(
          ctx,
          title: 'expense_form_full_features_tooltip_title'.tr(),
          showTitleInBody: !LayoutBreakpoints.isTabletOrWider(context),
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(tooltipKey.tr()),
          ),
          actions: [
            if (!LayoutBreakpoints.isTabletOrWider(context))
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('cancel'.tr()),
              ),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                context.go(RoutePaths.settings);
              },
              child: Text('settings'.tr()),
            ),
          ],
        ),
      ),
    );
  }

  bool _canCreateTags(Group? group, GroupRole? myRole) {
    if (group == null) return false;
    final localOnly = ref.read(effectiveLocalOnlyProvider);
    final isOwnerOrAdmin =
        localOnly || myRole == GroupRole.owner || myRole == GroupRole.admin;
    return isOwnerOrAdmin || group.allowMemberChangeSettings;
  }

  void _showTagPicker(List<ExpenseTag> customTags) {
    _defocusFormInputs();
    final theme = Theme.of(context);
    final group = ref.read(futureGroupProvider(widget.groupId)).asData?.value;
    final myRole = ref
        .read(myRoleInGroupProvider(widget.groupId))
        .asData
        ?.value;
    final canCreate = _canCreateTags(group, myRole);
    final expenses =
        ref.read(expensesByGroupProvider(widget.groupId)).asData?.value ??
        const <Expense>[];
    final usageByTag = <String, int>{};
    for (final e in expenses) {
      final tag = e.tag;
      if (tag == null || tag.isEmpty) continue;
      usageByTag[tag] = (usageByTag[tag] ?? 0) + 1;
    }

    showResponsiveSheet<void>(
      context: context,
      title: 'category'.tr(),
      maxHeight: MediaQuery.of(context).size.height * 0.75,
      isScrollControlled: true,
      centerInFullViewport: true,
      child: Builder(
        builder: (ctx) {
          var query = '';
          return StatefulBuilder(
            builder: (ctx, setSheetState) {
              final q = query.trim().toLowerCase();
              bool matches(String label) =>
                  q.isEmpty || label.toLowerCase().contains(q);

              final presets = presetExpenseTags.where((preset) {
                return matches('category_${preset.id}'.tr()) ||
                    matches(preset.label);
              });
              final customs = customTags.where((tag) => matches(tag.label));

              Widget pill({
                required bool selected,
                required IconData icon,
                required String label,
                required ExpenseTagChrome chrome,
                required VoidCallback onTap,
                bool useUserText = false,
                String? semanticsHint,
              }) {
                return Semantics(
                  button: true,
                  selected: selected,
                  label: semanticsHint ?? label,
                  child: InkWell(
                    onTap: onTap,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? chrome.container
                            : theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: chrome.accent.withValues(
                            alpha: selected ? 0.0 : 0.35,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            icon,
                            size: 20,
                            color: selected
                                ? chrome.onContainer
                                : chrome.onSurface,
                          ),
                          const SizedBox(width: 8),
                          useUserText
                              ? UserText(
                                  label,
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    color: selected
                                        ? chrome.onContainer
                                        : theme.colorScheme.onSurface,
                                    fontWeight: FontWeight.w600,
                                  ),
                                )
                              : Text(
                                  label,
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    color: selected
                                        ? chrome.onContainer
                                        : theme.colorScheme.onSurface,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              // Bottom safe/IME inset is owned by [showResponsiveSheet].
              return SafeArea(
                bottom: false,
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!LayoutBreakpoints.isTabletOrWider(context)) ...[
                          Text(
                            'category'.tr(),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        TextField(
                          decoration: InputDecoration(
                            hintText: 'search'.tr(),
                            prefixIcon: const Icon(Icons.search, size: 20),
                            isDense: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onChanged: (v) => setSheetState(() => query = v),
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            pill(
                              selected:
                                  _selectedTag == null || _selectedTag!.isEmpty,
                              icon: Icons.label_off_outlined,
                              label: 'no_category'.tr(),
                              chrome: chromeForExpenseTag(
                                null,
                                brightness: theme.brightness,
                                surface: theme.colorScheme.surface,
                              ),
                              onTap: () {
                                setState(() => _selectedTag = null);
                                if (ctx.mounted) Navigator.of(ctx).pop();
                              },
                            ),
                            ...presets.map((preset) {
                              final selected = _selectedTag == preset.id;
                              final chrome = chromeForExpenseTag(
                                preset.id,
                                brightness: theme.brightness,
                                surface: theme.colorScheme.surface,
                              );
                              final count = usageByTag[preset.id] ?? 0;
                              return pill(
                                selected: selected,
                                icon: preset.icon,
                                label: 'category_${preset.id}'.tr(),
                                chrome: chrome,
                                semanticsHint: count > 0
                                    ? '${'category_${preset.id}'.tr()}, ${'tag_usage_count'.tr(namedArgs: {'count': '$count'})}'
                                    : null,
                                onTap: () {
                                  setState(() => _selectedTag = preset.id);
                                  if (ctx.mounted) Navigator.of(ctx).pop();
                                },
                              );
                            }),
                            ...customs.map((tag) {
                              final selected = _selectedTag == tag.id;
                              final iconData =
                                  selectableExpenseIcons[tag.iconName] ??
                                  Icons.label_outlined;
                              final chrome = chromeForExpenseTag(
                                tag.id,
                                brightness: theme.brightness,
                                surface: theme.colorScheme.surface,
                                customTags: customTags,
                              );
                              final count = usageByTag[tag.id] ?? 0;
                              return pill(
                                selected: selected,
                                icon: iconData,
                                label: tag.label,
                                chrome: chrome,
                                useUserText: true,
                                semanticsHint: count > 0
                                    ? '${tag.label}, ${'tag_usage_count'.tr(namedArgs: {'count': '$count'})}'
                                    : tag.label,
                                onTap: () {
                                  setState(() => _selectedTag = tag.id);
                                  if (ctx.mounted) Navigator.of(ctx).pop();
                                },
                              );
                            }),
                            if (canCreate)
                              Semantics(
                                button: true,
                                label: 'create_new_tag'.tr(),
                                child: InkWell(
                                  onTap: () async {
                                    Navigator.of(ctx).pop();
                                    final created =
                                        await _showCreateTagDialog();
                                    if (created != null && mounted) {
                                      setState(() => _selectedTag = created.id);
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: theme.colorScheme.outline
                                            .withValues(alpha: 0.5),
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.add_circle_outline,
                                          size: 20,
                                          color: theme.colorScheme.primary,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'create_new_tag'.tr(),
                                          style: theme.textTheme.labelLarge
                                              ?.copyWith(
                                                color:
                                                    theme.colorScheme.primary,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<ExpenseTag?> _showCreateTagDialog() async {
    _defocusFormInputs();
    return showResponsiveSheet<ExpenseTag>(
      context: context,
      title: 'create_new_tag'.tr(),
      maxHeight: MediaQuery.of(context).size.height * 0.75,
      isScrollControlled: true,
      centerInFullViewport: true,
      child: Builder(
        builder: (ctx) => CreateTagSheetContent(
          sheetContext: ctx,
          groupId: widget.groupId,
          ref: ref,
        ),
      ),
    );
  }

  /// Line items to persist: exclude rows that are both empty description and zero amount.
  List<ReceiptLineItem>? _effectiveLineItemsForSave() {
    final filtered = _lineItems
        .where((e) => e.description.trim().isNotEmpty || e.amountCents > 0)
        .toList();
    return filtered.isEmpty ? null : filtered;
  }

  Widget _buildDescriptionSection(
    BuildContext context, {
    bool showLabel = true,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showLabel) ...[
          Text(
            'expense_description'.tr(),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
        ],
        TextFormField(
          controller: _descriptionController,
          decoration: InputDecoration(
            hintText: 'expense_description_hint'.tr(),
            filled: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            alignLabelWithHint: true,
          ),
          maxLines: 4,
          minLines: 2,
        ),
      ],
    );
  }

  Widget _buildPaidByAndWhenRow(
    BuildContext context,
    List<Participant> participants,
    String payerId, {
    bool payerReadOnly = false,
  }) {
    final theme = Theme.of(context);
    final payer = participants.firstWhere(
      (p) => p.id == payerId,
      orElse: () => participants.first,
    );
    final payerName = payer.name;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'paid_by_label'.tr(),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 6),
              payerReadOnly
                  ? Container(
                      height: 52,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: AlignmentDirectional.centerStart,
                      child: Row(
                        children: [
                          ParticipantAvatar(
                            name: payerName,
                            avatarId: payer.avatarId,
                            radius: 16,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: UserText(
                              payerName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyLarge,
                            ),
                          ),
                        ],
                      ),
                    )
                  : InkWell(
                      onTap: () => _showPayerPicker(context, participants),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        height: 52,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: AlignmentDirectional.centerStart,
                        child: Row(
                          children: [
                            ParticipantAvatar(
                              name: payerName,
                              avatarId: payer.avatarId,
                              radius: 16,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: UserText(
                                payerName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyLarge,
                              ),
                            ),
                            Icon(
                              Icons.arrow_drop_down,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ],
                        ),
                      ),
                    ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: _buildDateTimeField(context, label: 'when'.tr())),
      ],
    );
  }

  Widget _buildTransferFromToRow(
    BuildContext context,
    List<Participant> participants,
    String payerId,
    String toId, {
    bool payerReadOnly = false,
  }) {
    final theme = Theme.of(context);
    final payer = participants.firstWhere(
      (p) => p.id == payerId,
      orElse: () => participants.first,
    );
    final toParticipant = participants.firstWhere(
      (p) => p.id == toId,
      orElse: () => participants.first,
    );
    final others = participants.where((p) => p.id != payerId).toList();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'from'.tr(),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 6),
              payerReadOnly
                  ? Container(
                      height: 52,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: AlignmentDirectional.centerStart,
                      child: Row(
                        children: [
                          ParticipantAvatar(
                            name: payer.name,
                            avatarId: payer.avatarId,
                            radius: 16,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: UserText(
                              payer.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyLarge,
                            ),
                          ),
                        ],
                      ),
                    )
                  : InkWell(
                      onTap: () => _showPayerPicker(context, participants),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        height: 52,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: AlignmentDirectional.centerStart,
                        child: Row(
                          children: [
                            ParticipantAvatar(
                              name: payer.name,
                              avatarId: payer.avatarId,
                              radius: 16,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: UserText(
                                payer.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyLarge,
                              ),
                            ),
                            Icon(
                              Icons.arrow_drop_down,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ],
                        ),
                      ),
                    ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'to'.tr(),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 6),
              InkWell(
                onTap: () async {
                  if (others.isEmpty) return;
                  _defocusFormInputs();
                  final chosen = await showOptionPickerSheet<String>(
                    context,
                    title: 'to'.tr(),
                    selected: _toParticipantId,
                    options: [
                      for (final p in others)
                        SheetPickerOption(
                          value: p.id,
                          label: p.name,
                          leading: ParticipantAvatar(
                            name: p.name,
                            avatarId: p.avatarId,
                            radius: 16,
                          ),
                        ),
                    ],
                  );
                  if (chosen != null) setState(() => _toParticipantId = chosen);
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  height: 52,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: AlignmentDirectional.centerStart,
                  child: Row(
                    children: [
                      ParticipantAvatar(
                        name: toParticipant.name,
                        avatarId: toParticipant.avatarId,
                        radius: 16,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: UserText(
                          toParticipant.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyLarge,
                        ),
                      ),
                      Icon(
                        Icons.arrow_drop_down,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Shared date+time field: label "Date & time" (or "when"), formatted value, tap opens combined picker.
  Widget _buildDateTimeField(BuildContext context, {String? label}) {
    final theme = Theme.of(context);
    final use24h = ref.watch(use24HourFormatProvider);
    final dateLabel = DateFormat.MMMd().format(_date);
    final timeLabel = (use24h ? DateFormat.Hm() : DateFormat.jm()).format(
      _date,
    );
    final compactLabel = '$dateLabel · $timeLabel';
    final effectiveLabel = label ?? 'date_and_time'.tr();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          effectiveLabel,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: () async {
            final picked = await _showDateTimePicker(context);
            if (picked != null && mounted) setState(() => _date = picked);
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: AlignmentDirectional.centerStart,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    compactLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge,
                  ),
                ),
                Icon(
                  Icons.calendar_today_rounded,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Single dialog: calendar on top, time selector (hour/minute/AM-PM) below, Cancel/OK. No tabs.
  Future<DateTime?> _showDateTimePicker(BuildContext context) async {
    _defocusFormInputs();
    final use24h = ref.read(use24HourFormatProvider);
    return showDateTimePickerDialog(
      context,
      initial: _date,
      use24h: use24h,
      maxDate: DateTime.now(),
    );
  }

  Widget _buildWhenSection(BuildContext context) {
    return _buildDateTimeField(context, label: 'when'.tr());
  }

  Future<void> _showPayerPicker(
    BuildContext context,
    List<Participant> participants,
  ) async {
    _defocusFormInputs();
    final chosen = await showOptionPickerSheet<String>(
      context,
      title: 'paid_by_label'.tr(),
      selected: _payerParticipantId,
      options: [
        for (final p in participants)
          SheetPickerOption(
            value: p.id,
            label: p.name,
            leading: ParticipantAvatar(
              name: p.name,
              avatarId: p.avatarId,
              radius: 16,
            ),
          ),
      ],
    );
    if (chosen != null) setState(() => _payerParticipantId = chosen);
  }

  Future<void> _showSplitTypePicker(BuildContext context) async {
    _defocusFormInputs();
    final chosen = await showOptionPickerSheet<SplitType>(
      context,
      title: 'split_type'.tr(),
      selected: _splitType,
      options: [
        for (final e in SplitType.values)
          SheetPickerOption(
            value: e,
            label: e == SplitType.equal
                ? 'equal'.tr()
                : e == SplitType.parts
                ? 'parts'.tr()
                : 'amounts'.tr(),
          ),
      ],
    );
    if (chosen != null) {
      setState(() {
        _splitType = chosen;
        _amountsManuallySetIds.clear();
        _lastAmountCentsForAmounts = null;
        if (chosen == SplitType.parts || chosen == SplitType.amounts) {
          _amountsFieldsTouched = false;
          for (final c in _splitEditControllers.values) {
            c.dispose();
          }
          _splitEditControllers.clear();
          for (final f in _splitFocusNodes.values) {
            f.dispose();
          }
          _splitFocusNodes.clear();
          _customSplitValues.clear();
        }
      });
    }
  }
}
