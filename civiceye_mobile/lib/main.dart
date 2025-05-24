import 'package:civiceye/features/auth/pages/unAuthPage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';


Future<void> main() async {
   WidgetsFlutterBinding.ensureInitialized(); // Ensure Flutter binding is initialized
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

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home:  UnAuthPage(),  
    );
  }
}

