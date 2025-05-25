import 'dart:convert';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'package:civiceye/core/theme/app_pallete.dart';
import 'package:civiceye/core/utils/permission_handler.dart';
import 'package:civiceye/features/auth/pages/loginpage.dart';
import 'package:civiceye/features/auth/pages/registerpage.dart';

class UnAuthPage extends StatefulWidget {
  const UnAuthPage({super.key});

  @override
  State<UnAuthPage> createState() => _UnAuthPageState();
}

class _UnAuthPageState extends State<UnAuthPage> {
  String crimeAlert = 'Fetching your location...';
  String nearestHospital = 'Searching...';
  String nearestFireStation = 'Searching...';
  String nearestPoliceStation = 'Searching...';

  double? latitude;
  double? longitude;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
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

        // Set basic location info while waiting for geocoding
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
          // We already set basic location info above, so no need to update UI here
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
    return Scaffold(
      backgroundColor: backgroundColor,
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
              "Emergency Access",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 22,
                color: Colors.white,
              ),
            ),
            centerTitle: true,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),

              // Logo Section
              Image.asset('assets/logo.png', height: 200, width: 250),
              
              const SizedBox(height: 20),

              // SOS Section with Dashboard styling
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
                          } else {
                            print('Could not launch $phoneNumber');
                          }
                        }),
                        _buildSOSButton('Ambulance', Icons.local_hospital, () async {
                          const phoneNumber = 'tel:102';
                          if (await canLaunchUrl(Uri.parse(phoneNumber))) {
                            await launchUrl(Uri.parse(phoneNumber));
                          } else {
                            print('Could not launch $phoneNumber');
                          }
                        }),
                        _buildSOSButton(
                          'Fire',
                          Icons.local_fire_department,
                          () async {
                            const phoneNumber = 'tel:101';
                            if (await canLaunchUrl(Uri.parse(phoneNumber))) {
                              await launchUrl(Uri.parse(phoneNumber));
                            } else {
                              print('Could not launch $phoneNumber');
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 25),

              // Location Info with Dashboard styling
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

              const SizedBox(height: 25),

              // Emergency Services with Dashboard styling
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
                        if (latitude != null && longitude != null) {
                          final mapUrl = 'https://www.google.com/maps/search/hospital/@$latitude,$longitude';
                          if (await canLaunchUrl(Uri.parse(mapUrl))) {
                            await launchUrl(Uri.parse(mapUrl), mode: LaunchMode.externalApplication);
                          }
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
                        if (latitude != null && longitude != null) {
                          final mapUrl = 'https://www.google.com/maps/search/fire+station/@$latitude,$longitude';
                          if (await canLaunchUrl(Uri.parse(mapUrl))) {
                            await launchUrl(Uri.parse(mapUrl), mode: LaunchMode.externalApplication);
                          }
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
                        if (latitude != null && longitude != null) {
                          final mapUrl = 'https://www.google.com/maps/search/police+station/@$latitude,$longitude';
                          if (await canLaunchUrl(Uri.parse(mapUrl))) {
                            await launchUrl(Uri.parse(mapUrl), mode: LaunchMode.externalApplication);
                          }
                        }
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // Auth Section with enhanced styling
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      secondaryColor.withOpacity(0.8),
                      const Color.fromARGB(255, 45, 85, 165).withOpacity(0.6),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 15,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: const Icon(
                        Icons.security,
                        color: Colors.amber,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 15),
                    Text(
                      '🔒 Access More Features',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Log in or Sign up to access advanced features like Whistleblowing, Evidence Upload, Stealth Mode & more.',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Expanded(
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const Loginpage(),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 5,
                                shadowColor: Colors.black.withOpacity(0.3),
                              ),
                              child: const Text(
                                'Login',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Container(
                            margin: const EdgeInsets.only(left: 8),
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const RegisterPage(),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: primaryColor,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(color: primaryColor, width: 2),
                                ),
                                elevation: 5,
                                shadowColor: Colors.black.withOpacity(0.3),
                              ),
                              child: const Text(
                                'Sign Up',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}