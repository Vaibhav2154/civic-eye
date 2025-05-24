import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  SupabaseClient get supabaseClient => _supabase;

  // Sign in with email and password
  Future<void> signInWithEmailPassword(String email, String password) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      if (response.session == null) {
        throw Exception('Invalid email or password');
      }
    } catch (e) {
      throw Exception('Login failed: $e');
    }
  }

  // Sign up with email and password, return the user object
  Future<User?> signUpWithEmailPassword(String email, String password) async {
    try {
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
      );
      if (response.user == null) {
        throw Exception('Sign-up failed');
      }
      return response.user;
    } catch (e) {
      throw Exception('Sign-up error: $e');
    }
  }

  // Check if user is authenticated
  bool isAuthenticated() {
    final session = _supabase.auth.currentSession;
    return session != null && !session.isExpired;
  }

  // Get current user session
  Session? getCurrentSession() {
    return _supabase.auth.currentSession;
  }

  // Refresh the session if it's expired but has a refresh token
  Future<void> refreshSession() async {
    final session = _supabase.auth.currentSession;
    if (session != null && session.isExpired) {
      try {
        await _supabase.auth.refreshSession();
      } catch (e) {
        throw Exception('Session refresh failed: $e');
      }
    }
  }

  // Update password
  Future<void> updatePassword(String newPassword) async {
    try {
      await _supabase.auth.updateUser(UserAttributes(password: newPassword));
    } catch (e) {
      throw Exception("Password update failed: $e");
    }
  }

  // Forgot Password (Send Reset Link)
  Future<void> resetPassword(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(email, redirectTo: "unihub://auth/callback");
    } catch (e) {
      throw Exception('Password reset failed: $e');
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
    } catch (e) {
      throw Exception('Sign-out error: $e');
    }
  }

  // Get current user email
  String? getCurrentUserEmail() {
    final session = _supabase.auth.currentSession;
    return session?.user.email;
  }

  //Get  current user id
  String? getCurrentUserId() {
    final session = _supabase.auth.currentSession;
    return session?.user.id;
  }

  
}