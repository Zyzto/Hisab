import 'dart:io' show Platform;

import 'package:image_picker_android/image_picker_android.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';

/// Enables the Android Photo Picker so gallery access does not require
/// READ_MEDIA_IMAGES. No-op on non-Android.
void initImagePicker() {
  if (!Platform.isAndroid) return;
  final impl = ImagePickerPlatform.instance;
  if (impl is ImagePickerAndroid) {
    impl.useAndroidPhotoPicker = true;
  }
}
