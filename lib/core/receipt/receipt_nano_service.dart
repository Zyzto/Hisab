// Gemini Nano receipt extraction entrypoint.
// Web: stub (always unavailable).
// Native: Android AI Core via ML Kit GenAI Prompt; iOS returns unavailable.
export 'receipt_nano_service_stub.dart'
    if (dart.library.io) 'receipt_nano_service_io.dart';
