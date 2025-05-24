import 'package:civiceye/features/auth/pages/unAuthPage.dart';
import 'package:civiceye/features/dashboard/dashboardpage.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    
    // Check for existing session first
    final currentSession = Supabase.instance.client.auth.currentSession;
    
    // If there's an active session already, take user directly to profile
    if (currentSession != null && !currentSession.isExpired) {
      return const Dashboardpage();
    }
    
    // Otherwise listen for auth state changes
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Ensure data exists and extract session
        final session = snapshot.hasData ? snapshot.data!.session : null;

        return session == null ? const UnAuthPage() : const ProfilePage();
      },
    );
  }
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Container();
  }
}
