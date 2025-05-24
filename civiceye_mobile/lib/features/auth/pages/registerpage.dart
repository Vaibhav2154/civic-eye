import 'dart:ui';
import 'package:civiceye/core/theme/app_pallete.dart';
import 'package:civiceye/features/auth/services/auth_service.dart';
import 'package:flutter/material.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final authservice = AuthService();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailcontroller = TextEditingController();
  final _passwordcontroller = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  void register() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final email = _emailcontroller.text.trim();
    final password = _passwordcontroller.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (name.isEmpty || phone.isEmpty || email.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill in all fields.")),
      );
      return;
    }

    if (!email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter a valid email address.")),
      );
      return;
    }

    if (password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Passwords do not match.")),
      );
      return;
    }

    try {
      final user = await authservice.signUpWithEmailPassword(email, password);
      if (user != null) {
        await authservice.supabaseClient.from('users').insert({
          'id': user.id,
          'full_name': name,
          'email': email,
          'phone': phone,
          'created_at': DateTime.now().toIso8601String(),
          'last_active_at': DateTime.now().toIso8601String(),
        });
      }
      if (mounted) {
        // Pop the current route if registration is successful
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: ${e.toString()}")),
        );
      }
    }
  }

  // Helper widget for glassmorphic input fields
  Widget _glassInputField({
    required String label,
    required TextEditingController controller,
    bool obscure = false,
    TextInputType keyboardType = TextInputType.text, // Added keyboardType
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType, // Applied keyboardType
        style: const TextStyle(color: textColor),
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          labelText: label,
          labelStyle: const TextStyle(color: accentColor),
          border: InputBorder.none,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailcontroller.dispose();
    _passwordcontroller.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: textColor,
        title: const Text("Create Account"),
      ),
      // Using LayoutBuilder to get the available height for proper centering
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          return SingleChildScrollView(
            // Adjust padding to account for keyboard if it appears
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: ConstrainedBox(
              // Ensure the content takes at least the height of the available space
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight,
              ),
              child: IntrinsicHeight( // Allows its child (Column) to size itself based on its children's intrinsic heights
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center, // Center content vertically
                  crossAxisAlignment: CrossAxisAlignment.center, // Center content horizontally
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(25),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 15.0, sigmaY: 15.0),
                          child: Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(25),
                              border: Border.all(color: Colors.white.withOpacity(0.2)),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min, // Keep column size to content
                              children: [
                                _glassInputField(label: "Full Name", controller: _nameController),
                                _glassInputField(label: "Phone Number", controller: _phoneController, keyboardType: TextInputType.phone),
                                _glassInputField(label: "Email", controller: _emailcontroller, keyboardType: TextInputType.emailAddress),
                                _glassInputField(label: "Password", controller: _passwordcontroller, obscure: true),
                                _glassInputField(label: "Confirm Password", controller: _confirmPasswordController, obscure: true),
                                const SizedBox(height: 30),
                                ElevatedButton(
                                  onPressed: register,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: secondaryColor,
                                    foregroundColor: secondaryFgColor,
                                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  ),
                                  child: const Text("Sign Up", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
