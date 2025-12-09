

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'ml_service.dart';

class MLServiceWeb implements MLService {
  @override
  Future<void> loadModel() async {
    // Web stub: Do nothing or log
    debugPrint('MLServiceWeb: Model loading not supported on web yet.');
  }

  @override
  Future<List<MapEntry<String, double>>> classifyImage({img.Image? image}) async {
    // Web stub: Return empty or dummy
    debugPrint('MLServiceWeb: Classification not supported on web yet.');
    return [];
  }

  @override
  void dispose() {}
}

MLService createMLService() => MLServiceWeb();
