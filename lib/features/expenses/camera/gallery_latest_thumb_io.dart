import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

const _channel = MethodChannel('hisab/gallery_thumb');

/// Most recent Camera Roll / MediaStore image as a small JPEG, or null.
///
/// Requests photos access only when needed (system sheet). Does not show
/// Hisab's custom permanently-denied dialog — camera UI stays usable.
Future<Uint8List?> fetchLatestGalleryThumb() async {
  if (kIsWeb) return null;

  var status = await Permission.photos.status;
  if (status.isDenied) {
    status = await Permission.photos.request();
  }
  if (!status.isGranted && !status.isLimited) return null;

  try {
    final raw = await _channel.invokeMethod<dynamic>('latestThumb');
    if (raw is Uint8List) return raw.isEmpty ? null : raw;
    if (raw is List<int>) {
      final bytes = Uint8List.fromList(raw);
      return bytes.isEmpty ? null : bytes;
    }
    return null;
  } on PlatformException catch (e) {
    debugPrint('fetchLatestGalleryThumb: ${e.code} ${e.message}');
    return null;
  } catch (e) {
    debugPrint('fetchLatestGalleryThumb failed: $e');
    return null;
  }
}
