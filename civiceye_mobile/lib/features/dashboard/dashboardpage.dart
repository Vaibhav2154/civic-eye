import 'dart:convert';
import 'dart:developer';

import 'package:civiceye/core/theme/app_pallete.dart';
import 'package:civiceye/core/utils/permission_handler.dart';
import 'package:civiceye/features/auth/pages/loginpage.dart';
import 'package:civiceye/features/auth/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'dart:ui';
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
  String currentName = 'User';

  double? latitude;
  double? longitude;
  // Initialize _selectedIndex to 0 for Home
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
    getCurrentUserFullName();
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

  // Method to handle navigation item taps
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    switch (index) {
      case 0: // Home
        
        break;
      case 1: // Community
    
        break;
      case 2: // Report Crime
      
        break;
      case 3: // Chat
        
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
            } else {
              nearestFireStation =
                  '$name (${distanceInKm.toStringAsFixed(2)} km away)';
            }
          });
        } else {
          setState(() {
            if (type == "hospital") {
              nearestHospital = 'No hospital found nearby.';
            } else {
              nearestFireStation = 'No fire station found nearby.';
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
      child: CircleAvatar(
        radius: 40,
        backgroundColor: Colors.red,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 30, color: Colors.white),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  // Custom bottom navbar item widget
  Widget _buildNavBarItem(String label, IconData icon, int index) {
    final isSelected = _selectedIndex == index;

    return InkWell(
      onTap: () => _onItemTapped(index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Animated icon with shadow for selected state
            // AnimatedContainer(
            //   duration: const Duration(milliseconds: 200),
            //   padding: EdgeInsets.all(isSelected ? 12 : 8),
            //   decoration: BoxDecoration(
            //     color: isSelected ? primaryColor : backgroundColor,
            //     shape: BoxShape.circle,
            //     boxShadow: isSelected
            //         ? [
            //             BoxShadow(
            //               color: secondaryColor.withOpacity(0.5),
            //               blurRadius: 12,
            //               spreadRadius: 2,
            //             )
            //           ]
            //         : [],
            //   ),
            //   child: Icon(
            //     icon,
            //     color: isSelected ? Colors.white : Colors.white70,
            //     size: isSelected ? 24 : 20,
            //   ),
            // ),
            Icon(
                icon,
                color: isSelected ? secondaryColor : Colors.white70,
                size: isSelected ? 24 : 20,
              ),
            const SizedBox(height: 4),
            // Text label with gradient for selected state
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
                      fontSize: 12,
                    ),
                  ),
                )
                : Text(
                  label,
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
          ],
        ),
      ),
    );
  }
Future<void> getCurrentUserFullName() async {
  final user =supabase.auth.currentUser;
  if(user == null) return;

  final response = await supabase
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
              IconButton(
                icon: const Icon(Icons.logout),
                onPressed: logout,
                color: Colors.white,
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
            // Greeting Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    "👋 Welcome back,",
                    style: TextStyle(fontSize: 18, color: textColor),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    currentName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // SOS Section
            const Text(
              "🚨 Emergency SOS",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSOSButton('Police', Icons.local_police, () async {
                  const phoneNumber = 'tel:100';
                  if (await canLaunchUrl(Uri.parse(phoneNumber))) {
                    await launchUrl(Uri.parse(phoneNumber));
                  }
                }),
                _buildSOSButton('Ambulance', Icons.local_hospital, () async {
                  const phoneNumber = 'tel:102';
                  if (await canLaunchUrl(Uri.parse(phoneNumber))) {
                    await launchUrl(Uri.parse(phoneNumber));
                  }
                }),
                _buildSOSButton('Fire', Icons.local_fire_department, () async {
                  const phoneNumber = 'tel:101';
                  if (await canLaunchUrl(Uri.parse(phoneNumber))) {
                    await launchUrl(Uri.parse(phoneNumber));
                  }
                }),
              ],
            ),

            const SizedBox(height: 70),

            // Stealth Mode Button – now moved up and centered
            Center(
              child: GestureDetector(
                onTap: () => {},
                child: Container(
                  width: 170,
                  height: 170,
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
                    boxShadow: const [
                      BoxShadow(blurRadius: 20, spreadRadius: 5),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      "Stealth\nMode",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 50),

            // Nearest Facilities
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "📍 Nearest Emergency Services",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "🏥 Hospital: $nearestHospital",
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "🚒 Fire Station: $nearestFireStation",
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Location Info / Crime Alert
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.deepPurple.shade300, width: 1),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.location_history,
                    color: Colors.yellowAccent,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      crimeAlert,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),

      // Beautiful Custom Bottom Navigation Bar
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
                  // border: Border(
                  //   top: BorderSide(
                  //     color: secondaryColor.withOpacity(0.3),
                  //     width: 1,
                  //   ),
                  // ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    // Home is now index 0
                    _buildNavBarItem('Home', Icons.home_rounded, 0),
                    // Community is now index 1
                    _buildNavBarItem(
                      'Community',
                      Icons.people_alt_rounded,
                      1,
                    ),
                    // Report is now index 2
                    _buildNavBarItem(
                      'Report',
                      Icons.report_problem_rounded,
                      2,
                    ),
                    // Chat is now index 3
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
