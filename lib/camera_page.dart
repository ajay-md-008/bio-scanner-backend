import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class BioCameraPage extends StatefulWidget {
  final Function(XFile) onVideoRecorded;

  const BioCameraPage({super.key, required this.onVideoRecorded});

  @override
  State<BioCameraPage> createState() => _BioCameraPageState();
}

class _BioCameraPageState extends State<BioCameraPage> {
  CameraController? _controller;
  bool _isRecording = false;
  String _statusText = "Align Bowl in Green Box";
  List<CameraDescription> _cameras = [];

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    // Request Permissions
    await [Permission.camera, Permission.microphone].request();

    _cameras = await availableCameras();
    if (_cameras.isEmpty) return;

    // Use back camera
    final backCamera = _cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.back,
      orElse: () => _cameras.first,
    );

    _controller = CameraController(
      backCamera,
      ResolutionPreset.high, // Better quality for analysis
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    await _controller!.initialize();
    if (mounted) setState(() {});
  }

  Future<void> _startRecording() async {
    if (_controller == null || _controller!.value.isRecordingVideo) return;

    try {
      await _controller!.startVideoRecording();
      setState(() {
        _isRecording = true;
        _statusText = "Recording... Drop Oil Now!";
      });
      
      // Auto-stop after 3 minutes max
      Future.delayed(const Duration(seconds: 180), () {
        if (mounted && _isRecording) _stopRecording();
      });
      
    } catch (e) {
      print(e);
    }
  }

  Future<void> _stopRecording() async {
    if (_controller == null || !_isRecording) return;

    try {
      XFile videoFile = await _controller!.stopVideoRecording();
      setState(() {
        _isRecording = false;
        _statusText = "Processing...";
      });
      widget.onVideoRecorded(videoFile);
      Navigator.pop(context);
    } catch (e) {
      print(e);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Camera Preview
          Center(child: CameraPreview(_controller!)),
          
          // 2. Green Box Overlay
          Center(
            child: Container(
              width: 280, // Size of the bowl view
              height: 280,
              decoration: BoxDecoration(
                border: Border.all(
                  color: _isRecording ? Colors.redAccent : Colors.greenAccent, 
                  width: 3
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    spreadRadius: 2000, // Dim everything outside the box
                  )
                ]
              ),
              child: _isRecording 
                ? null 
                : const Icon(Icons.add, color: Colors.greenAccent, size: 40), // Crosshair
            ),
          ),
          
          // 3. Status Text
          Positioned(
            top: 60,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _statusText,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white, 
                  fontSize: 18, 
                  fontWeight: FontWeight.bold
                ),
              ),
            ),
          ),

          // 4. Controls
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: FloatingActionButton.extended(
                onPressed: _isRecording ? _stopRecording : _startRecording,
                label: Text(
                  _isRecording ? "STOP RECORDING" : "START TEST",
                  style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2),
                ),
                icon: Icon(_isRecording ? Icons.stop_circle : Icons.videocam, size: 30),
                backgroundColor: _isRecording ? Colors.red : Colors.teal,
                foregroundColor: Colors.white,
                elevation: 10,
              ),
            ),
          ),
          
          // Back Button
          Positioned(
            top: 40,
            left: 10,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }
}
