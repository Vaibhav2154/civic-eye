import 'package:civiceye/features/auth/services/auth_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';


Future<void> main() async {
   WidgetsFlutterBinding.ensureInitialized(); 
  await dotenv.load(fileName: ".env");
  try {
    await Supabase.initialize(
      url: dotenv.env['SUPABASE_URL'] ?? 'https://default-url.supabase.co',
      anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? 'default-anon-key',
      authOptions: FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce
      ),
      debug: true,
    );
  } catch (e) {
    debugPrint("Error initializing Supabase: $e");
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home:  const AuthGate(),  
    );
  }
}

