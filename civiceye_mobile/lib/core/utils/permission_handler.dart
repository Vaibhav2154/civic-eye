import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';

// Request location permission with feedback
Future<bool> requestLocationPermission() async {
  var status = await Permission.location.request();
  if (status.isGranted) {
    debugPrint("Location permission granted");
    return true;
  } else if (status.isDenied) {
    debugPrint("Location permission denied");
    return false;
  } else if (status.isPermanentlyDenied) {
    debugPrint("Location permission permanently denied");
    await openAppSettings();
    return false;
  }
  return false;
}

// Check if we already have permission
Future<bool> hasLocationPermission() async {
  return await Permission.location.isGranted;
}