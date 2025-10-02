// lib/profile/profile_page.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class ProfilePage extends StatefulWidget {
  final String userId;
  const ProfilePage({super.key, required this.userId});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _contactController = TextEditingController();
  final _addressController = TextEditingController();

  File? _profileImage;
  String? _profileImageUrl;
  bool _isLoading = false;

  String? _role;
  String? _createdAt;
  bool _verified = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  void _loadProfile() async {
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
            ? DateFormat('yyyy-MM-dd').format(ts.toDate())
            : 'Unknown';
      });
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile =
    await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (pickedFile != null) {
      setState(() => _profileImage = File(pickedFile.path));
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      String? imageUrl = _profileImageUrl;

      if (_profileImage != null) {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child(
            'profile_images/${widget.userId}_${DateTime.now().millisecondsSinceEpoch}.jpg');
        final uploadTask = await storageRef.putFile(_profileImage!);
        imageUrl = await uploadTask.ref.getDownloadURL();
      }

      final password = _passwordController.text.trim();
      if (password.isNotEmpty) {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await user.updatePassword(password);
        }
      }

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
        const SnackBar(content: Text("Profile updated successfully!")),
      );
      _passwordController.clear();
      setState(() {
        _profileImage = null;
        _profileImageUrl = imageUrl;
      });
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    bool obscure = false,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    String? hintText,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        prefixIcon: Icon(icon),
        labelText: label,
        hintText: hintText,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.grey[50],
        contentPadding:
        const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      ),
      validator: validator,
    );
  }

  bool _isWideScreen(BuildContext context) =>
      MediaQuery.of(context).size.width >= 900;

  @override
  Widget build(BuildContext context) {
    Widget profileForm() {
      return Form(
        key: _formKey,
        child: Column(
          children: [
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                CircleAvatar(
                  radius: 60,
                  backgroundImage: _profileImage != null
                      ? FileImage(_profileImage!)
                      : (_profileImageUrl != null &&
                      _profileImageUrl!.isNotEmpty)
                      ? NetworkImage(_profileImageUrl!)
                      : const AssetImage("assets/default_profile.png")
                  as ImageProvider,
                  onBackgroundImageError: (_, __) {},
                ),
                InkWell(
                  onTap: _pickImage,
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.blue,
                    child: const Icon(Icons.camera_alt,
                        color: Colors.white, size: 18),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (_role != null)
              Container(
                padding: const EdgeInsets.symmetric(
                    vertical: 12, horizontal: 14),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.verified_user),
                    const SizedBox(width: 12),
                    Text(_role!,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    if (_verified)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          "Verified",
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12),
                        ),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 24),
            _buildTextField(
                label: "Username",
                controller: _usernameController,
                icon: Icons.account_circle,
                validator: (v) =>
                v == null || v.isEmpty ? "Enter username" : null),
            const SizedBox(height: 16),
            _buildTextField(
                label: "Email",
                controller: _emailController,
                icon: Icons.email,
                keyboardType: TextInputType.emailAddress,
                validator: (v) =>
                v == null || v.isEmpty ? "Enter email" : null),
            const SizedBox(height: 16),
            _buildTextField(
                label: "Password",
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
            const SizedBox(height: 24),
            _isLoading
                ? const CircularProgressIndicator()
                : SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _saveProfile,
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Ink(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [
                          Colors.blue,
                          Colors.lightBlueAccent
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

    if (!_isWideScreen(context)) {
      // MOBILE
      return Scaffold(
        backgroundColor: Colors.grey[100],
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Card(
              shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              elevation: 8,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: profileForm(),
              ),
            ),
          ),
        ),
      );
    }

    // WEB
    return Scaffold(
      body: Container(
        padding: const EdgeInsets.all(32),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.white, Colors.blueAccent],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Card(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            elevation: 10,
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: SizedBox(
                width: 800,
                child: profileForm(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
