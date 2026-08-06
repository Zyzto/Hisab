import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_logging_service/flutter_logging_service.dart';

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
  } on PlatformException catch (e, st) {
    Log.warning(
      'fetchCameraLenses: ${e.code} ${e.message}',
      error: e,
      stackTrace: st,
    );
    return const [];
  } catch (e, st) {
    Log.warning('fetchCameraLenses failed', error: e, stackTrace: st);
    return const [];
  }
}
