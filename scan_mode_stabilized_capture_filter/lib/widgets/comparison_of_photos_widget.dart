import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:scan_mode_stabilized_capture_filter/widgets/enhanced_photo_widget.dart';
import 'package:scan_mode_stabilized_capture_filter/widgets/original_photo_widget.dart';

class ComparisonOfPhotosWidget extends StatelessWidget {
  const ComparisonOfPhotosWidget({
    super.key,
    required XFile? rawFile,
    required File? processedFile,
  }) : _rawFile = rawFile,
       _processedFile = processedFile;

  final XFile? _rawFile;
  final File? _processedFile;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Top: The Raw Photo (original one)
        Expanded(child: OriginalPhoto(rawFile: _rawFile)),
        const Divider(height: 4, color: Colors.black38, thickness: 3),
        // Bottom: The Enhanced Scan
        Expanded(child: EnhancedPhoto(processedFile: _processedFile)),
      ],
    );
  }
}
