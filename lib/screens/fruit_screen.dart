import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

class FruitScreen extends StatefulWidget {
  const FruitScreen({super.key});

  @override
  State<FruitScreen> createState() => _FruitScreenState();
}

class _FruitScreenState extends State<FruitScreen> {
  File? _imageFile;
  Uint8List? _webImage;
  List<MapEntry<String, double>> _predictions = [];
  bool _modelLoaded = false;
  late Interpreter _interpreter;
  List<String> _labels = [];
  final ImagePicker _picker = ImagePicker();

  // Adjust these according to your model's input size
  // Teachable Machine standard is usually 224x224
  final int inputHeight = 224;
  final int inputWidth = 224;

  @override
  void initState() {
    super.initState();
    _loadModel();
  }

  Future<void> _loadModel() async {
    try {
      // Fixed: Added 'assets/' prefix to the model path
      _interpreter = await Interpreter.fromAsset('assets/models/fruit_model.tflite');
      
      
      if (!mounted) return;
      final rawLabels = await DefaultAssetBundle.of(context).loadString('assets/models/labels.txt');
      _labels = rawLabels
          .split('\n')
          .where((l) => l.trim().isNotEmpty)
          .map((l) => l.replaceAll(RegExp(r'^\d+\s+'), '').trim()) // Remove leading numbers
          .toList();
      
      setState(() => _modelLoaded = true);
      debugPrint("✅ Model loaded successfully");
      debugPrint("✅ Loaded ${_labels.length} labels: $_labels");
    } catch (e) {
      debugPrint("❌ Failed to load model: $e");
      setState(() => _modelLoaded = false);
    }
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    if (kIsWeb) {
      final bytes = await picked.readAsBytes();
      setState(() {
        _webImage = bytes;
        _imageFile = null;
        _predictions = [];
      });
      if (_modelLoaded) _classifyImage(bytes: bytes);
    } else {
      setState(() {
        _imageFile = File(picked.path);
        _webImage = null;
        _predictions = [];
      });
      if (_modelLoaded) _classifyImage(file: File(picked.path));
    }
  }

  Future<void> _classifyImage({File? file, Uint8List? bytes}) async {
    img.Image? image;
    
    if (file != null) {
      final fileBytes = await file.readAsBytes();
      image = img.decodeImage(fileBytes);
    } else if (bytes != null) {
      image = img.decodeImage(bytes);
    }

    if (image == null) return;

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
    _interpreter.run(inputBuffer, outputBuffer);

    // Find top 3 probabilities
    var map = Map<String, double>.fromIterables(_labels, outputBuffer[0]);
    var sortedEntries = map.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    
    setState(() {
      _predictions = sortedEntries.take(3).toList();
    });
  }

  @override
  void dispose() {
    _interpreter.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Fruit Classifier"),
        backgroundColor: Colors.teal,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Image Display
            kIsWeb
                ? (_webImage == null
                    ? Container(
                        height: 250,
                        color: Colors.grey[300],
                        child: const Center(child: Text("No image selected")),
                      )
                    : Image.memory(_webImage!, height: 250))
                : (_imageFile == null
                    ? Container(
                        height: 250,
                        color: Colors.grey[300],
                        child: const Center(child: Text("No image selected")),
                      )
                    : Image.file(_imageFile!, height: 250)),
            
            const SizedBox(height: 20),
            
            // Pick Image Button
            ElevatedButton(
              onPressed: _pickImage,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
              ),
              child: const Text(
                "Pick an Image",
                style: TextStyle(fontSize: 16),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Model Status
            if (!_modelLoaded)
              const Text(
                "⚠️ Model not loaded",
                style: TextStyle(color: Colors.red, fontSize: 16),
              ),
            
            const SizedBox(height: 10),
            
            // Prediction Result
            // Predictions Display
            ..._predictions.asMap().entries.map((entry) {
              int index = entry.key;
              String label = entry.value.key;
              double confidence = entry.value.value;
              
              // Styling based on rank
              double height = index == 0 ? 60 : (index == 1 ? 50 : 40);
              double fontSize = index == 0 ? 24 : (index == 1 ? 18 : 14);
              Color color = index == 0 
                  ? Colors.teal 
                  : (index == 1 ? Colors.teal.shade400 : Colors.teal.shade200);
              
              return Container(
                margin: const EdgeInsets.symmetric(vertical: 5),
                width: double.infinity,
                height: height,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 4,
                      offset: const Offset(2, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    "$label ${(confidence * 100).toStringAsFixed(1)}%",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: fontSize,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            }).toList(),
            
            if (_predictions.isEmpty && _imageFile != null)
               const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}

// Extension methods for reshaping
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