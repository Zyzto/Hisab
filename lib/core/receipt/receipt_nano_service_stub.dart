import 'receipt_nano_types.dart';

export 'receipt_nano_types.dart';

/// Web / non-IO: Gemini Nano is unavailable.
Future<NanoFeatureStatus> checkNanoStatus() async =>
    NanoFeatureStatus.unavailable;

/// Web / non-IO: no-op.
Future<void> downloadNanoFeature({void Function()? onCompleted}) async {
  onCompleted?.call();
}

/// Web / non-IO: always fails.
Future<String?> extractReceiptJsonWithNano({
  String? ocrText,
  String? imagePath,
}) async => null;
