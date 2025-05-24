import 'dart:convert';
import 'dart:developer';

import 'package:civiceye/core/theme/app_pallete.dart';
import 'package:civiceye/core/utils/permission_handler.dart';
import 'package:civiceye/features/auth/pages/loginpage.dart';
import 'package:civiceye/features/auth/services/auth_service.dart';
import 'package:civiceye/features/chatbot/chatbot.dart';
import 'package:civiceye/features/community/pages/community.dart';
import 'package:civiceye/features/dashboard/decoyCalculator.dart';
import 'package:civiceye/features/legal_contacts/legal_contacts_page.dart';
import 'package:civiceye/features/report_crime/report_crime.dart';
import 'package:civiceye/features/stealth/steatlh_file_screens.dart';
import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class Dashboardpage extends StatefulWidget {
  const Dashboardpage({super.key});

  @override
  State<Dashboardpage> createState() => _DashboardpageState();
}

class _DashboardpageState extends State<Dashboardpage> {
  final authservice = AuthService();
  final SupabaseClient supabase = Supabase.instance.client;
  String crimeAlert = 'Fetching your location...';
  String nearestHospital = 'Searching...';
  String nearestFireStation = 'Searching...';
  String nearestPoliceStation = 'Searching...';

  String currentName = 'User';

  double? latitude;
  double? longitude;
  int _selectedIndex = 0;

  // Camera controller for stealth mode
  late CameraController _controller;
  bool _isRecording = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
    getCurrentUserFullName();
  }

  @override
  void dispose() {
    if (_isRecording && _controller.value.isInitialized) {
      _controller.stopVideoRecording();
    }
    super.dispose();
  }

  void logout() async {
    await authservice.signOut();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const Loginpage()),
      );
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    switch (index) {
      case 0: // Home
        break;
      case 1: Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const CommunityPage()),
        ).then((_) {
          // Set _selectedIndex back to Home (index 0) when CommunityPage is popped
          setState(() {
            _selectedIndex = 0;
          });
        });
        break;// Community
      case 2: // Report Crime
        final String? userId = authservice.getCurrentUserId();
        if (userId != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ReportCrimePage(userId: userId),
            ),
          ).then((_) {
            setState(() {
              _selectedIndex = 0;
            });
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please log in to report a crime.')),
          );
        }
        break;
      case 3:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ChatbotPage()),
        );
        break;
    }
  }

  Future<void> _checkPermissions() async {
    bool hasPermission = await requestLocationPermission();
    if (hasPermission) {
      try {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        latitude = position.latitude;
        longitude = position.longitude;

        setState(() {
          crimeAlert =
              'Your location: ${latitude!.toStringAsFixed(4)}, ${longitude!.toStringAsFixed(4)}';
        });

        try {
          List<Placemark> placemarks = await placemarkFromCoordinates(
            latitude!,
            longitude!,
          );
          if (placemarks.isNotEmpty) {
            Placemark place = placemarks[0];
            setState(() {
              crimeAlert =
                  'You are near ${place.name}, ${place.subLocality}, ${place.locality}, ${place.administrativeArea}';
            });
          }
        } catch (geocodingError) {
          log('Geocoding error: $geocodingError');
        }

        _getNearbyPlace("hospital");
        _getNearbyPlace("fire_station");
        _getNearbyPlace("police");
      } catch (e) {
        setState(() {
          crimeAlert = 'Failed to get location: $e';
          log(e.toString());
        });
      }
    } else {
      setState(() {
        crimeAlert = 'Location permission denied.';
      });
    }
  }

  Future<void> handleStealthMode(BuildContext context) async {
    final statusCamera = await Permission.camera.request();
    final statusMicrophone = await Permission.microphone.request();

    if (!statusCamera.isGranted || !statusMicrophone.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Camera and Microphone permission required")),
      );
      return;
    }

    try {
      final cameras = await availableCameras();
      final backCamera = cameras.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      _controller = CameraController(backCamera, ResolutionPreset.medium);
      await _controller.initialize();
      
      final Directory appDirectory = await getApplicationDocumentsDirectory();
      final String videoDir = '${appDirectory.path}/Videos';
      await Directory(videoDir).create(recursive: true);


      await _controller.startVideoRecording();
      _isRecording = true;

      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => CalculatorScreen()),
      ).then((_) {
        // Stop recording when returning from calculator
        if (_isRecording && _controller.value.isInitialized) {
          _controller.stopVideoRecording().then((_) {
            _isRecording = false;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Recording saved successfully")),
            );
          });
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to start stealth mode: $e")),
      );
    }
  }

  Future<void> _getNearbyPlace(String type) async {
    final amenity = type;
    final overpassUrl =
        'https://overpass-api.de/api/interpreter?data=[out:json];node[amenity=$amenity](${latitude! - 0.05},${longitude! - 0.05},${latitude! + 0.05},${longitude! + 0.05});out;';

    try {
      final response = await http.get(Uri.parse(overpassUrl));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['elements'] != null && data['elements'].isNotEmpty) {
          final element = data['elements'][0];
          final name = element['tags']['name'] ?? 'Unnamed';
          final double lat = element['lat'];
          final double lon = element['lon'];

          double distanceInMeters = Geolocator.distanceBetween(
            latitude!,
            longitude!,
            lat,
            lon,
          );
          double distanceInKm = distanceInMeters / 1000;

          setState(() {
            if (type == "hospital") {
              nearestHospital =
                  '$name (${distanceInKm.toStringAsFixed(2)} km away)';
            } else if (type == "fire_station") {
              nearestFireStation =
                  '$name (${distanceInKm.toStringAsFixed(2)} km away)';
            } else if (type == "police") {
              nearestPoliceStation = 
                  '$name (${distanceInKm.toStringAsFixed(2)} km away)';
            }
          });
        } else {
          setState(() {
            if (type == "hospital") {
              nearestHospital = 'No hospital found nearby.';
            } else if (type == "fire_station") {
              nearestFireStation = 'No fire station found nearby.';
            } else if (type == "police") {
              nearestPoliceStation = 'No police station found nearby.';
            }
          });
        }
      } else {
        print("Failed Overpass request: ${response.body}");
      }
    } catch (e) {
      print("Error in fetching from Overpass API: $e");
    }
  }

  Widget _buildSOSButton(String label, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 90,
        height: 90,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFF5252), Color(0xFFFF1744)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(45),
          boxShadow: [
            BoxShadow(
              color: Colors.red.withOpacity(0.5),
              spreadRadius: 2,
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: Colors.white),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavBarItem(String label, IconData icon, int index) {
    final isSelected = _selectedIndex == index;

    return InkWell(
      onTap: () => _onItemTapped(index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: EdgeInsets.all(isSelected ? 12 : 8),
              decoration: BoxDecoration(
                color: isSelected ? secondaryColor : Colors.transparent,
                shape: BoxShape.circle,
                boxShadow:
                    isSelected
                        ? [
                          BoxShadow(
                            color: secondaryColor.withOpacity(0.4),
                            blurRadius: 12,
                            spreadRadius: 2,
                          ),
                        ]
                        : [],
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.white : Colors.white70,
                size: isSelected ? 15 : 14,
              ),
            ),
            const SizedBox(height: 2),
            isSelected
                ? ShaderMask(
                  shaderCallback: (bounds) {
                    return LinearGradient(
                      colors: [secondaryColor, Colors.white],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    ).createShader(bounds);
                  },
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 10,
                    ),
                  ),
                )
                : Text(
                  label,
                  style: const TextStyle(color: Colors.white70, fontSize: 10),
                ),
          ],
        ),
      ),
    );
  }

  Future<void> getCurrentUserFullName() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final response =
        await supabase
            .from('users')
            .select('full_name')
            .eq('id', user.id)
            .maybeSingle();

    if (response != null) {
      setState(() {
        currentName = response['full_name'] ?? "Unknown";
      });
    }
  }

  Widget _buildEmergencyServiceItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.07),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: 22,
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: Colors.white54,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double bottomNavBarHeight =
        70.0 + MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: backgroundColor,
      resizeToAvoidBottomInset: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [const Color.fromARGB(255, 6, 53, 182), primaryColor],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: const Text(
              "Dashboard",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 22,
                color: Colors.white,
              ),
            ),
            actions: [
              Container(
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: IconButton(
                  icon: const Icon(Icons.video_call, size: 20),
                  onPressed: () => Navigator.push(
                    context, 
                    MaterialPageRoute(builder: (context) => SteatlhFileScreens())
                  ),
                  color: Colors.white,
                ),
              ),
              Container(
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: IconButton(
                  icon: const Icon(Icons.contact_emergency, size: 20),
                  onPressed: () => Navigator.push(
                    context, 
                    MaterialPageRoute(builder: (context) => LegalContactsPage())
                  ),
                  color: Colors.white,
                ),
              ),
              Container(
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: IconButton(
                  icon: const Icon(Icons.logout, size: 20),
                  onPressed: logout,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16.0, 10, 16.0, 10 + bottomNavBarHeight),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 25),

            // SOS Section
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.emergency,
                          color: Colors.red,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        "Emergency SOS",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildSOSButton('Police', Icons.local_police, () async {
                        const phoneNumber = 'tel:100';
                        if (await canLaunchUrl(Uri.parse(phoneNumber))) {
                          await launchUrl(Uri.parse(phoneNumber));
                        }
                      }),
                      _buildSOSButton(
                        'Ambulance',
                        Icons.local_hospital,
                        () async {
                          const phoneNumber = 'tel:102';
                          if (await canLaunchUrl(Uri.parse(phoneNumber))) {
                            await launchUrl(Uri.parse(phoneNumber));
                          }
                        },
                      ),
                      _buildSOSButton(
                        'Fire',
                        Icons.local_fire_department,
                        () async {
                          const phoneNumber = 'tel:101';
                          if (await canLaunchUrl(Uri.parse(phoneNumber))) {
                            await launchUrl(Uri.parse(phoneNumber));
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 25),

            // Stealth Mode Button
            Center(
              child: GestureDetector(
                onTap: () => handleStealthMode(context),
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color.fromARGB(255, 78, 140, 240),
                        primaryColor,
                      ],
                      center: const Alignment(-0.2, -0.2),
                      radius: 0.8,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withOpacity(0.6),
                        blurRadius: 25,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Container(
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 2,
                        ),
                      ),
                      child: const Center(
                        child: Text(
                          "Stealth\nMode",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 24,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 25),

            // Location Info / Crime Alert
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    primaryColor.withOpacity(0.6),
                    const Color.fromARGB(255, 27, 61, 141).withOpacity(0.6),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.location_on,
                          color: Colors.amber,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        "Your Location",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_history,
                        color: Colors.yellowAccent,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          crimeAlert,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Nearest Facilities
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.blue.withOpacity(0.2), 
                    Colors.indigo.withOpacity(0.15)
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withOpacity(0.1),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 15,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.blue.withOpacity(0.3), Colors.lightBlue.withOpacity(0.4)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.withOpacity(0.2),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.local_hospital,
                          color: Colors.lightBlueAccent,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 15),
                      const Text(
                        "Emergency Services",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildEmergencyServiceItem(
                    icon: Icons.local_hospital,
                    iconColor: Colors.redAccent,
                    title: "Hospital",
                    value: nearestHospital,
                    onTap: () async {
                      final mapUrl = 'https://www.google.com/maps/search/hospital/@$latitude,$longitude';
                      if (await canLaunchUrl(Uri.parse(mapUrl))) {
                        await launchUrl(Uri.parse(mapUrl), mode: LaunchMode.externalApplication);
                      }
                    },
                  ),
                  const SizedBox(height: 15),
                  _buildEmergencyServiceItem(
                    icon: Icons.local_fire_department,
                    iconColor: Colors.orangeAccent,
                    title: "Fire Station",
                    value: nearestFireStation,
                    onTap: () async {
                      final mapUrl = 'https://www.google.com/maps/search/fire+station/@$latitude,$longitude';
                      if (await canLaunchUrl(Uri.parse(mapUrl))) {
                        await launchUrl(Uri.parse(mapUrl), mode: LaunchMode.externalApplication);
                      }
                    },
                  ),
                  const SizedBox(height: 15),
                  _buildEmergencyServiceItem(
                    icon: Icons.local_police,
                    iconColor: Colors.blueAccent,
                    title: "Police Station",
                    value: nearestPoliceStation,
                    onTap: () async {
                      final mapUrl = 'https://www.google.com/maps/search/police+station/@$latitude,$longitude';
                      if (await canLaunchUrl(Uri.parse(mapUrl))) {
                        await launchUrl(Uri.parse(mapUrl), mode: LaunchMode.externalApplication);
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),

      // Bottom Navigation Bar
      bottomNavigationBar: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            color: backgroundColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: ClipRRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                height: 70,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.2),
                  border: Border(
                    top: BorderSide(
                      color: secondaryColor.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildNavBarItem('Home', Icons.home_rounded, 0),
                    _buildNavBarItem('Community', Icons.people_alt_rounded, 1),
                    _buildNavBarItem('Report', Icons.report_problem_rounded, 2),
                    _buildNavBarItem('Chat', Icons.chat_bubble_rounded, 3),
                  ],
                ),
              ),
            ),
          ),
        ),  
      ),
    );
  }
}