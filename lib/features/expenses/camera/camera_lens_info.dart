/// One physical / logical camera from the OS Camera2 (or stub) catalog.
class CameraLensInfo {
  const CameraLensInfo({
    required this.id,
    required this.facing,
    required this.minZoom,
    required this.maxZoom,
    required this.focalMm,
    required this.sensorWmm,
    required this.sensorHmm,
    required this.hfovDeg,
  });

  final String id;
  final String facing; // front | back | external
  final double minZoom;
  final double maxZoom;
  final double focalMm;
  final double sensorWmm;
  final double sensorHmm;
  final double hfovDeg;

  factory CameraLensInfo.fromMap(Map<dynamic, dynamic> map) {
    double d(Object? v) => (v as num?)?.toDouble() ?? 0;
    return CameraLensInfo(
      id: '${map['id']}',
      facing: '${map['facing'] ?? ''}',
      minZoom: d(map['minZoom']),
      maxZoom: d(map['maxZoom']),
      focalMm: d(map['focalMm']),
      sensorWmm: d(map['sensorWmm']),
      sensorHmm: d(map['sensorHmm']),
      hfovDeg: d(map['hfovDeg']),
    );
  }
}
