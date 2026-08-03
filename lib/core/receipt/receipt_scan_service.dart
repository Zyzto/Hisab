// Receipt OCR / AI scan entrypoint.
// Native: Tesseract/Vision OCR + local/nano/cloud pipeline.
// Web: no-op stub — AI/OCR is disabled.
export 'receipt_scan_service_stub.dart'
    if (dart.library.io) 'receipt_scan_service_io.dart';
