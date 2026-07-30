/// Receipt OCR / AI scan entrypoint.
///
/// Native: full ML Kit + LLM pipeline ([receipt_scan_service_io.dart]).
/// Web: no-op stub — AI/OCR is disabled (not working on Flutter web).
export 'receipt_scan_service_stub.dart'
    if (dart.library.io) 'receipt_scan_service_io.dart';
