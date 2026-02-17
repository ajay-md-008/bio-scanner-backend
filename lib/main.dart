import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'camera_page.dart';

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
  File? _videoFile; // New state variable for the video file

  Future<bool> _checkServerHealth() async {
    try {
      final response = await http.get(Uri.parse('$SERVER_URL/health')).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        return true;
      }
    } catch (e) {
      print('Health Check Failed: $e');
    }
    return false;
  }



  // ... (inside class)

  Future<void> _recordVideo() async {
    // 1. Check Server Connection Alert
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text("Connecting to Cloud Server..."),
            ],
          ),
        );
      },
    );

    bool isConnected = await _checkServerHealth();
    Navigator.pop(context); // Close loading dialog

    if (!isConnected) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Connection Error"),
          content: const Text("Could not connect to the Backend Server.\n\nPossible reasons:\n1. Server is waking up (Wait 30s and try again).\n2. No Internet Connection."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK"),
            ),
          ],
        ),
      );
      return;
    }

    // Server is Connected! 
    // Navigate to Custom Camera Page
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BioCameraPage(
          onVideoRecorded: (video) {
            setState(() {
              _videoFile = File(video.path);
              _results = null;
              _errorMessage = null;
            });
            _uploadVideo(); // Auto-upload after recording
          },
        ),
      ),
    );
  }

  Future<void> _uploadVideo() async {
    if (_videoFile == null) {
      setState(() {
        _errorMessage = 'No video file selected.';
      });
      return;
    }

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
      
      var stream = http.ByteStream(_videoFile!.openRead());
      var length = await _videoFile!.length();
      
      var multipartFile = http.MultipartFile(
        'video',
        stream,
        length,
        filename: p.basename(_videoFile!.path),
      );
      
      request.files.add(multipartFile);
      
      // Increased timeout to 2 minutes
      var streamedResponse = await request.send().timeout(const Duration(minutes: 5));
      var response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode == 200) {
        var jsonResponse = json.decode(response.body);
        setState(() {
          _results = jsonResponse['results'];
        });
      } else {
        String errorMsg;
        try {
          var jsonResponse = json.decode(response.body);
          errorMsg = jsonResponse['error'] ?? 'Unknown Error';
        } catch (_) {
          // If response is not JSON (e.g., HTML 502/504 page)
          if (response.body.contains('<html')) {
             errorMsg = 'Gateway Error (Server Overload/Timeout)';
          } else {
             errorMsg = response.body.length > 50 ? response.body.substring(0, 50) : response.body;
          }
        }
        setState(() {
          _errorMessage = 'Server Error (${response.statusCode}): $errorMsg';
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
            _resultRow("Circularity", "${_results!['circularity'] ?? 'N/A'}"),
            _resultRow("Irregularity", "${_results!['irregularity'] ?? 'N/A'}"),
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
    double circularity = res['circularity'] is String ? double.tryParse(res['circularity']) ?? 0.0 : (res['circularity'] ?? 0.0).toDouble();
    
    // Ayurvedic Logic based on User's Notes
    if (circularity >= 0.9) {
      return "Excellent Prognosis (Sadhyasadhya: Sukh Sadhya). Shape is a perfect circle.";
    } else if (circularity >= 0.7) {
      return "Good Prognosis. Slight irregularity detected.";
    } else if (circularity <= 0.6) {
      return "Irregular Shape detected (Asadhya/Krichra Sadhya). Indicates Dosha imbalance.";
    }
    
    if (direction == 'North' || direction == 'East') {
      return "Direction indicates favorable outcome.";
    }
    
    return "Consult an Ayurvedic Practitioner.";
  }
}

