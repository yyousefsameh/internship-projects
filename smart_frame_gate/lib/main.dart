import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras();
  runApp(MaterialApp(home: SmartFrameGate(cameras: cameras)));
}

class SmartFrameGate extends StatefulWidget {
  final List<CameraDescription> cameras;
  const SmartFrameGate({super.key, required this.cameras});

  @override
  State<SmartFrameGate> createState() => _SmartFrameGateState();
}

class _SmartFrameGateState extends State<SmartFrameGate> {
  CameraController? _controller;
  bool _isAnalyzing = false;

  // Real-time Scores
  double _sharpness = 0.0;
  double _exposure = 0.0;
  double _motion = 0.0;
  double _prevLuma = 0.0;

  final List<CameraImage> _bestFrames = [];
  int _countdown = 15;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    _controller = CameraController(
      widget.cameras[0],
      ResolutionPreset.medium,
      enableAudio: false,
    );
    await _controller!.initialize();
    setState(() {});
  }

  void _toggleCapture() {
    if (_isAnalyzing) {
      _stopCapture();
    } else {
      _startCapture();
    }
  }

  void _startCapture() {
    _bestFrames.clear();
    _countdown = 15;
    setState(() => _isAnalyzing = true);

    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_countdown > 0) {
        setState(() => _countdown--);
      } else {
        _stopCapture();
      }
    });

    _controller?.startImageStream((image) {
      if (!_isAnalyzing) return;
      _processFrame(image);
    });
  }

  void _processFrame(CameraImage image) {
    // Plane 0 is the Y (Luminance) channel. Fast access, no conversion needed.
    final bytes = image.planes[0].bytes;
    final int step = 200; // Sample for speed

    double sum = 0;
    for (int i = 0; i < bytes.length; i += step) {
      sum += bytes[i];
    }
    double avgLuma = sum / (bytes.length / step);

    // 1. Exposure Score (Target: 0.4 - 0.7)
    double exposure = avgLuma / 255.0;

    // 2. Motion/Shake Score (Delta between frames)
    double motion = (avgLuma - _prevLuma).abs();
    _prevLuma = avgLuma;

    // 3. Sharpness Score (Variance of pixel values)
    double variance = 0;
    for (int i = 0; i < bytes.length; i += step) {
      variance += math.pow(bytes[i] - avgLuma, 2);
    }
    double sharpness = math.sqrt(variance / (bytes.length / step));

    // GATE LOGIC: Accept only if quality is high
    bool isSharp = sharpness > 25.0;
    bool isStable = motion < 5.0;
    bool isExposed = exposure > 0.3 && exposure < 0.8;

    if (isSharp && isStable && isExposed && _bestFrames.length < 10) {
      _bestFrames.add(image);
    }

    if (mounted) {
      setState(() {
        _sharpness = sharpness;
        _exposure = exposure;
        _motion = motion;
      });
    }

    if (_bestFrames.length >= 10) _stopCapture();
  }

  void _stopCapture() {
    _isAnalyzing = false;
    _controller?.stopImageStream();
    _timer?.cancel();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold();
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          CameraPreview(_controller!),
          _buildMetricsUI(),
          if (_bestFrames.length >= 10) _buildSuccessBadge(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _isAnalyzing ? Colors.red : Colors.blue,
        onPressed: _toggleCapture,
        label: Text(_isAnalyzing ? "STOP ($_countdown)" : "START SCAN"),
        icon: Icon(_isAnalyzing ? Icons.stop : Icons.play_arrow),
      ),
    );
  }

  Widget _buildMetricsUI() {
    return Positioned(
      top: 60,
      left: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _metricRow("SHARPNESS", _sharpness, 25.0),
          _metricRow("STABILITY", _motion, 5.0, inverse: true),
          _metricRow("EXPOSURE", _exposure * 100, 40.0),
          const SizedBox(height: 20),
          Text(
            "COLLECTED: ${_bestFrames.length}/10",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricRow(
    String label,
    double val,
    double target, {
    bool inverse = false,
  }) {
    bool passed = inverse ? val < target : val > target;
    return Text(
      "$label: ${val.toStringAsFixed(1)} ${passed ? '✅' : '❌'}",
      style: TextStyle(
        color: passed ? Colors.greenAccent : Colors.redAccent,
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildSuccessBadge() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(20),
        color: Colors.black87,
        child: const Text(
          "CAPTURE COMPLETE\n10 QUALITY FRAMES SAVED",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.green, fontSize: 20),
        ),
      ),
    );
  }
}
