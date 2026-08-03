import Flutter
import UIKit
import Vision

/// MethodChannel bridge for on-device receipt OCR via Apple Vision.
final class ReceiptOcrBridge: NSObject {
  static let channelName = "hisab/receipt_ocr"

  private let queue = DispatchQueue(label: "com.shenepoy.hisab.receipt_ocr", qos: .userInitiated)
  private var cancelRequested = false
  private var currentRequest: VNRecognizeTextRequest?

  static func register(with messenger: FlutterBinaryMessenger) {
    let bridge = ReceiptOcrBridge()
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      bridge.handle(call, result: result)
    }
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "recognize":
      guard
        let args = call.arguments as? [String: Any],
        let path = args["path"] as? String,
        !path.isEmpty
      else {
        result(
          FlutterError(code: "invalid_args", message: "Missing image path", details: nil)
        )
        return
      }
      cancelRequested = false
      queue.async { [weak self] in
        guard let self else { return }
        do {
          let text = try self.recognizeBlocking(path: path)
          DispatchQueue.main.async {
            if self.cancelRequested {
              result(
                FlutterError(code: "cancelled", message: "OCR cancelled", details: nil)
              )
            } else {
              result(text)
            }
          }
        } catch {
          DispatchQueue.main.async {
            if self.cancelRequested {
              result(
                FlutterError(code: "cancelled", message: "OCR cancelled", details: nil)
              )
            } else {
              result(
                FlutterError(
                  code: "ocr_failed",
                  message: error.localizedDescription,
                  details: nil
                )
              )
            }
          }
        }
      }

    case "cancel":
      cancelRequested = true
      currentRequest?.cancel()
      currentRequest = nil
      result(nil)

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func recognizeBlocking(path: String) throws -> String {
    if cancelRequested {
      throw ReceiptOcrError.cancelled
    }
    let url = URL(fileURLWithPath: path)
    guard FileManager.default.fileExists(atPath: path) else {
      throw ReceiptOcrError.imageNotFound(path)
    }
    let handler = VNImageRequestHandler(url: url, options: [:])
    var recognized = ""
    let request = VNRecognizeTextRequest { request, error in
      if let error {
        // Propagated via handler.perform throw path when possible.
        NSLog("ReceiptOcr Vision error: \(error.localizedDescription)")
        return
      }
      let observations = (request.results as? [VNRecognizedTextObservation]) ?? []
      let lines = observations.compactMap { $0.topCandidates(1).first?.string }
      recognized = lines.joined(separator: "\n")
    }
    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = true
    if #available(iOS 16.0, *) {
      request.automaticallyDetectsLanguage = true
    }
    request.recognitionLanguages = ["en-US", "ar-SA"]
    currentRequest = request
    try handler.perform([request])
    currentRequest = nil
    if cancelRequested {
      throw ReceiptOcrError.cancelled
    }
    return recognized.trimmingCharacters(in: .whitespacesAndNewlines)
  }
}

private enum ReceiptOcrError: LocalizedError {
  case cancelled
  case imageNotFound(String)

  var errorDescription: String? {
    switch self {
    case .cancelled:
      return "OCR cancelled"
    case .imageNotFound(let path):
      return "Image not found: \(path)"
    }
  }
}
