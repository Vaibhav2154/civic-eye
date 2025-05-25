import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:civiceye/core/theme/app_pallete.dart';
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
  bool isCameraReady = false;
  Timer? _autoStopTimer;
  bool _disposed = false;

  final supabase = Supabase.instance.client;
  static const int RECORDING_DURATION_MINUTES = 10;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupCamera();
    });
  }

  Future<void> _setupCamera() async {
    if (_disposed) return;

    try {
      // Request permissions
      final permissions = await [
        Permission.camera,
        Permission.microphone,
        Permission.storage,
      ].request();

      if (!permissions.values.every((status) => status.isGranted)) {
        print('❌ Permissions denied');
        return;
      }

      // Get cameras
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        print('❌ No cameras found');
        return;
      }

      // Dispose existing controller if any
      await _disposeController();

      // Create new controller
      final camera = cameras.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: true,
      );

      // Initialize camera
      await _cameraController!.initialize();

      if (_disposed || !mounted) return;

      setState(() {
        isCameraReady = true;
      });

      print('✅ Camera ready, starting recording immediately...');

      // Start recording immediately - no delay
      await _startRecording();

    } catch (e) {
      print('❌ Camera setup failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Camera setup failed: $e')),
        );
      }
    }
  }

  Future<void> _startRecording() async {
    if (_disposed || !mounted || _cameraController == null || !isCameraReady) {
      print('❌ Cannot start recording - not ready');
      return;
    }

    if (isRecording) {
      print('⚠️ Already recording');
      return;
    }

    try {
      print('🎥 Starting recording NOW...');
      
      // Start recording immediately
      await _cameraController!.startVideoRecording();
      
      if (_disposed || !mounted) return;

      setState(() {
        isRecording = true;
      });

      print('✅ Recording started successfully');

      // Set auto-stop timer
      _autoStopTimer = Timer(Duration(minutes: RECORDING_DURATION_MINUTES), () {
        if (!_disposed && mounted && isRecording) {
          print('⏰ Auto-stopping after $RECORDING_DURATION_MINUTES minutes');
          _stopRecording();
        }
      });

    } catch (e) {
      print('❌ Recording start failed: $e');
      setState(() {
        isRecording = false;
      });
    }
  }

  Future<void> _stopRecording() async {
    if (_disposed || !isRecording || _cameraController == null) {
      print('❌ Cannot stop recording - not recording or disposed');
      return;
    }

    _autoStopTimer?.cancel();
    _autoStopTimer = null;

    try {
      print('🛑 Stopping recording...');
      
      final XFile videoFile = await _cameraController!.stopVideoRecording();
      
      if (_disposed || !mounted) return;

      setState(() {
        isRecording = false;
      });

      print('📁 Recording stopped: ${videoFile.path}');

      // Process video immediately
      await _processVideo(videoFile);

    } catch (e) {
      print('❌ Stop recording failed: $e');
      if (mounted) {
        setState(() {
          isRecording = false;
        });
      }
    }
  }

  Future<void> _processVideo(XFile videoFile) async {
    try {
      final file = File(videoFile.path);
      
      // Check if file exists and has content
      if (!await file.exists()) {
        print('❌ Video file does not exist');
        return;
      }

      final fileSize = await file.length();
      print('📏 Video file size: $fileSize bytes');

      // Require at least 10KB for a valid video
      if (fileSize < 10240) {
        print('❌ Video file too small: $fileSize bytes');
        
        // Try to read file info for debugging
        try {
          final bytes = await file.readAsBytes();
          print('🔍 File bytes length: ${bytes.length}');
          
          if (bytes.isEmpty) {
            print('❌ File is completely empty');
          } else {
            print('📄 File has content but small size');
          }
        } catch (e) {
          print('❌ Cannot read file: $e');
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('❌ Recording too short or corrupted ($fileSize bytes)')),
          );
        }
        return;
      }

      print('✅ Video file valid, uploading...');
      
      // Upload to Supabase
      final uploadUrl = await _uploadVideo(videoFile.path);
      
      if (uploadUrl != null) {
        await _saveToDatabase(uploadUrl);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ Video uploaded successfully')),
          );
        }
      }

      // Clean up local file
      try {
        await file.delete();
        print('🗑️ Local file deleted');
      } catch (e) {
        print('⚠️ Could not delete local file: $e');
      }

    } catch (e) {
      print('❌ Video processing failed: $e');
    }
  }

  Future<String?> _uploadVideo(String filePath) async {
    try {
      final file = File(filePath);
      final bytes = await file.readAsBytes();
      
      print('📤 Uploading ${bytes.length} bytes...');
      
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_video.mp4';
      
      await supabase.storage.from('stealth').uploadBinary(
        'videos/$fileName',
        bytes,
        fileOptions: const FileOptions(
          contentType: 'video/mp4',
          cacheControl: '3600',
          upsert: true,
        ),
      );

      final publicUrl = supabase.storage.from('stealth').getPublicUrl('videos/$fileName');
      
      print('✅ Upload successful: $publicUrl');
      return publicUrl;

    } catch (e) {
      print('❌ Upload failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Upload failed: $e')),
        );
      }
      return null;
    }
  }

  Future<void> _saveToDatabase(String videoUrl) async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        print('⚠️ No authenticated user');
        return;
      }

      await supabase.from('stealth').insert({
        'userid': user.id,
        'evidence_url': videoUrl,
        'created_at': DateTime.now().toIso8601String(),
      });

      print('✅ Saved to database');
    } catch (e) {
      print('❌ Database save failed: $e');
    }
  }

  Future<void> _disposeController() async {
    _autoStopTimer?.cancel();
    _autoStopTimer = null;

    if (_cameraController != null) {
      try {
        if (_cameraController!.value.isRecordingVideo) {
          await _cameraController!.stopVideoRecording();
        }
        await _cameraController!.dispose();
      } catch (e) {
        print('⚠️ Controller disposal error: $e');
      }
      _cameraController = null;
    }
  }

  // Calculator functions
  void onPressed(String value) {
    if (!_disposed) {
      setState(() {
        displayText += value;
      });
    }
  }

  void clear() {
    if (!_disposed) {
      setState(() => displayText = '');
    }
  }

  void backspace() {
    if (!_disposed) {
      setState(() {
        displayText = displayText.isNotEmpty
            ? displayText.substring(0, displayText.length - 1)
            : '';
      });
    }
  }

  @override
  void dispose() {
    _disposed = true;
    
    // Stop recording and dispose controller
    if (isRecording) {
      _stopRecording().then((_) => _disposeController());
    } else {
      _disposeController();
    }
    
    super.dispose();
  }

  Future<bool> _onWillPop() async {
    if (isRecording && !_disposed) {
      print('🔙 Stopping recording before exit...');
      await _stopRecording();
      await Future.delayed(const Duration(milliseconds: 300));
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Calculator", style: TextStyle(color: Colors.white),),
          backgroundColor: Colors.black,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              await _onWillPop();
              Navigator.of(context).pop();
            },
          ),
        ),
        backgroundColor: Colors.black,
        body: Column(
          children: [
            // Display area
            Expanded(
              child: Container(
                alignment: Alignment.bottomRight,
                padding: const EdgeInsets.all(24),
                child: Text(
                  displayText,
                  style: const TextStyle(color: Colors.white, fontSize: 36),
                ),
              ),
            ),
            
            // Calculator buttons
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                '7', '8', '9', 'C',
                '4', '5', '6', '←',
                '1', '2', '3', '+',
                '0', '.', '=', '-'
              ].map((e) => _buildButton(e)).toList(),
            ),
            
            // Recording indicator (very subtle)
            if (isRecording)
              Container(
                height: 1,
                color: Colors.red.withOpacity(0.2),
              ),
              
            // Debug info (remove in production)
            if (isRecording)
              Container(
                padding: const EdgeInsets.all(4),
                child: Text(
                  'REC',
                  style: TextStyle(color: Colors.red.withOpacity(0.3), fontSize: 8),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildButton(String text) {
    return GestureDetector(
      onTap: () {
        switch (text) {
          case 'C':
            clear();
            break;
          case '←':
            backspace();
            break;
          default:
            onPressed(text);
        }
      },
      child: Container(
        margin: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.grey[850],
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
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
            style: const TextStyle(fontSize: 28, color: Colors.white),
          ),
        ),
      ),
    );
  }
}