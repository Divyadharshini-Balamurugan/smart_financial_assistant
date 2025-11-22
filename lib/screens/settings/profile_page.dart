// lib/pages/profile_service_and_page.dart
// Combined: ProfileService + ProfilePage (Stateful) with unobtrusive autosave.

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Simple service to stream and update user profile fields.
class ProfileService {
  final FirebaseFirestore _firestore;
  final String usersCollection;

  ProfileService({FirebaseFirestore? firestore, this.usersCollection = 'users'}) : _firestore = firestore ?? FirebaseFirestore.instance;

  Stream<DocumentSnapshot<Map<String, dynamic>>> userDocStream(String uid) {
    return _firestore.collection(usersCollection).doc(uid).snapshots();
  }

  Future<void> updateFields(String uid, Map<String, dynamic> data) {
    final mutated = Map<String, dynamic>.from(data);
    if (!mutated.containsKey('updatedAt')) {
      mutated['updatedAt'] = FieldValue.serverTimestamp();
    }
    return _firestore.collection(usersCollection).doc(uid).update(mutated);
  }

  Future<void> setProfileMap(String uid, Map<String, dynamic> profileMap) {
    return _firestore.collection(usersCollection).doc(uid).set({
      'profile': profileMap,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}

/// ProfilePage: unobtrusive autosave, change-password flow (reset email),
/// double-tap delete to confirm (no blocking dialogs), small saving indicator in AppBar.
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _profileService = ProfileService();
  final _auth = FirebaseAuth.instance;

  late final TextEditingController firstNameController;
  late final TextEditingController lastNameController;
  late final TextEditingController usernameController;
  late final TextEditingController emailController;

  Timer? _debounceTimer;
  bool _isSaving = false;
  bool _showSavedTick = false; // small "Saved" hint
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _docSub;
  String? uid;

  // inline status messages (non-intrusive, shown under fields)
  String? _emailStatus; // e.g. 'Re-auth required', 'Saved', 'Failed'
  String? _passwordStatus; // e.g. 'Reset link sent'

  // delete confirmation state (double-tap within 3s)
  bool _confirmDelete = false;
  Timer? _deleteTimer;

  @override
  void initState() {
    super.initState();
    uid = _auth.currentUser?.uid;

    firstNameController = TextEditingController();
    lastNameController = TextEditingController();
    usernameController = TextEditingController();
    emailController = TextEditingController();

    firstNameController.addListener(_onFieldChanged);
    lastNameController.addListener(_onFieldChanged);
    usernameController.addListener(_onFieldChanged);
    emailController.addListener(_onFieldChanged);

    if (uid != null) _startListeningToUserDoc(uid!);
  }

  void _startListeningToUserDoc(String uid) {
    _docSub = _profileService.userDocStream(uid).listen((snapshot) {
      if (!snapshot.exists) return;
      final data = snapshot.data() ?? <String, dynamic>{};
      final profile = (data['profile'] is Map) ? Map<String, dynamic>.from(data['profile']) : <String, dynamic>{};

      _setControllerIfDifferent(firstNameController, profile['firstName']?.toString() ?? '');
      _setControllerIfDifferent(lastNameController, profile['lastName']?.toString() ?? '');
      _setControllerIfDifferent(usernameController, profile['username']?.toString() ?? '');
      _setControllerIfDifferent(emailController, data['email']?.toString() ?? '');
    }, onError: (_) {
      // silent failure - unobtrusive
    });
  }

  void _setControllerIfDifferent(TextEditingController c, String value) {
    if (c.text != value) {
      final sel = c.selection;
      c.text = value;
      try {
        c.selection = sel;
      } catch (_) {}
    }
  }

  void _onFieldChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 800), () async {
      await _saveChangedFields();
    });
    setState(() {});
  }

  Future<void> _saveChangedFields() async {
    if (uid == null) return;

    final Map<String, dynamic> updateData = {
      'profile.firstName': firstNameController.text.trim(),
      'profile.lastName': lastNameController.text.trim(),
      'profile.username': usernameController.text.trim(),
    };

    // email needs special handling with FirebaseAuth; attempt update but if it fails
    final String newEmail = emailController.text.trim();
    final String? currentEmail = _auth.currentUser?.email;

    setState(() => _isSaving = true);

    try {
      // 1) Update firestore profile fields (optimistic, atomic)
      await _profileService.updateFields(uid!, updateData);

      // 2) Try to update FirebaseAuth email when changed (silent handling)
      if (newEmail.isNotEmpty && newEmail != (currentEmail ?? '')) {
        try {
          await _auth.currentUser!.updateEmail(newEmail);
          await _auth.currentUser!.sendEmailVerification();
          _emailStatus = 'Email updated (verification sent)';
        } on FirebaseAuthException catch (e) {
          // Common case: requires-recent-login
          if (e.code == 'requires-recent-login') {
            _emailStatus = 'Re-auth required to change email';
            // revert email field locally to current email from auth so user knows
            final revert = currentEmail ?? '';
            _setControllerIfDifferent(emailController, revert);
          } else {
            _emailStatus = 'Email update failed';
          }
        } catch (_) {
          _emailStatus = 'Email update failed';
        }
      } else {
        _emailStatus = null;
      }

      // show a tiny saved tick for 1.5s
      _showSavedTick = true;
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) setState(() => _showSavedTick = false);
      });
    } catch (e) {
      // silent error handling - set small inline status
      _emailStatus = 'Failed to save profile';
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // Change password -> send password reset email. Non-blocking, shows inline text.
  Future<void> _sendPasswordReset() async {
    final email = emailController.text.trim();
    if (email.isEmpty) {
      _passwordStatus = 'Email required to send reset link';
      _clearStatusAfterDelay('_password');
      setState(() {});
      return;
    }

    try {
      await _auth.sendPasswordResetEmail(email: email);
      _passwordStatus = 'Reset link sent';
    } catch (_) {
      _passwordStatus = 'Failed to send reset link';
    }
    _clearStatusAfterDelay('_password');
    setState(() {});
  }

  void _clearStatusAfterDelay(String which) {
    Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() {
        if (which == '_password') _passwordStatus = null;
        if (which == '_email') _emailStatus = null;
      });
    });
  }

  // Double-tap delete: first tap arms, second tap within 3s confirms.
  Future<void> _onDeletePressed() async {
    if (!_confirmDelete) {
      setState(() => _confirmDelete = true);
      _deleteTimer?.cancel();
      _deleteTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => _confirmDelete = false);
      });
      return; // first tap just arms
    }

    // Confirmed: attempt delete (silent), then sign out
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).delete();
      await _auth.signOut();
      // pop until root without dialog
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (_) {
      // set small inline status on failure
      _emailStatus = 'Delete failed';
      _clearStatusAfterDelay('_email');
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _docSub?.cancel();
    _deleteTimer?.cancel();

    firstNameController.removeListener(_onFieldChanged);
    lastNameController.removeListener(_onFieldChanged);
    usernameController.removeListener(_onFieldChanged);
    emailController.removeListener(_onFieldChanged);

    firstNameController.dispose();
    lastNameController.dispose();
    usernameController.dispose();
    emailController.dispose();
    super.dispose();
  }

  Widget _buildTextField(String label, TextEditingController controller,
      {TextInputType keyboardType = TextInputType.text}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            filled: true,
            fillColor: Colors.grey.shade200,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE0E0E0), width: 1.2),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE0E0E0), width: 1.2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFBDBDBD), width: 1.4),
            ),
          ),
          style: const TextStyle(fontSize: 15, color: Colors.black),
        ),
      ],
    );
  }

  Widget _buildChangePasswordTile() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Password",
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _sendPasswordReset,
          child: Container(
            height: 50,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE0E0E0)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Change Password", style: TextStyle(fontSize: 15, color: Colors.grey)),
                Icon(Icons.lock_reset, color: Colors.grey),
              ],
            ),
          ),
        ),
        if (_passwordStatus != null) ...[
          const SizedBox(height: 8),
          Text(_passwordStatus!, style: const TextStyle(fontSize: 13, color: Colors.black54)),
        ]
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final avatarText = (firstNameController.text.isNotEmpty) ? firstNameController.text[0].toUpperCase() : 'D';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.grey),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Profile', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Center(
              child: _isSaving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : _showSavedTick
                      ? const Icon(Icons.check, color: Colors.green, size: 18)
                      : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFD9D9D9), width: 2),
              ),
              child: Center(
                child: Text(avatarText, style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w600, color: Colors.black)),
              ),
            ),
            const SizedBox(height: 40),

            _buildTextField("First name", firstNameController),
            const SizedBox(height: 15),
            _buildTextField("Last name", lastNameController),
            const SizedBox(height: 15),
            _buildTextField("Username", usernameController),
            const SizedBox(height: 15),
            _buildTextField("Email", emailController, keyboardType: TextInputType.emailAddress),
            if (_emailStatus != null) ...[
              const SizedBox(height: 8),
              Text(_emailStatus!, style: const TextStyle(fontSize: 13, color: Colors.black54)),
            ],
            const SizedBox(height: 15),
            _buildChangePasswordTile(),
            const SizedBox(height: 40),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _onDeletePressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _confirmDelete ? Colors.red : Colors.white,
                  side: BorderSide(color: _confirmDelete ? Colors.red.shade700 : Colors.red),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: Text(
                  _confirmDelete ? 'CONFIRM DELETE (tap again to abort)' : 'DELETE ACCOUNT',
                  style: TextStyle(
                    color: _confirmDelete ? Colors.white : Colors.red,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
