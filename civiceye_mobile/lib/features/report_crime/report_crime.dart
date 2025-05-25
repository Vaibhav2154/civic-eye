import 'dart:convert';
import 'dart:io';
import 'package:civiceye/core/constants/api_constants.dart'; // Assuming you have this for API constants
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart'; // For generating UUIDs
import 'dart:ui'; // For BackdropFilter
import 'package:image_picker/image_picker.dart'; // For picking images and videos
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart'; // For picking audio files
import 'package:path/path.dart' as path; // For file path manipulations

// Assuming these are defined in your app_pallete.dart file
import 'package:civiceye/core/theme/app_pallete.dart';
import 'package:civiceye/core/utils/permission_handler.dart'; // Assuming you have this for location permission

// Define the base URL for your backend API
String _baseUrl = ApiConstants.baseUrl;

class ReportCrimePage extends StatefulWidget {
  final String userId; // The ID of the currently logged-in user

  const ReportCrimePage({super.key, required this.userId});

  @override
  State<ReportCrimePage> createState() => _ReportCrimePageState();
}

class _ReportCrimePageState extends State<ReportCrimePage> {
  final SupabaseClient supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _stateController = TextEditingController();
  final TextEditingController _countryController = TextEditingController();

  String? _selectedCategory;
  bool _isAnonymous = false;
  bool isAPublicPost = true;
  double? _latitude;
  double? _longitude;
  bool _isLocating = false;
  bool _isSubmitting = false;
  String? _locationError;

  final ImagePicker _picker = ImagePicker();
  final List<PickedMedia> _pickedMedia =
      []; // Stores picked files and their validation status

  final List<String> _categories = const [
    'corruption',
    'harassment',
    'theft',
    'violence',
    'discrimination',
    'other',
  ];

  @override
  void initState() {
    super.initState();
    _fetchCurrentLocation();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _countryController.dispose();
    super.dispose();
  }

  Future<void> _fetchCurrentLocation() async {
    setState(() {
      _isLocating = true;
      _locationError = null;
    });

    try {
      bool hasPermission = await requestLocationPermission();
      if (hasPermission) {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        _latitude = position.latitude;
        _longitude = position.longitude;

        List<Placemark> placemarks = await placemarkFromCoordinates(
          _latitude!,
          _longitude!,
        );

        if (placemarks.isNotEmpty) {
          Placemark place = placemarks[0];
          _cityController.text = place.locality ?? '';
          _stateController.text = place.administrativeArea ?? '';
          _countryController.text = place.country ?? '';
        }
      } else {
        _locationError =
            'Location permission denied. Please enable it in settings to auto-fill location.';
      }
    } catch (e) {
      _locationError = 'Failed to get location: ${e.toString()}';
    } finally {
      setState(() {
        _isLocating = false;
      });
    }
  }

  Future<void> _pickMedia(ImageSource source, {bool isVideo = false}) async {
    XFile? file;
    if (isVideo) {
      file = await _picker.pickVideo(source: source);
    } else {
      file = await _picker.pickImage(source: source);
    }

    if (file != null) {
      PickedMedia newMedia = PickedMedia(
        file: File(file.path),
        type: isVideo ? MediaType.video : MediaType.image,
      );
      setState(() {
        _pickedMedia.add(newMedia);
      });
      _validateMedia(newMedia);
    }
  }

  Future<void> _pickAudio() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: false,
    );

    if (result != null && result.files.single.path != null) {
      PickedMedia newMedia = PickedMedia(
        file: File(result.files.single.path!),
        type: MediaType.audio,
      );
      setState(() {
        _pickedMedia.add(newMedia);
      });
      _validateMedia(newMedia);
    }
  }

  // --- Media Validation Logic ---
  Future<void> _validateMedia(PickedMedia media) async {
    setState(() {
      media.validationStatus = MediaValidationStatus.validating;
    });

    String endpoint;
    switch (media.type) {
      case MediaType.image:
        endpoint = '/validate/image';
        break;
      case MediaType.video:
        endpoint = '/validate/video';
        break;
      case MediaType.audio:
        endpoint = '/validate/audio';
        break;
    }

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl$endpoint'),
      );
      request.files.add(
        await http.MultipartFile.fromPath('file', media.file.path),
      );

      var response = await request.send();
      var responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final data = json.decode(responseBody);
        setState(() {
          media.tampered = data['tampered'] as bool;
          media.validationStatus = MediaValidationStatus.validated;
        });
      } else {
        setState(() {
          media.tampered = true; // Assume tampered or validation failed
          media.validationStatus = MediaValidationStatus.failed;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Media validation failed for ${media.type}: ${responseBody}',
              ),
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        media.tampered = true; // Assume tampered on error
        media.validationStatus = MediaValidationStatus.failed;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error validating media: ${e.toString()}')),
        );
      }
    }
  }

  // Add this function to your ReportCrimeState class to handle media upload to Supabase
  Future<String> _uploadMediaToSupabase(File file, MediaType type) async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${path.basename(file.path)}';
      final bytes = await file.readAsBytes();
      final bucket = 'evidence';
      final folder =
          type == MediaType.image
              ? 'images'
              : type == MediaType.video
              ? 'videos'
              : 'audio';

      // Include user ID in the path for RLS
      final filePath = '${user.id}/$folder/$fileName';

      final String uploadedPath = await supabase.storage
          .from(bucket)
          .uploadBinary(
            filePath,
            bytes,
            fileOptions: FileOptions(
              cacheControl: '3600',
              upsert: true,
              contentType:
                  type == MediaType.image
                      ? 'image/jpeg'
                      : type == MediaType.video
                      ? 'video/mp4'
                      : 'audio/mp4',
            ),
          );

      final String publicUrl = supabase.storage
          .from(bucket)
          .getPublicUrl(filePath);
      return publicUrl;
    } catch (e) {
      print('❌ Evidence upload error: $e');
      throw e;
    }
  }

  // Add function to insert evidence records
  Future<void> _insertEvidenceRecords(
    String reportId, // Changed from int to String
    List<String> mediaUrls,
    List<MediaType> mediaTypes,
  ) async {
    try {
      final evidenceRecords = <Map<String, dynamic>>[];

      for (int i = 0; i < mediaUrls.length; i++) {
        evidenceRecords.add({
          'evidence_id':const Uuid().v4(),
          'uploaded_by': _isAnonymous ? null : widget.userId,
          'report_id': reportId,
          'file_url': mediaUrls[i],
          'file_type':
              mediaTypes[i] == MediaType.image
                  ? 'image'
                  : mediaTypes[i] == MediaType.video
                  ? 'video'
                  : 'audio',
          'uploaded_at': DateTime.now().toIso8601String(),
        });
      }

      // Insert all evidence records
      await supabase.from('evidence').insert(evidenceRecords);
      print('✅ Evidence records inserted successfully');
    } catch (e) {
      print('❌ Error inserting evidence records: $e');
      throw e;
    }
  }

  // Modify _submitReport to include media upload and evidence table updates
  Future<void> _submitReport() async {
    if (_formKey.currentState!.validate()) {
      // Check authentication first
      final user = supabase.auth.currentUser;
      if (user == null && !_isAnonymous) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in to submit a report.')),
        );
        return;
      }

      // Check if all media items are validated and none are failed
      if (_pickedMedia.any(
        (m) => m.validationStatus == MediaValidationStatus.validating,
      )) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please wait for all media to be validated.'),
          ),
        );
        return;
      }

      if (_pickedMedia.any((m) => m.tampered == true)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Cannot submit report with tampered media. Please remove or replace.',
            ),
          ),
        );
        return;
      }

      setState(() {
        _isSubmitting = true;
      });

      try {
        final mediaUrls = <String>[];
        final mediaTypes = <MediaType>[];

        // Upload each media file to Supabase storage and collect URLs
        for (final media in _pickedMedia) {
          final url = await _uploadMediaToSupabase(media.file, media.type);
          mediaUrls.add(url);
          mediaTypes.add(media.type);
        }

        // Insert the report first to get the report ID
        final reportData = {
          'id': const Uuid().v4(), // Generate a UUID for the id field
          'userid': _isAnonymous ? null : widget.userId,
          'title': _titleController.text,
          'description': _descriptionController.text,
          'latitude': _latitude,
          'longitude': _longitude,
          'city': _cityController.text,
          'state': _stateController.text,
          'country': _countryController.text,
          'category': _selectedCategory,
          'isapublicpost': isAPublicPost,
          'reporter_id': _isAnonymous ? null : widget.userId,
          'status': 'submitted',
          'submitted_at': DateTime.now().toIso8601String(),
        };

        final List<dynamic> reportResponse = await supabase
            .from('reports')
            .insert(reportData)
            .select('id');

        if (reportResponse.isEmpty) {
          throw Exception('Failed to create report');
        }

        final String reportId = reportResponse.first['id']; // Changed from int to String
        print('✅ Report created with ID: $reportId');

        // Insert evidence records if there are media files
        if (mediaUrls.isNotEmpty) {
          await _insertEvidenceRecords(reportId, mediaUrls, mediaTypes);
        }

        // Submit to blockchain API with the media URLs
        var request = http.MultipartRequest(
          'POST',
          Uri.parse('$_baseUrl/blockchain/report'),
        );

        request.fields['text'] =
            '${_titleController.text} - ${_descriptionController.text}';
        request.fields['media_links'] = jsonEncode(
          mediaUrls,
        ); // Send media URLs as JSON string
        request.fields['user_id'] = _isAnonymous ? 'anonymous' : widget.userId;
        request.fields['report_id'] =
            reportId; // No need for toString() since it's already a String

        final streamedResponse = await request.send();
        final response = await http.Response.fromStream(streamedResponse);

        if (response.statusCode == 200) {
          final blockchainResponse = jsonDecode(response.body);
          print('✅ Blockchain response: $blockchainResponse');

          // Optionally update the report with blockchain transaction hash
          if (blockchainResponse['transaction_hash'] != null) {
            await supabase
                .from('reports')
                .update({
                  'blockchain_hash': blockchainResponse['transaction_hash'],
                })
                .eq('id', reportId);
          }

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Report submitted successfully!'),
              backgroundColor: Colors.green,
            ),
          );

          Navigator.pop(context);
        } else {
          throw Exception('Blockchain submission failed: ${response.body}');
        }
      } catch (e) {
        print('❌ Report submission error: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error submitting report: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text(
          'Report a Crime',
          style: TextStyle(color: primaryFgColor, fontWeight: FontWeight.bold),
        ),
        backgroundColor: primaryColor, // Base color for app bar
        flexibleSpace: Container(
          // Apply gradient here
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [const Color.fromARGB(255, 6, 53, 182), primaryColor],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        iconTheme: const IconThemeData(
          color: primaryFgColor,
        ), // For back button
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title Field
              _buildAwesomeTextField(
                controller: _titleController,
                labelText: 'Crime Title',
                hintText: 'e.g., Roadside Robbery',
                icon: Icons.bookmark_added_rounded,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a title for the crime.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Description Field
              _buildAwesomeTextField(
                controller: _descriptionController,
                labelText: 'Description',
                hintText: 'Provide details of the incident...',
                icon: Icons.description_rounded,
                maxLines: 5,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a description.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Category Dropdown
              _buildAwesomeDropdownField(
                labelText: 'Category',
                value: _selectedCategory,
                items:
                    _categories.map((category) {
                      return DropdownMenuItem<String>(
                        value: category,
                        child: Text(
                          category.replaceFirst(
                            category[0],
                            category[0].toUpperCase(),
                          ),
                          style: const TextStyle(color: textColor),
                        ),
                      );
                    }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedCategory = value;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select a category.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Location Section
              Text(
                'Location Details',
                style: TextStyle(
                  color: textColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),

              if (_isLocating)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 10.0),
                    child: CircularProgressIndicator(color: secondaryColor),
                  ),
                )
              else if (_locationError != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10.0),
                  child: Text(
                    _locationError!,
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 13,
                    ),
                  ),
                ),

              _buildAwesomeTextField(
                controller: _cityController,
                labelText: 'City',
                icon: Icons.location_city_rounded,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter the city.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              _buildAwesomeTextField(
                controller: _stateController,
                labelText: 'State/Province',
                icon: Icons.map_rounded,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter the state/province.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              _buildAwesomeTextField(
                controller: _countryController,
                labelText: 'Country',
                icon: Icons.public_rounded,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter the country.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 30),

              // Add Evidence Section
              Text(
                'Add Evidence',
                style: TextStyle(
                  color: textColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              _buildEvidenceSection(),
              const SizedBox(height: 30),

              // Anonymous Toggle
              _buildAnonymousToggle(),
              const SizedBox(height: 30),

              // Submit Button
              _buildSubmitButton(),
            ],
          ),
        ),
      ),
    );
  }

  // --- Helper Widgets for Stunning UI ---

  Widget _buildAwesomeTextField({
    required TextEditingController controller,
    required String labelText,
    String? hintText,
    IconData? icon,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: primaryColor.withOpacity(
          0.1,
        ), // Slightly transparent primary color
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: secondaryColor.withOpacity(0.3),
          width: 1,
        ), // Subtle border
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2), // Darker shadow for depth
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        style: const TextStyle(color: textColor, fontSize: 16),
        decoration: InputDecoration(
          labelText: labelText,
          hintText: hintText,
          hintStyle: TextStyle(
            color: textColor.withOpacity(0.6),
          ), // Lighter hint text
          labelStyle: const TextStyle(
            color: secondaryColor,
          ), // Accent color for label
          prefixIcon:
              icon != null
                  ? Icon(icon, color: accentColor)
                  : null, // Accent color for icon
          border: InputBorder.none, // Remove default border
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          floatingLabelBehavior: FloatingLabelBehavior.always,
        ),
        validator: validator,
      ),
    );
  }

  Widget _buildAwesomeDropdownField({
    required String labelText,
    required String? value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: secondaryColor.withOpacity(0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: DropdownButtonFormField<String>(
        value: value,
        items: items,
        onChanged: onChanged,
        validator: validator,
        dropdownColor: backgroundColor, // Background for dropdown options
        style: const TextStyle(
          color: textColor,
          fontSize: 16,
        ), // Style for the selected value displayed in the field
        icon: const Icon(Icons.arrow_drop_down, color: accentColor),
        decoration: InputDecoration(
          labelText: labelText,
          labelStyle: const TextStyle(color: secondaryColor),
          border: InputBorder.none,
          isDense: true, // Reduce vertical space
          contentPadding: EdgeInsets.zero, // Remove internal padding
        ),
        selectedItemBuilder: (BuildContext context) {
          return items.map<Widget>((item) {
            return Align(
              alignment: Alignment.centerLeft,
              child: Text(
                item.value!.replaceFirst(
                  item.value![0],
                  item.value![0].toUpperCase(),
                ),
                style: const TextStyle(
                  color: textColor,
                ), // Use textColor for dropdown items
              ),
            );
          }).toList();
        },
      ),
    );
  }

  Widget _buildAnonymousToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: secondaryColor.withOpacity(0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Report Anonymously',
                style: TextStyle(
                  color: textColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Switch(
                value: _isAnonymous,
                onChanged: (bool value) {
                  setState(() {
                    _isAnonymous = value;
                  });
                },
                activeColor: secondaryColor,
                inactiveTrackColor: accentColor.withOpacity(0.3),
                inactiveThumbColor: accentColor,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Make Public Post',
                style: TextStyle(
                  color: textColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Switch(
                value: isAPublicPost,
                onChanged: (bool value) {
                  setState(() {
                    isAPublicPost = value;
                  });
                },
                activeColor: secondaryColor,
                inactiveTrackColor: accentColor.withOpacity(0.3),
                inactiveThumbColor: accentColor,
              ),
            ],
          ),
          if (isAPublicPost)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                'Your report will be visible to other users in public feeds.',
                style: TextStyle(
                  color: textColor.withOpacity(0.7),
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          if (!isAPublicPost)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                'Your report will only be visible to authorities and administrators.',
                style: TextStyle(
                  color: textColor.withOpacity(0.7),
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEvidenceSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: primaryColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: secondaryColor.withOpacity(0.2), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Upload Media Evidence',
            style: TextStyle(
              color: textColor,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMediaUploadButton(
                icon: Icons.image,
                label: 'Image',
                onTap: () => _showImageSourceDialog(),
              ),
              _buildMediaUploadButton(
                icon: Icons.videocam,
                label: 'Video',
                onTap: () => _showVideoSourceDialog(),
              ),
              _buildMediaUploadButton(
                icon: Icons.mic,
                label: 'Audio',
                onTap: _pickAudio,
              ),
            ],
          ),
          if (_pickedMedia.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              'Uploaded Files:',
              style: TextStyle(
                color: textColor,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 10),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _pickedMedia.length,
              itemBuilder: (context, index) {
                final media = _pickedMedia[index];
                return _buildMediaPreviewCard(media, index);
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMediaUploadButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(50),
          child: Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [secondaryColor, accentColor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: secondaryColor.withOpacity(0.4),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 30),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: textColor, fontSize: 13)),
      ],
    );
  }

  Widget _buildMediaPreviewCard(PickedMedia media, int index) {
    IconData statusIcon;
    Color statusColor;
    String statusText;

    switch (media.validationStatus) {
      case MediaValidationStatus.none:
        statusIcon = Icons.hourglass_empty;
        statusColor = Colors.grey;
        statusText = 'Pending validation...';
        break;
      case MediaValidationStatus.validating:
        statusIcon = Icons.hourglass_top;
        statusColor = Colors.orange;
        statusText = 'Validating...';
        break;
      case MediaValidationStatus.validated:
        if (media.tampered == true) {
          statusIcon = Icons.error_outline;
          statusColor = Colors.redAccent;
          statusText = 'Tampered!';
        } else {
          statusIcon = Icons.check_circle_outline;
          statusColor = Colors.greenAccent;
          statusText = 'Authentic';
        }
        break;
      case MediaValidationStatus.failed:
        statusIcon = Icons.cancel_outlined;
        statusColor = Colors.red;
        statusText = 'Validation failed';
        break;
    }

    return Card(
      color: primaryColor.withOpacity(0.15),
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Icon(_getMediaTypeIcon(media.type), color: accentColor),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    media.file.path.split('/').last, // Display filename
                    style: const TextStyle(color: textColor, fontSize: 15),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Icon(statusIcon, color: statusColor, size: 18),
                      const SizedBox(width: 5),
                      Text(
                        statusText,
                        style: TextStyle(color: statusColor, fontSize: 13),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.redAccent),
              onPressed: () {
                setState(() {
                  _pickedMedia.removeAt(index);
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  IconData _getMediaTypeIcon(MediaType type) {
    switch (type) {
      case MediaType.image:
        return Icons.image_rounded;
      case MediaType.video:
        return Icons.video_file_rounded;
      case MediaType.audio:
        return Icons.audio_file_rounded;
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent, // Make background transparent
      builder: (BuildContext context) {
        return ClipRRect(
          // Use ClipRRect with BackdropFilter for a stunning effect
          borderRadius: const BorderRadius.vertical(top: Radius.circular(25.0)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0), // Apply blur
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.3), // Semi-transparent color
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(25.0),
                ),
                border: Border(
                  top: BorderSide(
                    color: secondaryColor.withOpacity(0.5),
                    width: 1,
                  ),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    'Select Image Source',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ListTile(
                    leading: Icon(Icons.camera_alt, color: accentColor),
                    title: Text(
                      'Camera',
                      style: TextStyle(color: textColor, fontSize: 18),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _pickMedia(ImageSource.camera);
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.photo_library, color: accentColor),
                    title: Text(
                      'Gallery',
                      style: TextStyle(color: textColor, fontSize: 18),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _pickMedia(ImageSource.gallery);
                    },
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showVideoSourceDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(25.0)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.3),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(25.0),
                ),
                border: Border(
                  top: BorderSide(
                    color: secondaryColor.withOpacity(0.5),
                    width: 1,
                  ),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    'Select Video Source',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ListTile(
                    leading: Icon(Icons.camera_alt, color: accentColor),
                    title: Text(
                      'Camera',
                      style: TextStyle(color: textColor, fontSize: 18),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _pickMedia(ImageSource.camera, isVideo: true);
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.video_library, color: accentColor),
                    title: Text(
                      'Gallery',
                      style: TextStyle(color: textColor, fontSize: 18),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _pickMedia(ImageSource.gallery, isVideo: true);
                    },
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSubmitButton() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          colors:
              _isSubmitting
                  ? [
                    primaryColor.withOpacity(0.5),
                    secondaryColor.withOpacity(0.5),
                  ]
                  : [primaryColor, secondaryColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: secondaryColor.withOpacity(0.4),
            blurRadius: 10,
            spreadRadius: 2,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _submitReport,
        style: ElevatedButton.styleFrom(
          backgroundColor:
              Colors
                  .transparent, // Make button transparent to show container's gradient
          shadowColor: Colors.transparent, // Remove button's default shadow
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0, // No elevation on the button itself
        ),
        child:
            _isSubmitting
                ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
                : const Text(
                  'Submit Report',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: primaryFgColor,
                  ),
                ),
      ),
    );
  }
}

// Enum for media types
enum MediaType { image, video, audio }

// Enum for media validation status
enum MediaValidationStatus { none, validating, validated, failed }

// Model to hold picked media file and its validation status
class PickedMedia {
  final File file;
  final MediaType type;
  MediaValidationStatus validationStatus;
  bool? tampered; // null if not validated, true if tampered, false if authentic

  PickedMedia({
    required this.file,
    required this.type,
    this.validationStatus = MediaValidationStatus.none,
    this.tampered,
  });
}
