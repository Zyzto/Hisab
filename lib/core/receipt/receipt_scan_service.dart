// Receipt OCR / AI scan entrypoint.
// Native: Tesseract/Vision OCR plus local receipt extraction.
// Web: no-op stub — AI/OCR is disabled.
export 'receipt_scan_service_stub.dart'
    if (dart.library.io) 'receipt_scan_service_io.dart';
