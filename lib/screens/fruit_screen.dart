import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import '../services/ml_service.dart';

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
  late MLService _mlService;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _mlService = MLService.create();
    _loadModel();
  }

  Future<void> _loadModel() async {
    await _mlService.loadModel();
    if(mounted) {
        setState(() => _modelLoaded = true);
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

    final predictions = await _mlService.classifyImage(image: image);
    
    setState(() {
      _predictions = predictions;
    });
  }

  @override
  void dispose() {
    _mlService.dispose();
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

             if (kIsWeb)
              const Padding(
                padding: EdgeInsets.only(top: 8.0),
                child: Text(
                  "ML classification is not supported on Web",
                  style: TextStyle(color: Colors.orange, fontStyle: FontStyle.italic),
                ),
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
            
            if (_predictions.isEmpty && _imageFile != null && !kIsWeb)
               const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}