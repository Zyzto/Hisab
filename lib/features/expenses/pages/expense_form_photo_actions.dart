part of 'expense_form_page.dart';

/// Photo pick / scan / gallery handlers for [_ExpenseFormPageState].
mixin _ExpenseFormPhotoActionsMixin on ConsumerState<ExpenseFormPage> {
  /// Photos: pending bytes (before upload) or stored URL. Max [kMaxExpenseImages].
  final List<ExpensePhotoItem> _expenseImages = [];

  /// Index of the expense image currently OCR/AI scanning.
  /// `-1` = scanning with unknown thumb; `null` = idle.
  int? _scanningImageIndex;

  bool get _scanningReceipt => _scanningImageIndex != null;

  /// Cooperative cancel for the in-flight receipt scan.
  ReceiptScanCancelToken? _scanCancel;

  /// One Nano-unavailable toast per form session.
  bool _nanoFallbackToastShown = false;

  /// Android may kill the activity under the camera; recover once via retrieveLostData.
  bool _lostPickerDataChecked = false;

  _ExpenseFormPageState get _photoForm => this as _ExpenseFormPageState;

  void _stopReceiptScan() {
    _scanCancel?.cancel();
    _scanCancel = null;
    // Ignore: native stop is best-effort.
    cancelReceiptOcr();
    if (mounted && _scanningImageIndex != null) {
      setState(() => _scanningImageIndex = null);
    }
  }

  /// After Android kills MainActivity under the camera, [pickImage] /
  /// [pickMultiImage] never returns — recover files and ingest into the form.
  Future<void> _recoverLostPickerImage() async {
    if (_lostPickerDataChecked) return;
    _lostPickerDataChecked = true;
    if (kIsWeb || !isAndroid) return;
    if (_expenseImages.length >= kMaxExpenseImages) {
      clearPendingImagePick(ref);
      return;
    }
    try {
      final response = await ImagePicker().retrieveLostData();
      if (!mounted || response.isEmpty) {
        clearPendingImagePick(ref);
        return;
      }
      final exception = response.exception;
      if (exception != null) {
        Log.warning(
          'Lost camera/gallery data: ${exception.code} ${exception.message}',
        );
        clearPendingImagePick(ref);
        return;
      }
      final files = <XFile>[
        ...?response.files,
        if ((response.files == null || response.files!.isEmpty) &&
            response.file != null)
          response.file!,
      ];
      if (files.isEmpty) {
        clearPendingImagePick(ref);
        return;
      }
      final scanAfter =
          readPendingImagePickMode(ref) == PendingImagePickMode.scan;
      Log.info(
        'Recovered ${files.length} photo(s) after picker activity kill '
        '(scanAfter=$scanAfter)',
      );
      await _ingestPickedPhotos(files, scanAfter: scanAfter);
    } catch (e, stack) {
      Log.warning('retrieveLostData failed', error: e, stackTrace: stack);
      clearPendingImagePick(ref);
    }
  }

  /// Compress and append multiple picks; OCR runs on the last image when asked.
  Future<void> _ingestPickedPhotos(
    List<XFile> files, {
    required bool scanAfter,
  }) async {
    if (files.isEmpty) {
      clearPendingImagePick(ref);
      return;
    }
    Uint8List? lastOcrBytes;
    try {
      for (final file in files) {
        if (!mounted) break;
        if (_expenseImages.length >= kMaxExpenseImages) break;
        final bytes = await file.readAsBytes();
        final forOcr = await compressReceiptImageForOcr(bytes) ?? bytes;
        final compressed = await compressReceiptImage(forOcr);
        if (!mounted) break;
        final toAdd = compressed ?? forOcr;
        lastOcrBytes = forOcr;
        setState(() {
          if (_expenseImages.length < kMaxExpenseImages) {
            _expenseImages.add((bytes: toAdd, url: null));
          }
        });
      }
    } catch (e, stack) {
      if (mounted) {
        Log.warning('Photo add error', error: e, stackTrace: stack);
        context.showError('receipt_scan_error'.tr(args: [e.toString()]));
      }
    } finally {
      clearPendingImagePick(ref);
    }
    if (scanAfter && lastOcrBytes != null && mounted) {
      final scanIndex = _expenseImages.length - 1;
      await _onScanReceiptFromPhoto(
        lastOcrBytes,
        imageIndex: scanIndex >= 0 ? scanIndex : null,
      );
    }
  }

  Future<void> _scanReceiptAction() async {
    if (_scanningReceipt) return;
    if (!ReceiptScanCapability.scanUiEnabled(
      ref.read(receiptScanModeProvider),
    )) {
      return;
    }
    if (kIsWeb) {
      if (mounted) context.showToast('receipt_scan_web_unavailable'.tr());
      return;
    }
    await _addPhoto(scanAfter: true);
  }

  /// Add photo via inline camera (gallery is on the camera chrome).
  /// [scanAfter] runs OCR after attach. Desktop/web without mock → gallery picker.
  Future<void> _addPhoto({bool scanAfter = false}) async {
    _photoForm._defocusFormInputs();
    if (_expenseImages.length >= kMaxExpenseImages) return;

    final mockOn = ref.read(debugReceiptCameraMockProvider);
    if (ReceiptScanCapability.isNativeMobile || mockOn) {
      await _addPhotoFromInlineCamera(
        scanAfter: scanAfter,
        mockPreview: mockOn,
      );
      return;
    }

    await _pickAndIngestFromPicker(
      source: ImageSource.gallery,
      scanAfter: scanAfter,
    );
  }

  /// In-app receipt camera. [mockPreview] skips hardware (debug desktop/mobile).
  Future<void> _addPhotoFromInlineCamera({
    required bool scanAfter,
    bool mockPreview = false,
  }) async {
    final maxRemaining = kMaxExpenseImages - _expenseImages.length;
    if (maxRemaining <= 0 || !mounted) return;

    Uint8List? galleryThumb;
    for (var i = _expenseImages.length - 1; i >= 0; i--) {
      final bytes = _expenseImages[i].bytes;
      if (bytes != null && bytes.isNotEmpty) {
        galleryThumb = bytes;
        break;
      }
    }

    final result = await showReceiptCamera(
      context,
      maxRemaining: maxRemaining,
      scanAfter: scanAfter,
      mockPreview: mockPreview,
      galleryThumb: galleryThumb,
    );
    if (!mounted) return;

    if (result == null) return;

    if (result.openGallery) {
      await _pickAndIngestFromPicker(
        source: ImageSource.gallery,
        scanAfter: scanAfter,
      );
      return;
    }

    final images = result.images;
    await _ingestPickedPhotos(images, scanAfter: result.scanAfter);
  }

  /// OS camera / gallery via [ImagePicker], with Android lost-data recovery.
  Future<void> _pickAndIngestFromPicker({
    required ImageSource source,
    required bool scanAfter,
  }) async {
    final maxRemaining = kMaxExpenseImages - _expenseImages.length;
    if (maxRemaining <= 0) return;

    final bool hasPermission;
    if (source == ImageSource.camera) {
      hasPermission = await PermissionService.requestCameraPermission(context);
    } else if (isAndroid) {
      hasPermission = true;
    } else {
      hasPermission = await PermissionService.requestPhotosPermission(context);
    }
    if (!hasPermission || !mounted) return;

    persistLastRoutePath(ref, _photoForm._formRoutePath);
    setPendingImagePickMode(
      ref,
      scanAfter ? PendingImagePickMode.scan : PendingImagePickMode.attach,
    );

    final picker = ImagePicker();
    final List<XFile> files;
    if (source == ImageSource.gallery) {
      // Multi-select up to remaining slots (limit:1 delegates to single pick).
      files = await picker.pickMultiImage(
        limit: maxRemaining,
        maxWidth: kReceiptOcrMaxDimension.toDouble(),
        maxHeight: kReceiptOcrMaxDimension.toDouble(),
        imageQuality: kReceiptOcrQuality,
      );
    } else {
      final file = await picker.pickImage(
        source: source,
        maxWidth: kReceiptOcrMaxDimension.toDouble(),
        maxHeight: kReceiptOcrMaxDimension.toDouble(),
        imageQuality: kReceiptOcrQuality,
      );
      files = file == null ? const <XFile>[] : <XFile>[file];
    }
    if (files.isEmpty || !mounted) {
      if (mounted && isAndroid && !kIsWeb) {
        _lostPickerDataChecked = false;
        await _recoverLostPickerImage();
      } else {
        clearPendingImagePick(ref);
      }
      return;
    }
    await _ingestPickedPhotos(files, scanAfter: scanAfter);
  }

  void _removeExpenseImageAt(int index) {
    final scanning = _scanningImageIndex;
    if (scanning == index) {
      _scanCancel?.cancel();
      _scanCancel = null;
      cancelReceiptOcr();
    }
    setState(() {
      _expenseImages.removeAt(index);
      if (scanning == index) {
        _scanningImageIndex = null;
      } else if (scanning != null && scanning > index) {
        _scanningImageIndex = scanning - 1;
      }
    });
  }

  Future<void> _showPhotoGallery(int index) async {
    if (_expenseImages.isEmpty || !mounted) return;
    final scanMode = ref.read(receiptScanModeProvider);
    final scanEnabled = ReceiptScanCapability.scanUiEnabled(scanMode);
    final updated = await showExpensePhotoGallery(
      context,
      images: List<ExpensePhotoItem>.of(_expenseImages),
      initialIndex: index,
      scanEnabled: scanEnabled && !_scanningReceipt,
      onScan: scanEnabled
          ? (bytes) async {
              final idx = _expenseImages.indexWhere(
                (e) => identical(e.bytes, bytes),
              );
              await _onScanReceiptFromPhoto(
                bytes,
                imageIndex: idx >= 0 ? idx : null,
              );
            }
          : null,
    );
    if (!mounted || updated == null) return;
    setState(() {
      _expenseImages
        ..clear()
        ..addAll(updated);
    });
  }

  /// Run OCR/AI on a photo (native only). Pre-fills title/date/amount or description.
  Future<void> _onScanReceiptFromPhoto(
    Uint8List bytes, {
    int? imageIndex,
  }) async {
    if (_scanningReceipt) return;
    if (kIsWeb) {
      context.showToast('receipt_scan_web_unavailable'.tr());
      return;
    }
    final mode = ref.read(receiptScanModeProvider);
    if (!ReceiptScanCapability.scanUiEnabled(mode)) return;

    final cancel = ReceiptScanCancelToken();
    _scanCancel = cancel;
    // -1 keeps the section header busy without marking every thumbnail.
    setState(() => _scanningImageIndex = imageIndex ?? -1);
    try {
      if (!_nanoFallbackToastShown &&
          !cancel.isCancelled &&
          await nanoNeedsUserAttention(ref)) {
        cancel.throwIfCancelled();
        _nanoFallbackToastShown = true;
        if (mounted) {
          context.showToast('receipt_nano_unavailable_toast'.tr());
        }
      }
      cancel.throwIfCancelled();
      final result = await processReceiptBytes(
        bytes,
        ref,
        _photoForm._date,
        cancel: cancel,
      );
      if (cancel.isCancelled || !mounted) return;
      if (result == null) {
        context.showToast('receipt_no_text'.tr());
        return;
      }
      switch (result) {
        case ReceiptScanParsed():
          setState(() {
            _photoForm._titleController.text = result.vendor;
            _photoForm._date = result.date.isUtc
                ? result.date.toLocal()
                : result.date;
            _photoForm._amountController.text = result.total.toStringAsFixed(2);
            if (result.lineItems != null && result.lineItems!.isNotEmpty) {
              _photoForm._lineItems = List<ReceiptLineItem>.from(
                result.lineItems!,
              );
              _photoForm._syncLineItemControllersFromItems();
            }
            if (result.description != null &&
                result.description!.trim().isNotEmpty) {
              _photoForm._descriptionController.text = result.description!;
            } else if (result.vat != null && result.vat! > 0) {
              _photoForm._descriptionController.text =
                  'VAT: ${result.vat!.toStringAsFixed(2)}';
            }
          });
          context.showSuccess('receipt_scan_applied'.tr());
        case ReceiptScanFallback():
          setState(() {
            if (_photoForm._titleController.text.trim().isEmpty) {
              _photoForm._titleController.text = 'receipt'.tr();
            }
            if (result.ocrText.isNotEmpty) {
              _photoForm._descriptionController.text = result.ocrText;
            }
          });
          context.showSuccess('receipt_scan_applied'.tr());
      }
    } on ReceiptScanCancelledException {
      Log.info('Receipt scan stopped by user');
    } catch (e, stack) {
      if (mounted && !cancel.isCancelled) {
        final msg = shortReceiptErrorMessage(e);
        Log.warning('Receipt scan error', error: e, stackTrace: stack);
        context.showError('receipt_scan_error'.tr(args: [msg]));
      }
    } finally {
      if (_scanCancel == cancel) {
        _scanCancel = null;
        if (mounted) setState(() => _scanningImageIndex = null);
      }
    }
  }
}
