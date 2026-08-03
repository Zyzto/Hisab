// Platform OCR for receipt scan.
// Native: Android Tesseract / iOS Vision via MethodChannel.
// Web: stub (empty text).
export 'receipt_ocr_stub.dart' if (dart.library.io) 'receipt_ocr_io.dart';
