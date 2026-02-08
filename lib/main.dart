import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ayurveda Bio Scanner',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const ScannerPage(),
    );
  }
}

class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key});

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  // Set this to your local IP or the full Localtunnel URL
  // e.g. '192.168.1.5' or 'https://warm-dog-42.loca.lt'
  static const String SERVER_URL = 'https://bio-scanner-api.onrender.com'; 
  
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;
  Map<String, dynamic>? _results;
  String? _errorMessage;

  Future<void> _recordVideo() async {
    try {
      final XFile? video = await _picker.pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(seconds: 30),
      );

      if (video != null) {
        _uploadVideo(File(video.path));
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error picking video: $e';
      });
    }
  }

  Future<void> _uploadVideo(File videoFile) async {
    setState(() {
      _isUploading = true;
      _errorMessage = null;
      _results = null;
    });

    try {
      // Handle both IP addresses and full URLs
      Uri uri;
      if (SERVER_URL.startsWith('http')) {
         uri = Uri.parse('$SERVER_URL/api/upload_test');
      } else {
         uri = Uri.parse('http://$SERVER_URL:5000/api/upload_test');
      }
      
      var request = http.MultipartRequest('POST', uri);
      
      
      request.headers['User-Agent'] = 'BioScannerApp';

      request.fields['patient_id'] = '1'; 
      
      var stream = http.ByteStream(videoFile.openRead());
      var length = await videoFile.length();
      
      var multipartFile = http.MultipartFile(
        'video',
        stream,
        length,
        filename: basename(videoFile.path),
      );
      
      request.files.add(multipartFile);
      
      // Increased timeout to 2 minutes
      var streamedResponse = await request.send().timeout(const Duration(minutes: 2));
      var response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode == 200) {
        var jsonResponse = json.decode(response.body);
        setState(() {
          _results = jsonResponse['results'];
        });
      } else {
        setState(() {
          _errorMessage = 'Server Error: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Connection Error: $e';
      });
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Taila Bindu Pariksha'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              if (_isUploading)
                const Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 20),
                    Text("Analyzing Oil Drop Dynamics..."),
                  ],
                )
              else if (_results != null)
                _buildResultsCard()
              else if (_errorMessage != null)
                 Text(
                   _errorMessage!,
                   style: const TextStyle(color: Colors.red),
                   textAlign: TextAlign.center,
                 )
              else
                const Column(
                  children: [
                    Icon(Icons.monitor_heart, size: 100, color: Colors.teal),
                    SizedBox(height: 20),
                    Text(
                      'Ready to Scan',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    Text('Place camera over the sample and drop the oil.'),
                  ],
                ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isUploading ? null : _recordVideo,
        label: const Text('Start Test'),
        icon: const Icon(Icons.camera_alt),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildResultsCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const Text(
              "Test Results",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.teal),
            ),
            const Divider(),
            const SizedBox(height: 10),
            _resultRow("Spreading Speed", "${_results!['speed']} px/s"),
            _resultRow("Direction", "${_results!['direction']}"),
            _resultRow("Shape Detected", "${_results!['shape']}"),
            _resultRow("Duration", "${_results!['duration_sec']} s"),
            const SizedBox(height: 20),
            const Text(
              "Interpretation",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 5),
            Text(
              _interpretResult(_results!),
              textAlign: TextAlign.center,
              style: const TextStyle(fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }

  Widget _resultRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16)),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  String _interpretResult(Map<String, dynamic> res) {
    String direction = res['direction'];
    String shape = res['shape'];
    
    // Basic Ayurveda Logic (simplified)
    if (direction == 'North' || direction == 'East') {
      return "Prognosis seems Favorable (Good).";
    } else if (direction == 'South' || direction == 'South-West') {
      return "Prognosis requires attention.";
    }
    
    if (shape.contains('Pearl')) {
      return "Indicates Vata Balance/Good.";
    } else if (shape.contains('Snake') || shape.contains('Irregular')) {
      return "Indicates Dosha Imbalance.";
    }
    
    return "Consult an Ayurvedic Practitioner for detailed analysis.";
  }
}

