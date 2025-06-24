import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';

class EditUser extends StatefulWidget {
  const EditUser({super.key, this.userData});
  final Map<String, dynamic>? userData;


  @override
  EditUserState createState() => EditUserState();
}

class EditUserState extends State<EditUser> {
  final _formKey = GlobalKey<FormState>();
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _logger = Logger();

  late User _user;
  late TextEditingController _emailController;
  late TextEditingController _nameController;
  late TextEditingController _passwordController;
  late TextEditingController _dcNumberController;
  late TextEditingController _probationOfficerController;

  @override
  void initState() {
    super.initState();
    _user = _auth.currentUser!;
    _emailController = TextEditingController(text: _user.email);
    _nameController = TextEditingController(text: _user.displayName ?? '');
    _passwordController = TextEditingController();
    _dcNumberController = TextEditingController();
    _probationOfficerController = TextEditingController();
    _loadUserCustomData();
  }

  Future<void> _loadUserCustomData() async {
    try {
      final docSnapshot =
      await _firestore.collection('users').doc(_user.uid).get();
      if (docSnapshot.exists && docSnapshot.data() != null) {
        final data = docSnapshot.data() as Map<String, dynamic>;
        if (mounted) {
          // Check if mounted before calling setState
          setState(() {
            _dcNumberController.text = data['dcNumber'] ?? '';
            _probationOfficerController.text = data['probationOfficer'] ?? '';
          });
        }
      }
    } catch (e) {
      _logger.e("Error loading user custom data: $e");
      // Optionally show a snackbar to the user if data loading fails
      // ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to load user details.")));
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _nameController.dispose();
    _passwordController.dispose();
    _dcNumberController.dispose();
    _probationOfficerController.dispose();
    super.dispose();
  }

  void _updateUserInfo() async {
    if (_formKey.currentState!.validate()) {
      try {
        // Update email
        if (_emailController.text != _user.email) {
          await _user.verifyBeforeUpdateEmail(_emailController.text);
        }

        // Update display name
        if (_nameController.text != _user.displayName) {
          await _user.updateDisplayName(_nameController.text);
        }

        // Update password
        if (_passwordController.text.isNotEmpty) {
          await _user.updatePassword(_passwordController.text);
        }

        // Update DCNumber in Firestore
        // Update custom fields in Firestore
        await _firestore
            .collection('users')
            .doc(_user.uid)
            .set({
          'dcNumber': _dcNumberController.text,
          'probationOfficer': _probationOfficerController.text,
        }, SetOptions(merge: true));

        await _user.reload();
        // No need to re-assign _user if only custom data changed,
        // but good practice if auth profile items were updated.
        _user = _auth.currentUser!;
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User info updated')),
        );
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            Navigator.of(context).pop();
          }
        });
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit User')),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/road_lines.png'), // Make sure this path is correct
            fit: BoxFit.cover,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                TextFormField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    label: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                      decoration: BoxDecoration(
                        color: Colors.grey[200], // Lite gray background for the label
                        borderRadius: BorderRadius.circular(4.0),
                      ),
                      child: const Text('Email'),
                    ),
                    filled: true,
                    fillColor: Colors.grey[200],
                    border: const OutlineInputBorder(),
                  ),
                  validator: (val) => val != null && val.contains('@') ? null : 'Enter valid email',
                ),
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    label: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                      decoration: BoxDecoration(
                        color: Colors.grey[200], // Lite gray background for the label
                        borderRadius: BorderRadius.circular(4.0),
                      ),
                      child: const Text('Display Name'),
                    ),
                    filled: true,
                    fillColor: Colors.grey[200],
                    border: const OutlineInputBorder(),
                  ),
                ),
                TextFormField(
                  controller: _dcNumberController,
                  decoration: InputDecoration(
                    label: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                      decoration: BoxDecoration(
                        color: Colors.grey[200], // Lite gray background for the label
                        borderRadius: BorderRadius.circular(4.0),
                      ),
                      child: const Text('DCNumber'),
                    ),
                    filled: true,
                    fillColor: Colors.grey[200],
                    border: const OutlineInputBorder(),
                  ),
                ),
                TextFormField(
                    controller: _probationOfficerController,
                    decoration: InputDecoration(
                      label: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                        decoration: BoxDecoration(
                          color: Colors.grey[200], // Lite gray background for the label
                          borderRadius: BorderRadius.circular(4.0),
                        ),
                        child: const Text('Probation Officer'),
                      ),
                      filled: true,
                      fillColor: Colors.grey[200],
                      border: const OutlineInputBorder(),
                    )
                ),
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    label: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                      decoration: BoxDecoration(
                        color: Colors.grey[200], // Lite gray background for the label
                        borderRadius: BorderRadius.circular(4.0),
                      ),
                      child: const Text('New Password'),
                    ),
                    filled: true,
                    fillColor: Colors.grey[200],
                    border: const OutlineInputBorder(),
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _updateUserInfo,
                  child: const Text('Update'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
