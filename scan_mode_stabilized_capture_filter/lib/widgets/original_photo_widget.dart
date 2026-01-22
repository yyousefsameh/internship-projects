import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class OriginalPhoto extends StatelessWidget {
  const OriginalPhoto({super.key, required XFile? rawFile})
    : _rawFile = rawFile;

  final XFile? _rawFile;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey[900],
      width: double.infinity,
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text("Before Enhancement"),
          ),
          Expanded(
            child: Image.file(File(_rawFile!.path), fit: BoxFit.contain),
          ),
        ],
      ),
    );
  }
}
