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
            SizedBox(height: 4),
            Text(label, style: TextStyle(color: Colors.white, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
           child: Padding(
               padding: const EdgeInsets.all(16.0),
               child: Column(
             crossAxisAlignment: CrossAxisAlignment.center,
               children: [
              Image.asset('assets/logo.png', height: 250, width: 300),
              Text(
                'Emergency Access',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              SizedBox(height: 30),
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
              SizedBox(height: 40),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "🔍 Nearest Hospital: $nearestHospital",
                    style: TextStyle(color: textColor, fontSize: 14),
                  ),
                  SizedBox(height: 8),
                  Text(
                    "🚒 Nearest Fire Station: $nearestFireStation",
                    style: TextStyle(color: textColor, fontSize: 14),
                  ),
                ],
              ),
              SizedBox(height: 30),
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: primaryColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Icon(Icons.location_city, color: Colors.yellowAccent),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        crimeAlert,
                        style: TextStyle(color: textColor, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 40),
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: secondaryColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Text(
                      '🔒 Log in or Sign up to access more features like Whistleblowing, Evidence Upload, Stealth Mode & more.',
                      style: TextStyle(
                        color: secondaryFgColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton(
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
                          ),
                          child: Text(
                            'Login',
                            style: TextStyle(color: primaryFgColor,fontSize: 16),
                          ),
                        ),
                        SizedBox(width: 20),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const RegisterPage(),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                          ),
                          child: Text(
                            'Signup',
                            style: TextStyle(color: primaryFgColor,fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}