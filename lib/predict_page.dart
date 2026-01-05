import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart' show rootBundle;

class PredictPage extends StatefulWidget {
  const PredictPage({super.key});

  @override
  State<PredictPage> createState() => _PredictPageState();
}

class _PredictPageState extends State<PredictPage> {
  late Interpreter _interpreter;
  List<String> classNames = [];
  bool _isLoading = false;
  String _result = "";
  File? _selectedImage;

  @override
  void initState() {
    super.initState();
    _loadModelAndClasses();
  }

  Future<void> _loadModelAndClasses() async {
    try {
      // Load TFLite model
      _interpreter = await Interpreter.fromAsset('assets/model/plant_disease_model_final.tflite');
      debugPrint("✅ Model loaded successfully");

      // Load class names
      final txt = await rootBundle.loadString('assets/model/class_names.txt');
      classNames = txt.split('\n').where((e) => e.trim().isNotEmpty).toList();
      debugPrint("✅ Loaded ${classNames.length} class names");
    } catch (e) {
      debugPrint("❌ Error loading model or classes: $e");
    }
  }







  Future<void> _predict(File imageFile) async {
    setState(() {
      _isLoading = true;
      _result = "";
    });

    try {
      final img.Image? image = img.decodeImage(await imageFile.readAsBytes());
      if (image == null) return;

      final resized = img.copyResize(image, width: 224, height: 224);

      // 1. Create a flat Float32List (1 * 224 * 224 * 3)
      var input = Float32List(1 * 224 * 224 * 3);
      var bufferIndex = 0;

      // 2. Fill the flat list with normalized values
      for (int y = 0; y < 224; y++) {
        for (int x = 0; x < 224; x++) {
          final pixel = resized.getPixel(x, y);

          // Add to buffer and increment index
          input[bufferIndex++] = (pixel.r.toDouble() / 127.5) - 1.0;
          input[bufferIndex++] = (pixel.g.toDouble() / 127.5) - 1.0;
          input[bufferIndex++] = (pixel.b.toDouble() / 127.5) - 1.0;
        }
      }

      var output = List.filled(classNames.length, 0.0).reshape([1, classNames.length]);

      // 3. Reshape the flat list on the fly for the interpreter
      _interpreter.run(input.reshape([1, 224, 224, 3]), output);

      final List<double> scores = output[0].cast<double>();
      final double confidence = scores.reduce((a, b) => a > b ? a : b);
      final int predictedIndex = scores.indexOf(confidence);

      setState(() {
        _isLoading = false;
        _selectedImage = imageFile;
        _result = "🌿 Predicted: ${classNames[predictedIndex]}\n🧠 Confidence: ${(confidence * 100).toStringAsFixed(2)}%";
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _result = 'Prediction failed.';
      });
    }
  }







  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      setState(() => _selectedImage = file);
      await _predict(file);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      
      appBar: AppBar(
        title: const Text("🌱 Plant Disease Detector"),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Center(
          child: _isLoading
              ? const CircularProgressIndicator()
              : SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_selectedImage != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.file(_selectedImage!, height: 200),
                  ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.image_search),
                  label: const Text("Pick Image"),
                ),
                const SizedBox(height: 20),
                Text(
                  _result,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
