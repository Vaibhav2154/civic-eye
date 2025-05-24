import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import '../../core/theme/app_pallete.dart';

class SteatlhFileScreens extends StatefulWidget {
  const SteatlhFileScreens({super.key});

  @override
  State<SteatlhFileScreens> createState() => _SteatlhFileScreensState();
}

class _SteatlhFileScreensState extends State<SteatlhFileScreens> {
  final SupabaseClient supabase = Supabase.instance.client;
  bool isLoading = true;
  List<Map<String, dynamic>> stealthFiles = [];
  List<Map<String, dynamic>> filteredFiles = [];
  Map<String, ChewieController?> videoControllers = {};
  Map<String, String> videoInitializationErrors = {};
  
  // Date filtering
  DateTime? selectedStartDate;
  DateTime? selectedEndDate;
  String currentFilter = 'All';

  @override
  void initState() {
    super.initState();
    loadStealthFiles();
  }

  @override
  void dispose() {
    // Release resources when app is in background
    for (var controller in videoControllers.values) {
      if (controller != null) {
        controller.dispose();
      }
    }
    super.dispose();
  }

  Future<void> loadStealthFiles() async {
    try {
      setState(() {
        isLoading = true;
      });

      final user = supabase.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final response = await supabase
          .from('stealth')
          .select('*')
          .eq('userid', user.id)
          .order('created_at', ascending: false);
      log(response.toString());

      if (mounted) {
        setState(() {
          stealthFiles = List<Map<String, dynamic>>.from(response);
          filteredFiles = List<Map<String, dynamic>>.from(response);
          isLoading = false;
        });

        // Pre-initialize video controllers with delay to avoid overwhelming the system
        _initializeVideoControllersWithDelay();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading stealth files: $e')),
        );
      }
    }
  }

  // Apply filters based on selected dates
  void applyFilters() {
    setState(() {
      if (selectedStartDate == null && selectedEndDate == null) {
        // No date filter applied
        filteredFiles = List<Map<String, dynamic>>.from(stealthFiles);
        currentFilter = 'All';
      } else {
        filteredFiles = stealthFiles.where((file) {
          final fileDate = DateTime.parse(file['created_at']);
          
          bool passesStartDate = selectedStartDate == null || 
              fileDate.isAfter(selectedStartDate!) || 
              isSameDay(fileDate, selectedStartDate!);
              
          bool passesEndDate = selectedEndDate == null || 
              fileDate.isBefore(selectedEndDate!.add(const Duration(days: 1))) || 
              isSameDay(fileDate, selectedEndDate!);
              
          return passesStartDate && passesEndDate;
        }).toList();
        
        if (selectedStartDate != null && selectedEndDate != null) {
          currentFilter = '${_formatDateForFilter(selectedStartDate!)} - ${_formatDateForFilter(selectedEndDate!)}';
        } else if (selectedStartDate != null) {
          currentFilter = 'From ${_formatDateForFilter(selectedStartDate!)}';
        } else {
          currentFilter = 'Until ${_formatDateForFilter(selectedEndDate!)}';
        }
      }
    });
  }
  
  String _formatDateForFilter(DateTime date) {
    return "${date.day}/${date.month}/${date.year}";
  }
  
  bool isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year && 
           date1.month == date2.month && 
           date1.day == date2.day;
  }

  // Reset filters
  void resetFilters() {
    setState(() {
      selectedStartDate = null;
      selectedEndDate = null;
      filteredFiles = List<Map<String, dynamic>>.from(stealthFiles);
      currentFilter = 'All';
    });
  }

  // Show date picker
  Future<void> _selectDate(bool isStartDate) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: isStartDate ? selectedStartDate ?? DateTime.now() : selectedEndDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: primaryColor,
              onPrimary: textColor,
              surface: backgroundColor,
              onSurface: textColor,
            ),
            dialogBackgroundColor: backgroundColor,
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null) {
      setState(() {
        if (isStartDate) {
          selectedStartDate = pickedDate;
          // If end date is before start date, update end date
          if (selectedEndDate != null && selectedEndDate!.isBefore(selectedStartDate!)) {
            selectedEndDate = selectedStartDate;
          }
        } else {
          selectedEndDate = pickedDate;
          // If start date is after end date, update start date
          if (selectedStartDate != null && selectedStartDate!.isAfter(selectedEndDate!)) {
            selectedStartDate = selectedEndDate;
          }
        }
        applyFilters();
      });
    }
  }

  Future<void> _initializeVideoControllersWithDelay() async {
    for (int i = 0; i < stealthFiles.length; i++) {
      final file = stealthFiles[i];
      final videoUrl = file['evidence_url'];

      // Add delay between initializations to prevent overwhelming the system
      if (i > 0) {
        await Future.delayed(const Duration(milliseconds: 500));
      }

      await _initializeVideoController(videoUrl);
    }
  }

  String _processVideoUrl(String originalUrl) {
    // Handle .temp files by adding proper headers and potentially modifying the URL
    final uri = Uri.parse(originalUrl);

    // If it's a .temp file, we might need to add parameters or modify the URL
    if (originalUrl.endsWith('.temp')) {
      // Option 1: Try to access it as an MP4 by removing .temp extension
      // (This depends on how your backend stores the files)
      // return originalUrl.replaceAll('.temp', '.mp4');

      // Option 2: Keep original URL but handle with special headers
      return originalUrl;
    }

    return originalUrl;
  }

  Future<void> _initializeVideoController(String videoUrl) async {
    // Skip if already initialized or failed
    if (videoControllers.containsKey(videoUrl)) {
      return;
    }

    try {
      // Check if the URL seems valid
      if (videoUrl.isEmpty || !Uri.parse(videoUrl).isAbsolute) {
        log('Invalid video URL: $videoUrl');
        setState(() {
          videoInitializationErrors[videoUrl] = 'Invalid video URL';
          videoControllers[videoUrl] = null;
        });
        return;
      }

      final processedUrl = _processVideoUrl(videoUrl);
      final Uri videoUri = Uri.parse(processedUrl);

      log('Initializing video: $processedUrl');

      // Create video player controller with appropriate headers
      VideoPlayerController videoPlayerController;

      if (processedUrl.endsWith('.temp')) {
        // For .temp files, try with specific headers
        videoPlayerController = VideoPlayerController.networkUrl(
          videoUri,
          httpHeaders: {
            'Accept': '*/*',
            'User-Agent': 'Flutter Video Player',
            'Range': 'bytes=0-', // Support for range requests
          },
        );
      } else {
        // For regular files
        videoPlayerController = VideoPlayerController.networkUrl(videoUri);
      }

      // Use a timeout to avoid hanging if initialization fails
      await videoPlayerController.initialize().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException(
            'Video initialization timed out after 10 seconds',
          );
        },
      );

      // Check if the video was successfully initialized
      if (!videoPlayerController.value.isInitialized) {
        throw Exception('Video controller failed to initialize');
      }

      final chewieController = ChewieController(
        videoPlayerController: videoPlayerController,
        autoPlay: false,
        looping: false,
        aspectRatio:
            videoPlayerController.value.aspectRatio > 0
                ? videoPlayerController.value.aspectRatio
                : 16 / 9, // Default aspect ratio
        allowMuting: true,
        allowPlaybackSpeedChanging: true,
        showControls: true,
        materialProgressColors: ChewieProgressColors(
          playedColor: primaryColor,
          handleColor: primaryColor,
          backgroundColor: Colors.grey.shade700,
          bufferedColor: Colors.grey.shade400,
        ),
        placeholder: Container(
          color: Colors.black,
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: primaryColor),
                SizedBox(height: 8),
                Text('Loading video...', style: TextStyle(color: Colors.white)),
              ],
            ),
          ),
        ),
        errorBuilder: (context, errorMessage) {
          return Container(
            color: Colors.black,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 40),
                  const SizedBox(height: 12),
                  const Text(
                    'Could not play video',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    errorMessage,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => _retryVideoInitialization(videoUrl),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        },
      );

      if (mounted) {
        setState(() {
          videoControllers[videoUrl] = chewieController;
          videoInitializationErrors.remove(videoUrl);
        });
        log('Successfully initialized video: $videoUrl');
      }
    } catch (e) {
      log('Error initializing video: $e');
      String errorMessage = e.toString();

      // Handle specific error types
      if (e is TimeoutException) {
        errorMessage = 'Video loading timed out. Please check your connection.';
      } else if (e.toString().contains('PlatformException')) {
        errorMessage = 'Platform error. Try restarting the app.';
      } else if (e.toString().contains('404')) {
        errorMessage = 'Video file not found.';
      } else if (e.toString().contains('403')) {
        errorMessage = 'Access denied to video file.';
      }

      if (mounted) {
        setState(() {
          videoControllers[videoUrl] = null;
          videoInitializationErrors[videoUrl] = errorMessage;
        });
      }
    }
  }

  Future<void> _retryVideoInitialization(String videoUrl) async {
    setState(() {
      videoControllers.remove(videoUrl);
      videoInitializationErrors.remove(videoUrl);
    });

    await _initializeVideoController(videoUrl);
  }

  Widget _buildVideoPlayer(String videoUrl) {
    if (videoControllers.containsKey(videoUrl)) {
      final controller = videoControllers[videoUrl];
      if (controller != null) {
        return Chewie(controller: controller);
      } else {
        // Video failed to initialize
        final errorMessage =
            videoInitializationErrors[videoUrl] ?? 'Failed to load video';
        return Container(
          color: Colors.black,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, color: Colors.red, size: 40),
                const SizedBox(height: 12),
                const Text(
                  'Video Unavailable',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    errorMessage,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => _retryVideoInitialization(videoUrl),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Try Again'),
                ),
              ],
            ),
          ),
        );
      }
    } else {
      // Still loading
      return Container(
        color: Colors.black,
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: primaryColor),
              SizedBox(height: 12),
              Text('Preparing video...', style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
      );
    }
  }

  // Build the filter UI
  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: primaryColor.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Date Filter: $currentFilter',
                style: const TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (currentFilter != 'All')
                IconButton(
                  icon: const Icon(Icons.clear, color: textColor, size: 18),
                  onPressed: resetFilters,
                  tooltip: 'Clear filters',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.date_range, size: 16),
                  label: Text(selectedStartDate != null 
                      ? _formatDateForFilter(selectedStartDate!) 
                      : 'Start Date'),
                  onPressed: () => _selectDate(true),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: textColor,
                    side: BorderSide(color: primaryColor.withOpacity(0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.date_range, size: 16),
                  label: Text(selectedEndDate != null 
                      ? _formatDateForFilter(selectedEndDate!) 
                      : 'End Date'),
                  onPressed: () => _selectDate(false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: textColor,
                    side: BorderSide(color: primaryColor.withOpacity(0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text(
          'Stealth Recordings',
          style: TextStyle(color: textColor),
        ),
        backgroundColor: backgroundColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: textColor),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              // Clear all controllers and reload
              for (var controller in videoControllers.values) {
                controller?.dispose();
              }
              setState(() {
                videoControllers.clear();
                videoInitializationErrors.clear();
                selectedStartDate = null;
                selectedEndDate = null;
                currentFilter = 'All';
              });
              loadStealthFiles();
            },
          ),
        ],
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: primaryColor),
            )
          : stealthFiles.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.videocam_off,
                        size: 64,
                        color: textColor.withOpacity(0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No stealth recordings found',
                        style: TextStyle(
                          fontSize: 18,
                          color: textColor.withOpacity(0.7),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Recordings from stealth mode will appear here',
                        style: TextStyle(
                          fontSize: 14,
                          color: textColor.withOpacity(0.5),
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  color: primaryColor,
                  onRefresh: loadStealthFiles,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: _buildFilterBar(),
                      ),
                      Expanded(
                        child: filteredFiles.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.search_off,
                                      size: 64,
                                      color: textColor.withOpacity(0.5),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No recordings found for this date range',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: textColor.withOpacity(0.7),
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 16),
                                    ElevatedButton(
                                      onPressed: resetFilters,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: primaryColor,
                                        foregroundColor: Colors.white,
                                      ),
                                      child: const Text('Show All Recordings'),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                itemCount: filteredFiles.length,
                                itemBuilder: (context, index) {
                                  final file = filteredFiles[index];
                                  final videoUrl = file['evidence_url'];
                                  final createdAt = DateTime.parse(file['created_at']);
                                  final formattedDate =
                                      "${createdAt.day}/${createdAt.month}/${createdAt.year}";
                                  final formattedTime =
                                      "${createdAt.hour}:${createdAt.minute.toString().padLeft(2, '0')}";

                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 16),
                                    color: secondaryColor,
                                    elevation: 3,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: BorderSide(
                                        color: primaryColor.withOpacity(0.3),
                                        width: 1,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        ClipRRect(
                                          borderRadius: const BorderRadius.vertical(
                                            top: Radius.circular(12),
                                          ),
                                          child: AspectRatio(
                                            aspectRatio: 16 / 9,
                                            child: _buildVideoPlayer(videoUrl),
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Row(
                                                    children: [
                                                      const Icon(
                                                        Icons.calendar_today,
                                                        size: 16,
                                                        color: textColor,
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Text(
                                                        formattedDate,
                                                        style: const TextStyle(
                                                          color: textColor,
                                                          fontSize: 14,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  Row(
                                                    children: [
                                                      const Icon(
                                                        Icons.access_time,
                                                        size: 16,
                                                        color: textColor,
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Text(
                                                        formattedTime,
                                                        style: const TextStyle(
                                                          color: textColor,
                                                          fontSize: 14,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 12),
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Text(
                                                    'Stealth Recording',
                                                    style: TextStyle(
                                                      color: textColor.withOpacity(0.9),
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 6,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: primaryColor.withOpacity(0.2),
                                                      borderRadius: BorderRadius.circular(16),
                                                      border: Border.all(
                                                        color: primaryColor.withOpacity(0.3),
                                                      ),
                                                    ),
                                                    child: const Text(
                                                      'Stealth',
                                                      style: TextStyle(
                                                        color: primaryColor,
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
    );
  }
}
