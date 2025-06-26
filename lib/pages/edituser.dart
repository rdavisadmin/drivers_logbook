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

  // New state variable to hold the list of vehicles
  final List<Map<String, dynamic>> _vehicles = [];
  // New state variable to track the selected vehicle from the dropdown
  String? _selectedVehicleTag;

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

  /// Loads all user data from Firestore, including the new list of vehicles.
  Future<void> _loadUserCustomData() async {
    try {
      final docSnapshot =
      await _firestore.collection('users').doc(_user.uid).get();
      if (docSnapshot.exists && docSnapshot.data() != null) {
        final data = docSnapshot.data() as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            _dcNumberController.text = data['dcNumber'] ?? '';
            _probationOfficerController.text = data['probationOfficer'] ?? '';

            // Load vehicles data from Firestore.
            // It's stored as an array of maps.
            if (data['vehicles'] != null && data['vehicles'] is List) {
              _vehicles.clear(); // Clear the list before populating
              for (var vehicleData in data['vehicles']) {
                if (vehicleData is Map<String, dynamic>) {
                  _vehicles.add(vehicleData);
                }
              }
            }
            // Set the default selected vehicle in the dropdown if any exist
            if (_vehicles.isNotEmpty) {
              _selectedVehicleTag = _vehicles.first['tag'];
            }
          });
        }
      }
    } catch (e) {
      _logger.e("Error loading user custom data: $e");
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to load user details.")));
      }
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

  /// Updates all user information, including the list of vehicles, in Firestore.
  void _updateUserInfo() async {
    if (_formKey.currentState!.validate()) {
      try {
        // Update standard Firebase Auth fields
        if (_emailController.text != _user.email) {
          await _user.verifyBeforeUpdateEmail(_emailController.text);
        }
        if (_nameController.text != _user.displayName) {
          await _user.updateDisplayName(_nameController.text);
        }
        if (_passwordController.text.isNotEmpty) {
          await _user.updatePassword(_passwordController.text);
        }

        // Update custom fields in Firestore, now including the vehicles list
        await _firestore
            .collection('users')
            .doc(_user.uid)
            .set({
          'dcNumber': _dcNumberController.text,
          'probationOfficer': _probationOfficerController.text,
          'vehicles': _vehicles, // Save the entire list of vehicles
        }, SetOptions(merge: true));

        await _user.reload();
        _user = _auth.currentUser!;

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User info updated successfully!')),
        );
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.of(context).pop();
          }
        });
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating info: ${e.toString()}')),
        );
      }
    }
  }

  /// Shows a dialog to add a new vehicle or edit an existing one.
  void _showVehicleDialog({Map<String, dynamic>? vehicleToEdit}) {
    final vehicleController = TextEditingController(text: vehicleToEdit?['vehicle'] ?? '');
    final tagController = TextEditingController(text: vehicleToEdit?['tag'] ?? '');
    final isEditing = vehicleToEdit != null;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isEditing ? 'Edit Vehicle' : 'Add Vehicle'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: vehicleController,
                decoration: const InputDecoration(labelText: 'Vehicle (e.g., Toyota Camry)'),
                autofocus: true,
              ),
              TextField(
                controller: tagController,
                decoration: const InputDecoration(labelText: 'Tag #'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final vehicle = vehicleController.text;
                final tag = tagController.text;
                if (vehicle.isNotEmpty && tag.isNotEmpty) {
                  setState(() {
                    if (isEditing) {
                      // Find and update the vehicle in the list
                      final index = _vehicles.indexWhere((v) => v['tag'] == vehicleToEdit['tag']);
                      if (index != -1) {
                        _vehicles[index] = {'vehicle': vehicle, 'tag': tag};
                        // If the tag of the currently selected vehicle was changed, update the selection
                        if (_selectedVehicleTag == vehicleToEdit['tag']) {
                          _selectedVehicleTag = tag;
                        }
                      }
                    } else {
                      // Add a new vehicle to the list
                      _vehicles.add({'vehicle': vehicle, 'tag': tag});
                      // If it's the first vehicle being added, select it by default
                      if (_vehicles.length == 1) {
                        _selectedVehicleTag = tag;
                      }
                    }
                  });
                  Navigator.of(context).pop();
                }
              },
              child: Text(isEditing ? 'Save' : 'Add'),
            ),
          ],
        );
      },
    );
  }

  /// A dedicated widget to build the entire vehicle management section.
  Widget _buildVehiclesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        // Header for the vehicles section
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Vehicles', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Add'),
              onPressed: () => _showVehicleDialog(),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent, foregroundColor: Colors.white),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Dropdown menu to select from the list of added vehicles
        if (_vehicles.isNotEmpty)
          DropdownButtonFormField<String>(
            value: _selectedVehicleTag,
            hint: const Text('Select a vehicle'),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.grey[200],
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16.0),
            ),
            items: _vehicles.map((vehicle) {
              return DropdownMenuItem<String>(
                value: vehicle['tag'],
                child: Text('${vehicle['vehicle']} - ${vehicle['tag']}'),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedVehicleTag = value;
              });
            },
          )
        else
        // Placeholder message when no vehicles have been added
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[200]?.withAlpha(204),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Text('No vehicles added yet. Click "Add" to start.'),
            ),
          ),
        const SizedBox(height: 10),

        // A scrollable list of vehicles with edit and delete buttons
        ListView.builder(
          shrinkWrap: true, // Important inside a parent ListView
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _vehicles.length,
          itemBuilder: (context, index) {
            final vehicle = _vehicles[index];
            return Card(
              color: Colors.white.withAlpha(204),
              child: ListTile(
                title: Text(vehicle['vehicle']),
                subtitle: Text('Tag #: ${vehicle['tag']}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Edit button
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () => _showVehicleDialog(vehicleToEdit: vehicle),
                    ),
                    // Delete button
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        setState(() {
                          // If the deleted vehicle was the one selected in the dropdown, reset the selection
                          if (_selectedVehicleTag == _vehicles[index]['tag']) {
                            _selectedVehicleTag = null;
                          }
                          _vehicles.removeAt(index);
                          // If other vehicles still exist, select the first one by default
                          if (_vehicles.isNotEmpty) {
                            _selectedVehicleTag = _vehicles.first['tag'];
                          }
                        });
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit User')),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/road_lines.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                // Re-using a helper for cleaner code
                _buildTextFormField(_emailController, 'Email', validator: (val) => val != null && val.contains('@') ? null : 'Enter valid email'),
                const SizedBox(height: 16),
                _buildTextFormField(_nameController, 'Display Name'),
                const SizedBox(height: 16),
                _buildTextFormField(_dcNumberController, 'DCNumber'),
                const SizedBox(height: 16),
                _buildTextFormField(_probationOfficerController, 'Probation Officer'),
                const SizedBox(height: 16),
                _buildTextFormField(_passwordController, 'New Password (optional)', obscureText: true),

                // Renders the entire vehicle management UI
                _buildVehiclesSection(),

                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _updateUserInfo,
                  style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16)
                  ),
                  child: const Text('Update User Info'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// A helper method to reduce repetition in TextFormField decoration.
  Widget _buildTextFormField(TextEditingController controller, String label, {String? Function(String?)? validator, bool obscureText = false}) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      decoration: InputDecoration(
        label: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(4.0),
          ),
          child: Text(label),
        ),
        filled: true,
        fillColor: Colors.grey[200],
        border: const OutlineInputBorder(),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.grey[400]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
        ),
      ),
      validator: validator,
    );
  }
}
