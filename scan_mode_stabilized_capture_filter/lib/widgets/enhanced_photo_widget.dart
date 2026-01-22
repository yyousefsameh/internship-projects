import 'dart:io';

import 'package:flutter/material.dart';

class EnhancedPhoto extends StatelessWidget {
  const EnhancedPhoto({super.key, required File? processedFile})
    : _processedFile = processedFile;

  final File? _processedFile;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white, // White background makes the paper scan pop
      width: double.infinity,
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text(
              "After Enhancement",
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(child: Image.file(_processedFile!, fit: BoxFit.contain)),
        ],
      ),
    );
  }
}
