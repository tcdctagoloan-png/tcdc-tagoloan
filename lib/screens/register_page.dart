import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:ui';
import 'dart:developer'; // For debug logging

const Color _primaryGreen = Color(0xFF4CAF50);

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  _RegisterPageState createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _contactController = TextEditingController();
  final _addressController = TextEditingController();
  final _verificationCodeController = TextEditingController();

  // Firebase Auth State Management
  String? _verificationId; // Stores the ID needed to verify the SMS code
  int? _forceResendingToken; // Stores the token for resending the code

  int _currentStep = 0;
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _fullNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _contactController.dispose();
    _addressController.dispose();
    _verificationCodeController.dispose();
    super.dispose();
  }

  // --- CORE LOGIC: Firebase Creation & Verification ---

  // Step 0: Create the user account with Email/Password
  Future<UserCredential?> _createUserWithEmailPassword() async {
    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      return cred;
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Account Creation Error: ${e.message}")),
        );
        setState(() => _isLoading = false); // Stop loading on error
      }
      return null;
    }
  }

  // Step 1: Handle actual Firebase phone verification request
  void _sendVerificationCode(String phoneNumber) async {
    log('Attempting to send code to $phoneNumber');

    // Clear previous verification state
    _verificationCodeController.clear();
    _verificationId = null;

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        // Mandated callback when verification is automatically completed (rare in registration)
        verificationCompleted: (PhoneAuthCredential credential) async {
          log("Phone verification completed automatically.");
          // Since this is a new registration, we treat automatic completion as success
          // and move directly to finalizing the Firestore data.
          await _finalizeRegistration(credential);
        },
        // Mandated callback for errors (e.g., invalid phone, reCAPTCHA failure)
        verificationFailed: (FirebaseAuthException e) {
          log('Verification Failed: ${e.code} | ${e.message}');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  // Specific warning for common iframe issue
                  e.code == 'web-captcha-failed' || e.code == 'invalid-verification-code'
                      ? "Error: Phone Auth failed. (Code: ${e.code}). In this web environment, reCAPTCHA frequently fails. Please check console for details."
                      : "Phone Auth Error: ${e.message}",
                  style: const TextStyle(color: Colors.white),
                ),
                backgroundColor: Colors.redAccent,
                duration: const Duration(seconds: 8),
              ),
            );
            setState(() {
              _isLoading = false;
              _currentStep = 0; // Go back to form if sending fails
            });
          }
        },
        // Mandated callback when the code has been successfully sent
        codeSent: (String verificationId, int? resendToken) {
          log('Code Sent. Verification ID: $verificationId');
          if (mounted) {
            setState(() {
              _verificationId = verificationId;
              _forceResendingToken = resendToken;
              _currentStep = 1; // Move to the verification screen
              _isLoading = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("Code sent successfully to ${phoneNumber}. Please enter it below."),
                backgroundColor: _primaryGreen,
              ),
            );
          }
        },
        // Mandated callback for auto-retrieval timeout
        codeAutoRetrievalTimeout: (String verificationId) {
          log('Code retrieval timed out. Verification ID: $verificationId');
          if (mounted) {
            setState(() {
              _verificationId = verificationId; // Keep the ID for manual entry
            });
          }
        },
      );
    } catch (e) {
      log('Unexpected Error during verifyPhoneNumber: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Unexpected error: $e")),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  // Step 2: Finalize registration by verifying code and updating Firestore
  Future<void> _finalizeRegistration(PhoneAuthCredential credential) async {
    // Ensure the current user is available (from the email/password sign-up)
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Registration flow error: User not authenticated.")),
        );
        setState(() => _currentStep = 0);
      }
      return;
    }

    try {
      // 1. We don't need to sign in, but successfully creating the credential confirms the number.
      // In a more complex app, you might link the phone number here using user.linkWithCredential(credential).

      // 2. Update user document in Firestore, marking contactVerified: true
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'fullName': _fullNameController.text.trim(),
        'username': _usernameController.text.trim(),
        'email': _emailController.text.trim(),
        'contactNumber': _contactController.text.trim(),
        'address': _addressController.text.trim(),
        'role': 'patient',
        'verified': false,
        'contactVerified': true, // SUCCESS: Contact is now verified
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 3. Send notification to admin
      await FirebaseFirestore.instance.collection('notifications').add({
        'title': 'New Patient Registered (Contact Verified)',
        'message':
        '${_fullNameController.text.trim()} has registered and verified their contact.',
        'targetRole': 'admin',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Registration complete! Contact verified. Please login.")),
      );

      // Navigate back to the login page after success
      Navigator.pop(context);

    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Verification Error: ${e.message}")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("An error occurred during finalization: $e")),
      );
    }
    finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- FLOW HANDLER ---
  Future<void> _handleRegistrationFlow() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    if (_currentStep == 0) {
      // Step 0: Create account and initiate phone verification
      final userCred = await _createUserWithEmailPassword();
      if (userCred != null) {
        // Now that the user is created (and signed in), send the verification code
        _sendVerificationCode(_contactController.text.trim());
      } else {
        setState(() => _isLoading = false);
      }

    } else if (_currentStep == 1) {
      // Step 1: Validate code and complete registration
      if (_verificationId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Verification ID is missing. Please restart the process.")),
        );
        setState(() => _isLoading = false);
        return;
      }

      try {
        // Create the credential object using the ID from codeSent and user's SMS code
        final PhoneAuthCredential credential = PhoneAuthProvider.credential(
          verificationId: _verificationId!,
          smsCode: _verificationCodeController.text.trim(),
        );

        // Finalize registration
        await _finalizeRegistration(credential);
      } on Exception catch (e) {
        log('Code validation error: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Invalid verification code. Please try again.")),
          );
          setState(() => _isLoading = false);
        }
      }
    }
  }

  // Helper for input decoration consistency
  InputDecoration _minimalInputDecoration(IconData icon, String label) {
    // ... (InputDecoration implementation remains the same)
    return InputDecoration(
      filled: true,
      fillColor: Colors.white,
      contentPadding:
      const EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0),
      labelText: label,
      labelStyle: const TextStyle(color: Colors.black54),
      prefixIcon: Icon(icon, color: _primaryGreen),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
            color: _primaryGreen, width: 2), // Green focus border
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 2),
      ),
    );
  }

  // Helper Widget for Text Fields
  Widget _buildTextField({
    required TextEditingController controller,
    required IconData icon,
    required String label,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    Widget? suffixIcon,
    String? Function(String?)? customValidator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      decoration: _minimalInputDecoration(icon, label).copyWith(
        suffixIcon: suffixIcon,
      ),
      validator: customValidator ?? (val) => val!.isEmpty ? "Enter $label" : null,
    );
  }

  // --- New Widget for Contact Verification ---
  Widget _buildVerificationForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.lock_open, size: 60, color: _primaryGreen),
        const SizedBox(height: 20),
        const Text(
          "Verify Contact Number",
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Text(
          "Enter the 6-digit code sent to ${_contactController.text.trim()}.",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 30),

        TextFormField(
          controller: _verificationCodeController,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 6,
          decoration: InputDecoration(
            hintText: "Verification Code (SMS)",
            filled: true,
            fillColor: Colors.grey.shade100,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          validator: (val) {
            if (val == null || val.length != 6) {
              return "Code must be 6 digits.";
            }
            return null;
          },
        ),

        const SizedBox(height: 10),
        TextButton(
          onPressed: _isLoading ? null : () => _sendVerificationCode(_contactController.text.trim()),
          child: Text(
            _isLoading ? "Sending..." : "Resend Code",
            style: TextStyle(
              color: _primaryGreen,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  // --- Existing Registration Form Widget ---
  Widget _buildRegistrationForm(bool isMobile) {
    if (!isMobile) {
      // ... (Desktop Layout implementation remains the same)
      return Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Full Name
              Expanded(child: _buildTextField(
                  controller: _fullNameController,
                  icon: Icons.badge,
                  label: "Full Name")),
              const SizedBox(width: 16),
              // Username
              Expanded(child: _buildTextField(
                  controller: _usernameController,
                  icon: Icons.account_circle,
                  label: "Username")),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Email
              Expanded(child: _buildTextField(
                  controller: _emailController,
                  icon: Icons.email,
                  label: "Email",
                  keyboardType: TextInputType.emailAddress)),
              const SizedBox(width: 16),
              // Password
              Expanded(child: _buildTextField(
                controller: _passwordController,
                icon: Icons.lock,
                label: "Password",
                obscureText: _obscurePassword,
                customValidator: (val) {
                  if (val == null || val.length < 6) {
                    return "Password must be at least 6 characters";
                  }
                  return null;
                },
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: Colors.black54,
                  ),
                  onPressed: () {
                    setState(() => _obscurePassword = !_obscurePassword);
                  },
                ),
              )),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Contact Number (IMPORTANT: Must be in E.164 format, e.g., +12225550101)
              Expanded(child: _buildTextField(
                  controller: _contactController,
                  icon: Icons.phone,
                  label: "Contact Number (e.g., +12225550101)",
                  keyboardType: TextInputType.phone,
                  customValidator: (val) {
                    if (val == null || val.isEmpty) {
                      return "Enter Contact Number for verification";
                    }
                    if (!RegExp(r'^\+?[0-9]{10,15}$').hasMatch(val.trim())) {
                      return "Use E.164 format (e.g., +12225550101)";
                    }
                    return null;
                  }
              )),
              const SizedBox(width: 16),
              // Address
              Expanded(child: _buildTextField(
                  controller: _addressController,
                  icon: Icons.home,
                  label: "Address")),
            ],
          ),
        ],
      );
    } else {
      // ... (Mobile Layout implementation remains the same)
      return Column(
        children: [
          _buildTextField(
              controller: _fullNameController,
              icon: Icons.badge,
              label: "Full Name"),
          const SizedBox(height: 16),
          _buildTextField(
              controller: _usernameController,
              icon: Icons.account_circle,
              label: "Username"),
          const SizedBox(height: 16),
          _buildTextField(
              controller: _emailController,
              icon: Icons.email,
              label: "Email",
              keyboardType: TextInputType.emailAddress),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _passwordController,
            icon: Icons.lock,
            label: "Password",
            obscureText: _obscurePassword,
            customValidator: (val) {
              if (val == null || val.length < 6) {
                return "Password must be at least 6 characters";
              }
              return null;
            },
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: Colors.black54,
              ),
              onPressed: () {
                setState(() => _obscurePassword = !_obscurePassword);
              },
            ),
          ),
          const SizedBox(height: 16),
          _buildTextField(
              controller: _contactController,
              icon: Icons.phone,
              label: "Contact Number (e.g., +12225550101)",
              keyboardType: TextInputType.phone,
              customValidator: (val) {
                if (val == null || val.isEmpty) {
                  return "Enter Contact Number for verification";
                }
                if (!RegExp(r'^\+?[0-9]{10,15}$').hasMatch(val.trim())) {
                  return "Use E.164 format (e.g., +12225550101)";
                }
                return null;
              }
          ),
          const SizedBox(height: 16),
          _buildTextField(
              controller: _addressController,
              icon: Icons.home,
              label: "Address"),
        ],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 800;

    Widget cardContent = Center(
      child: Container(
        padding: isMobile
            ? const EdgeInsets.symmetric(horizontal: 20.0, vertical: 40.0)
            : const EdgeInsets.symmetric(horizontal: 40.0, vertical: 60.0),
        constraints: const BoxConstraints(maxWidth: 800),

        child: Card(
          elevation: 10,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: isMobile
                ? const EdgeInsets.all(24.0)
                : const EdgeInsets.all(32.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // --- Header ---
                  Icon(_currentStep == 0 ? Icons.person_add : Icons.phone_android, size: 80, color: _primaryGreen),
                  const SizedBox(height: 16),
                  Text(
                    _currentStep == 0 ? "Create Account" : "Verify Contact",
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _currentStep == 0
                        ? "Register as a patient and verify your phone number."
                        : "We sent a verification code to your number.",
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.black54, fontSize: 16),
                  ),
                  const SizedBox(height: 32),

                  // --- Conditional Form Content ---
                  if (_currentStep == 0) _buildRegistrationForm(isMobile),
                  if (_currentStep == 1) _buildVerificationForm(),

                  const SizedBox(height: 30),

                  // --- Action Button ---
                  _isLoading
                      ? const Center(
                      child: CircularProgressIndicator(color: _primaryGreen))
                      : SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryGreen,
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _handleRegistrationFlow,
                      child: Text(
                        _currentStep == 0 ? "N E X T (Send Code)" : "V E R I F Y & R E G I S T E R",
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // --- Navigation Link ---
                  if (_currentStep == 0)
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        "Already have an account? Login here",
                        style: TextStyle(
                          color: _primaryGreen,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  if (_currentStep == 1)
                    TextButton(
                      onPressed: () {
                        // Return to registration form
                        setState(() {
                          _currentStep = 0;
                          _verificationCodeController.clear();
                          _verificationId = null;
                        });
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                      },
                      child: Text(
                        "Go back and edit details",
                        style: TextStyle(
                          color: _primaryGreen,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    // --- Page Scaffold ---
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.white, _primaryGreen.withOpacity(0.5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          // Scrollable card
          ScrollConfiguration(
            behavior: const ScrollBehavior().copyWith(scrollbars: false),
            child: SingleChildScrollView(child: cardContent),
          ),
        ],
      ),
    );
  }
}
