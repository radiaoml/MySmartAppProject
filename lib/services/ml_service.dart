
import 'dart:typed_data';
import 'package:image/image.dart' as img;

import 'ml_service_stub.dart'
    if (dart.library.io) 'ml_service_mobile.dart'
    if (dart.library.html) 'ml_service_web.dart';

abstract class MLService {
  Future<void> loadModel();
  Future<List<MapEntry<String, double>>> classifyImage({img.Image? image});
  void dispose();
  
  static MLService create() => createMLService();
}
