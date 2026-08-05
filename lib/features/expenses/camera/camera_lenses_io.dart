import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'camera_lens_info.dart';

const _channel = MethodChannel('hisab/camera_lenses');

Future<List<CameraLensInfo>> fetchCameraLenses() async {
  if (kIsWeb) return const [];
  try {
    final raw = await _channel.invokeMethod<dynamic>('listLenses');
    if (raw is! List) return const [];
    return [
      for (final item in raw)
        if (item is Map) CameraLensInfo.fromMap(item),
    ];
  } on PlatformException catch (e) {
    debugPrint('fetchCameraLenses: ${e.code} ${e.message}');
    return const [];
  } catch (e) {
    debugPrint('fetchCameraLenses failed: $e');
    return const [];
  }
}
