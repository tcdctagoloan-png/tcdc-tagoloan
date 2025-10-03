import 'dart:typed_data'; // Needed for Uint8List
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

// Note: dart:io is removed as it's not supported on Flutter Web.

class ProfilePage extends StatefulWidget {
  final String userId;
  const ProfilePage({super.key, required this.userId});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // Controllers for the form fields
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _contactController = TextEditingController();
  final _addressController = TextEditingController();

  // State variables for profile image (using Uint8List for web compatibility) and loading status
  Uint8List? _profileImageBytes; // Stores image data as bytes for web
  String? _profileImageUrl;
  bool _isLoading = false;

  // State variables for non-editable details
  String? _role;
  String? _createdAt;
  bool _verified = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _contactController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  /// Fetches user data from Firestore on widget initialization.
  void _loadProfile() async {
    setState(() => _isLoading = true);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _usernameController.text = data['username'] ?? '';
          _emailController.text = data['email'] ?? '';
          _contactController.text = data['contactNumber'] ?? '';
          _addressController.text = data['address'] ?? '';
          _profileImageUrl = data['profileImage'];
          _role = data['role'] ?? 'Patient';
          _verified = data['verified'] == true;
          final ts = data['createdAt'] as Timestamp?;
          _createdAt = ts != null
              ? DateFormat('MMM d, yyyy').format(ts.toDate())
              : 'Unknown';
        });
      }
    } catch (e) {
      print("Error loading profile: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// Opens the gallery to pick a new profile image.
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile =
    await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (pickedFile != null) {
      // FIX for Web: Read the file data as bytes instead of creating a dart:io File object
      final bytes = await pickedFile.readAsBytes();
      setState(() => _profileImageBytes = bytes);
    }
  }

  /// Handles the save operation: uploading image, updating password, and updating Firestore.
  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      String? imageUrl = _profileImageUrl;

      // 1. Upload new image if selected (using bytes for web compatibility)
      if (_profileImageBytes != null) {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child(
            'profile_images/${widget.userId}_${DateTime.now().millisecondsSinceEpoch}.jpg');

        // FIX for Web: Use putData for uploading Uint8List (bytes)
        final uploadTask = await storageRef.putData(_profileImageBytes!, SettableMetadata(contentType: 'image/jpeg'));
        imageUrl = await uploadTask.ref.getDownloadURL();
      }

      // 2. Update password if field is not empty
      final password = _passwordController.text.trim();
      if (password.isNotEmpty) {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          // This operation requires the user to have recently signed in
          await user.updatePassword(password);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Password updated successfully!")),
          );
        }
      }

      // 3. Update user data in Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .update({
        'username': _usernameController.text.trim(),
        'email': _emailController.text.trim(),
        'contactNumber': _contactController.text.trim(),
        'address': _addressController.text.trim(),
        'profileImage': imageUrl,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Profile details updated successfully!")),
      );

      // Reset temporary states after successful save
      _passwordController.clear();
      setState(() {
        _profileImageBytes = null; // Clear temporary bytes
        _profileImageUrl = imageUrl; // Update network URL
      });

    } on FirebaseAuthException catch (e) {
      String errorMessage = "Authentication Error: ${e.message}";
      if (e.code == 'requires-recent-login') {
        errorMessage = 'Please sign in again to update your password.';
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(errorMessage)));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // --- UI Builder Methods ---

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    bool obscure = false,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    String? hintText,
    bool readOnly = false,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      readOnly: readOnly,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.blue.shade700),
        labelText: label,
        hintText: hintText,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: readOnly ? Colors.grey[200] : Colors.white,
        contentPadding:
        const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      ),
      validator: validator,
    );
  }

  /// Builds the CircleAvatar for the profile image with proper fallbacks.
  Widget _buildProfileImageAvatar() {
    ImageProvider? imageProvider;
    Widget? fallbackChild;

    // Use MemoryImage for the newly picked image bytes (Web compatible)
    if (_profileImageBytes != null) {
      imageProvider = MemoryImage(_profileImageBytes!);
    }
    // Fallback to NetworkImage if a URL is already stored
    else if (_profileImageUrl != null && _profileImageUrl!.isNotEmpty) {
      imageProvider = NetworkImage(_profileImageUrl!);
    }
    // Fallback to Icon if no image data or URL is available
    else {
      fallbackChild = Icon(Icons.person, size: 60, color: Colors.blue.shade700);
    }

    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        CircleAvatar(
          radius: 60,
          backgroundColor: Colors.blue.shade100,
          backgroundImage: imageProvider,
          child: fallbackChild,
        ),
        InkWell(
          onTap: _pickImage,
          child: CircleAvatar(
            radius: 18,
            backgroundColor: Colors.blue.shade700,
            child: const Icon(Icons.camera_alt,
                color: Colors.white, size: 18),
          ),
        ),
      ],
    );
  }


  /// Determines if the screen is wide (desktop/tablet) for layout adjustments.
  bool _isWideScreen(BuildContext context) =>
      MediaQuery.of(context).size.width >= 900;

  Widget _buildProfileForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          // Profile Image Picker
          _buildProfileImageAvatar(),
          const SizedBox(height: 24),

          // Role and Verification Status Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.lightBlue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.shield, color: Colors.blue, size: 24),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Role: ${_role ?? 'N/A'}",
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Text(
                          "Member Since: ${_createdAt ?? 'N/A'}",
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _verified ? Colors.green.shade600 : Colors.orange.shade600,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _verified ? "VERIFIED" : "UNVERIFIED",
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Form Fields
          _buildTextField(
              label: "Username",
              controller: _usernameController,
              icon: Icons.account_circle,
              validator: (v) =>
              v == null || v.isEmpty ? "Enter username" : null),
          const SizedBox(height: 16),
          // Email is read-only as it's typically tied to the auth provider
          _buildTextField(
              label: "Email (Read-Only)",
              controller: _emailController,
              icon: Icons.email,
              keyboardType: TextInputType.emailAddress,
              readOnly: true,
              validator: (v) =>
              v == null || v.isEmpty ? "Enter email" : null),
          const SizedBox(height: 16),
          _buildTextField(
              label: "New Password",
              controller: _passwordController,
              icon: Icons.lock,
              obscure: true,
              hintText: "Leave blank to keep current password"),
          const SizedBox(height: 16),
          _buildTextField(
              label: "Contact Number",
              controller: _contactController,
              icon: Icons.phone,
              keyboardType: TextInputType.phone,
              validator: (v) =>
              v == null || v.isEmpty ? "Enter contact" : null),
          const SizedBox(height: 16),
          _buildTextField(
              label: "Address",
              controller: _addressController,
              icon: Icons.home,
              keyboardType: TextInputType.streetAddress,
              validator: (v) =>
              v == null || v.isEmpty ? "Enter address" : null),
          const SizedBox(height: 32),

          // Save Button
          _isLoading
              ? const CircularProgressIndicator(color: Colors.blue)
              : SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _saveProfile,
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 5,
              ),
              child: Ink(
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    Colors.blue.shade600,
                    Colors.lightBlue.shade400
                  ]),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Container(
                  alignment: Alignment.center,
                  child: const Text(
                    "Save Changes",
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isWideScreen(context)) {
      // WEB Layout
      return Scaffold(
        body: Container(
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.white, Colors.blue.shade100],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Center(
            child: Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25)),
              elevation: 12,
              child: Padding(
                padding: const EdgeInsets.all(40.0),
                child: SizedBox(
                  width: 600, // Constrain width for large screens
                  // SingleChildScrollView remains here to prevent overflow
                  child: SingleChildScrollView(
                    child: _buildProfileForm(),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    // MOBILE Layout
    return Scaffold(
      appBar: AppBar(
        title: const Text("User Profile"),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.grey[100],
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Card(
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            elevation: 8,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: _buildProfileForm(),
            ),
          ),
        ),
      ),
    );
  }
}
