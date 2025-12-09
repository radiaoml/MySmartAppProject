
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'ml_service.dart';

class MLServiceMobile implements MLService {
  Interpreter? _interpreter;
  List<String> _labels = [];
  bool _isModelLoaded = false;

  final int inputHeight = 224;
  final int inputWidth = 224;

  @override
  Future<void> loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset('assets/models/fruit_model.tflite');
      
      final rawLabels = await rootBundle.loadString('assets/models/labels.txt');
      _labels = rawLabels
          .split('\n')
          .where((l) => l.trim().isNotEmpty)
          .map((l) => l.replaceAll(RegExp(r'^\d+\s+'), '').trim())
          .toList();
      
      _isModelLoaded = true;
      debugPrint("✅ MLServiceMobile: Model loaded successfully");
    } catch (e) {
      debugPrint("❌ MLServiceMobile: Failed to load model: $e");
      _isModelLoaded = false;
    }
  }

  @override
  Future<List<MapEntry<String, double>>> classifyImage({img.Image? image}) async {
    if (!_isModelLoaded || _interpreter == null || image == null) {
      return [];
    }

    // Resize to model input
    final resized = img.copyResize(image, width: inputWidth, height: inputHeight);

    // Prepare input tensor
    final input = Float32List(inputHeight * inputWidth * 3);
    int idx = 0;

    for (int y = 0; y < inputHeight; y++) {
      for (int x = 0; x < inputWidth; x++) {
        final img.Pixel pixel = resized.getPixel(x, y);
        final int r = pixel.r.toInt();
        final int g = pixel.g.toInt();
        final int b = pixel.b.toInt();
        
        // Normalization [0, 1] RGB
        input[idx++] = r / 255.0; // Red
        input[idx++] = g / 255.0; // Green
        input[idx++] = b / 255.0; // Blue
      }
    }

    // Reshape input
    final inputBuffer = input.reshape([1, inputHeight, inputWidth, 3]);

    // Prepare output
    final outputBuffer = List.filled(_labels.length, 0.0).reshape([1, _labels.length]);

    // Run inference
    _interpreter!.run(inputBuffer, outputBuffer);

    // Find top 3 probabilities
    var map = Map<String, double>.fromIterables(_labels, outputBuffer[0]);
    var sortedEntries = map.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    
    return sortedEntries.take(3).toList();
  }

  @override
  void dispose() {
    _interpreter?.close();
  }
}

// Extension methods for reshaping (copied from original because they were local extensions)
extension Float32ListReshape on Float32List {
  List<List<List<List<double>>>> reshape(List<int> shape) {
    final List<List<List<List<double>>>> result =
        List.generate(shape[0], (_) => List.generate(shape[1], (_) => List.generate(shape[2], (_) => List.filled(shape[3], 0.0))));
    
    int idx = 0;
    for (int b = 0; b < shape[0]; b++) {
      for (int h = 0; h < shape[1]; h++) {
        for (int w = 0; w < shape[2]; w++) {
          for (int c = 0; c < shape[3]; c++) {
            result[b][h][w][c] = this[idx++];
          }
        }
      }
    }
    return result;
  }
}

extension ListDoubleReshape on List<double> {
  List<List<double>> reshape(List<int> shape) {
    final List<List<double>> result = List.generate(shape[0], (_) => List.filled(shape[1], 0.0));
    
    int idx = 0;
    for (int i = 0; i < shape[0]; i++) {
      for (int j = 0; j < shape[1]; j++) {
        result[i][j] = this[idx++];
      }
    }
    return result;
  }
}

MLService createMLService() => MLServiceMobile();
