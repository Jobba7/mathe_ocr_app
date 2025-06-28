import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

void main() => runApp(const MatheOcrApp());

class MatheOcrApp extends StatelessWidget {
  const MatheOcrApp({super.key});
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: OCRScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class OCRScreen extends StatefulWidget {
  const OCRScreen({super.key});
  @override
  State<OCRScreen> createState() => _OCRScreenState();
}

class _OCRScreenState extends State<OCRScreen> {
  File? _image;
  final List<RecognizedMathBlock> _recognizedTasks = [];
  final List<RecognizedMathBlock> _selectedTasks = [];

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.camera);
    if (picked == null) return;

    final imageFile = File(picked.path);
    setState(() {
      _image = imageFile;
      _recognizedTasks.clear();
      _selectedTasks.clear();
    });

    final inputImage = InputImage.fromFile(imageFile);
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final recognizedText = await textRecognizer.processImage(inputImage);
    await textRecognizer.close();

    for (final block in recognizedText.blocks) {
      print('Erkannt: "${block.text}"');
      if (_isSimpleMathTask(block.text)) {
        _recognizedTasks.add(
          RecognizedMathBlock(block.text, block.boundingBox),
        );
      }
    }

    setState(() {});
  }

  bool _isSimpleMathTask(String text) {
    return true;
    final pattern = RegExp(r'^\s*\d+\s*[\+\-\*/:]\s*\d+.*$');
    return pattern.hasMatch(text.trim());
  }

  void _toggleSelection(RecognizedMathBlock task) {
    setState(() {
      _selectedTasks.contains(task)
          ? _selectedTasks.remove(task)
          : _selectedTasks.add(task);
    });
  }

  Future<Size> _getImageSize(File imageFile) async {
    final decodedImage = await decodeImageFromList(imageFile.readAsBytesSync());
    return Size(decodedImage.width.toDouble(), decodedImage.height.toDouble());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Mathe OCR")),
      body: Column(
        children: [
          ElevatedButton(
            onPressed: _pickImage,
            child: const Text("Bild aufnehmen"),
          ),
          Expanded(
            child: _image == null
                ? const Center(child: Text('Kein Bild ausgewählt'))
                : LayoutBuilder(
                    builder: (context, constraints) {
                      return FutureBuilder<Size>(
                        future: _getImageSize(_image!),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }

                          final imageSize = snapshot.data!;
                          final containerWidth = constraints.maxWidth;
                          final containerHeight = constraints.maxHeight;

                          final imageAspect =
                              imageSize.width / imageSize.height;
                          final containerAspect =
                              containerWidth / containerHeight;

                          double displayWidth, displayHeight;
                          double dx = 0, dy = 0;

                          if (containerAspect > imageAspect) {
                            // Container ist breiter → Bild hat oben/unten freien Platz
                            displayHeight = containerHeight;
                            displayWidth = imageAspect * displayHeight;
                            dx = (containerWidth - displayWidth) / 2;
                          } else {
                            // Container ist höher → Bild hat links/rechts freien Platz
                            displayWidth = containerWidth;
                            displayHeight = displayWidth / imageAspect;
                            dy = (containerHeight - displayHeight) / 2;
                          }

                          final scaleX = displayWidth / imageSize.width;
                          final scaleY = displayHeight / imageSize.height;

                          return Stack(
                            children: [
                              Positioned.fill(
                                child: Image.file(_image!, fit: BoxFit.contain),
                              ),
                              ..._recognizedTasks.map((task) {
                                final rect = task.boundingBox;
                                return Positioned(
                                  left: rect.left * scaleX + dx,
                                  top: rect.top * scaleY + dy,
                                  width: rect.width * scaleX,
                                  height: rect.height * scaleY,
                                  child: GestureDetector(
                                    onTap: () => _toggleSelection(task),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: _selectedTasks.contains(task)
                                              ? Colors.green
                                              : Colors.red,
                                          width: 2,
                                        ),
                                        color: _selectedTasks.contains(task)
                                            ? Colors.green.withOpacity(0.2)
                                            : Colors.red.withOpacity(0.2),
                                      ),
                                      child: Center(
                                        child: Text(
                                          task.text,
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ],
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class RecognizedMathBlock {
  final String text;
  final Rect boundingBox;

  RecognizedMathBlock(this.text, this.boundingBox);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecognizedMathBlock &&
          text == other.text &&
          boundingBox == other.boundingBox;

  @override
  int get hashCode => text.hashCode ^ boundingBox.hashCode;
}
