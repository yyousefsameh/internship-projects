import 'dart:io';
import 'dart:math' as math;
import 'package:conditional_builder_null_safety/conditional_builder_null_safety.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
// Keeping your custom widget import
import 'package:scan_mode_stabilized_capture_filter/widgets/comparison_of_photos_widget.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras();
  runApp(
    MaterialApp(
      theme: ThemeData.dark(),
      debugShowCheckedModeBanner: false,
      home: ExpertScannerApp(cameras: cameras),
    ),
  );
}

class ExpertScannerApp extends StatefulWidget {
  final List<CameraDescription> cameras;
  const ExpertScannerApp({super.key, required this.cameras});

  @override
  State<ExpertScannerApp> createState() => _ExpertScannerAppState();
}

class _ExpertScannerAppState extends State<ExpertScannerApp> {
  late CameraController _cameraController;
  XFile? _rawFile;
  File? _processedFile;
  bool _isProcessing = false;

  double _sharpness = 0.0;
  double _exposure = 0.0;

  @override
  void initState() {
    super.initState();
    _cameraController = CameraController(
      widget.cameras[0],
      ResolutionPreset.max,
      enableAudio: false, // Audio disabled for smoother stream
    );

    _cameraController.initialize().then((_) {
      if (!mounted) return;

      // START LIVE METRICS STREAM (Analyzing raw frames)
      _cameraController.startImageStream((CameraImage image) {
        if (_processedFile == null && !_isProcessing) {
          _runLiveAnalysis(image);
        }
      });

      setState(() {});
    });
  }

  void _runLiveAnalysis(CameraImage image) {
    // Plane 0 is the Y (Luminance) plane. Perfect for light/sharpness math.
    final bytes = image.planes[0].bytes;
    double totalLuma = 0;
    const int skipedPixels = 150; // Skip pixels for performance

    for (int i = 0; i < bytes.length; i += skipedPixels) {
      totalLuma += bytes[i];
    }
    double avgLuma = totalLuma / (bytes.length / skipedPixels);

    // Sharpness calculation (Variance heuristic)
    double variance = 0;
    for (int i = 0; i < bytes.length; i += skipedPixels * 5) {
      variance += math.pow(bytes[i] - avgLuma, 2);
    }

    if (mounted) {
      setState(() {
        _exposure = avgLuma / 255.0;
        _sharpness = math.sqrt(variance / (bytes.length / (skipedPixels * 5)));
      });
    }
  }

  @override
  void dispose() {
    _cameraController.dispose();
    super.dispose();
  }

  Future<void> runScanEnhancement(XFile photo) async {
    setState(() => _isProcessing = true);

    final bytes = await photo.readAsBytes();
    img.Image? image = img.decodeImage(bytes);

    if (image != null) {
      image = img.bakeOrientation(image);

      // CONTRAST ENHANCEMENT
      image = img.adjustColor(image, contrast: 1.8, brightness: 1.1);

      // SHARPENING (Convolution Filter)
      image = img.convolution(image, filter: [0, -1, 0, -1, 5, -1, 0, -1, 0]);

      // OPTIONAL: "Scanner" Look (Thresholding)
      // image = img.grayscale(image);
      // image = img.luminanceThreshold(image, threshold: 0.6);

      final tempDir = Directory.systemTemp;
      final file = File(
        '${tempDir.path}/scan_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await file.writeAsBytes(img.encodeJpg(image, quality: 90));

      setState(() {
        _rawFile = photo;
        _processedFile = file;
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ConditionalBuilder(
      condition: !_cameraController.value.isInitialized,
      builder: (context) => const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      ),
      fallback: (context) => Scaffold(
        appBar: AppBar(
          title: const Text("EXPERT SCAN MODE"),
          actions: [
            if (_processedFile != null)
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => setState(() => _processedFile = null),
              ),
          ],
        ),
        body: Stack(
          children: [
            Positioned.fill(
              child: _processedFile == null
                  ? CameraPreview(_cameraController)
                  : ComparisonOfPhotosWidget(
                      processedFile: _processedFile,
                      rawFile: _rawFile,
                    ),
            ),

            if (_processedFile == null) _buildMetricsOverlay(),

            if (_processedFile == null && !_isProcessing)
              Positioned(
                bottom: 40,
                left: 0,
                right: 0,
                child: Center(
                  child: FloatingActionButton.large(
                    backgroundColor: Colors.white,
                    onPressed: () async {
                      final photo = await _cameraController.takePicture();
                      await runScanEnhancement(photo);
                    },
                    child: const Icon(
                      Icons.camera_alt_outlined,
                      color: Colors.black,
                      size: 40,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Helper widget to show live analytics for your screen recording
  Widget _buildMetricsOverlay() {
    bool isSharp = _sharpness > 20;
    bool isLit = _exposure > 0.3 && _exposure < 0.8;

    return Positioned(
      top: 20,
      left: 20,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "SHARPNESS: ${_sharpness.toStringAsFixed(1)} ${isSharp ? '✅' : '❌'}",
              style: TextStyle(
                color: isSharp ? Colors.greenAccent : Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              "EXPOSURE: ${(_exposure * 100).toStringAsFixed(0)}% ${isLit ? '✅' : '❌'}",
              style: TextStyle(
                color: isLit ? Colors.greenAccent : Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
