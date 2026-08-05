import Flutter
import Photos
import UIKit

/// MethodChannel bridge that returns a JPEG of the newest Photos library image.
final class GalleryThumbBridge: NSObject {
  static let channelName = "hisab/gallery_thumb"
  private static let maxEdge: CGFloat = 256

  private let queue = DispatchQueue(
    label: "com.shenepoy.hisab.gallery_thumb",
    qos: .userInitiated
  )

  static func register(with messenger: FlutterBinaryMessenger) {
    let bridge = GalleryThumbBridge()
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      bridge.handle(call, result: result)
    }
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "latestThumb":
      queue.async { [weak self] in
        guard let self else { return }
        self.loadLatestThumb { data in
          DispatchQueue.main.async { result(data) }
        }
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func loadLatestThumb(completion: @escaping (FlutterStandardTypedData?) -> Void) {
    let status: PHAuthorizationStatus
    if #available(iOS 14, *) {
      status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    } else {
      status = PHPhotoLibrary.authorizationStatus()
    }
    let allowed: Bool
    if #available(iOS 14, *) {
      allowed = status == .authorized || status == .limited
    } else {
      allowed = status == .authorized
    }
    guard allowed else {
      completion(nullData())
      return
    }

    let options = PHFetchOptions()
    options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
    options.fetchLimit = 1
    let assets = PHAsset.fetchAssets(with: .image, options: options)
    guard let asset = assets.firstObject else {
      completion(nullData())
      return
    }

    let target = CGSize(width: Self.maxEdge, height: Self.maxEdge)
    let req = PHImageRequestOptions()
    req.deliveryMode = .highQualityFormat
    req.resizeMode = .fast
    req.isNetworkAccessAllowed = true
    req.isSynchronous = true

    var output: FlutterStandardTypedData?
    PHImageManager.default().requestImage(
      for: asset,
      targetSize: target,
      contentMode: .aspectFill,
      options: req
    ) { image, _ in
      guard let image else { return }
      guard let jpeg = image.jpegData(compressionQuality: 0.82) else { return }
      output = FlutterStandardTypedData(bytes: jpeg)
    }
    completion(output)
  }

  private func nullData() -> FlutterStandardTypedData? { nil }
}
