import 'package:flutter_riverpod/legacy.dart' show StateProvider;

/// Debug menu toggle: receipt camera uses an animated mock preview (no hardware).
///
/// Only honored when [kDebugMode] / debug package — the expense form gates on that.
final debugReceiptCameraMockProvider = StateProvider<bool>((ref) => false);
