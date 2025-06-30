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
  final List<Map<String, dynamic>> _vehicles = [];
  String? _selectedVehicleTag;
  final List<Map<String, dynamic>> _passengers = [];
  String? _selectedPassengerName;
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
          setState(() {
            _dcNumberController.text = data['dcNumber'] ?? '';
            _probationOfficerController.text = data['probationOfficer'] ?? '';

            if (data['vehicles'] != null && data['vehicles'] is List) {
              _vehicles.clear();
              for (var vehicleData in data['vehicles']) {
                if (vehicleData is Map<String, dynamic>) {
                  _vehicles.add(vehicleData);
                }
              }
            }
            if (_vehicles.isNotEmpty) {
              _selectedVehicleTag = _vehicles.first['tag'];
            }

            // --- (2) ADDED: Load passengers data ---
            if (data['passengers'] != null && data['passengers'] is List) {
              _passengers.clear();
              for (var passengerData in data['passengers']) {
                if (passengerData is Map<String, dynamic>) {
                  _passengers.add(passengerData);
                }
              }
            }
            if (_passengers.isNotEmpty) {
              _selectedPassengerName = _passengers.first['name'];
            }
          });
        }
      }
    } catch (e) {
      _logger.e("Error loading user custom data: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Failed to load user details.")));
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
  void _updateUserInfo() async {
    if (_formKey.currentState!.validate()) {
      try {
        if (_emailController.text != _user.email) {
          await _user.verifyBeforeUpdateEmail(_emailController.text);
        }
        if (_nameController.text != _user.displayName) {
          await _user.updateDisplayName(_nameController.text);
        }
        if (_passwordController.text.isNotEmpty) {
          await _user.updatePassword(_passwordController.text);
        }
        await _firestore.collection('users').doc(_user.uid).set({
          'dcNumber': _dcNumberController.text,
          'probationOfficer': _probationOfficerController.text,
          'vehicles': _vehicles,
          // --- (3) ADDED: Save the passengers list ---
          'passengers': _passengers,
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
                decoration:
                const InputDecoration(labelText: 'Vehicle (e.g., Toyota Camry)'),
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
                      final index = _vehicles.indexWhere((v) => v['tag'] == vehicleToEdit['tag']);
                      if (index != -1) {
                        _vehicles[index] = {'vehicle': vehicle, 'tag': tag};
                        if (_selectedVehicleTag == vehicleToEdit['tag']) {
                          _selectedVehicleTag = tag;
                        }
                      }
                    } else {
                      _vehicles.add({'vehicle': vehicle, 'tag': tag});
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
  void _showPassengerDialog({Map<String, dynamic>? passengerToEdit}) {
    final nameController = TextEditingController(text: passengerToEdit?['name'] ?? '');
    final isEditing = passengerToEdit != null;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isEditing ? 'Edit Passenger' : 'Add Passenger'),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(labelText: 'Passenger Name'),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final name = nameController.text;
                if (name.isNotEmpty) {
                  setState(() {
                    if (isEditing) {
                      final index = _passengers.indexWhere((p) => p['name'] == passengerToEdit['name']);
                      if (index != -1) {
                        _passengers[index] = {'name': name};
                        if (_selectedPassengerName == passengerToEdit['name']) {
                          _selectedPassengerName = name;
                        }
                      }
                    } else {
                      _passengers.add({'name': name});
                      if (_passengers.length == 1) {
                        _selectedPassengerName = name;
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
  Widget _buildVehiclesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Vehicles',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
            ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Add'),
              onPressed: () => _showVehicleDialog(),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white),
            ),
          ],
        ),
        const SizedBox(height: 10),
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
        ListView.builder(
          shrinkWrap: true,
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
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () => _showVehicleDialog(vehicleToEdit: vehicle),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        setState(() {
                          if (_selectedVehicleTag == _vehicles[index]['tag']) {
                            _selectedVehicleTag = null;
                          }
                          _vehicles.removeAt(index);
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
  Widget _buildPassengersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Passengers', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Add'),
              onPressed: () => _showPassengerDialog(),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal, foregroundColor: Colors.white),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (_passengers.isNotEmpty)
          DropdownButtonFormField<String>(
            value: _selectedPassengerName,
            hint: const Text('Select a passenger'),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.grey[200],
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16.0),
            ),
            items: _passengers.map((passenger) {
              return DropdownMenuItem<String>(
                value: passenger['name'],
                child: Text(passenger['name']),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedPassengerName = value;
              });
            },
          )
        else
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[200]?.withAlpha(204),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Text('No passengers added yet. Click "Add" to start.'),
            ),
          ),
        const SizedBox(height: 10),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _passengers.length,
          itemBuilder: (context, index) {
            final passenger = _passengers[index];
            return Card(
              color: Colors.white.withAlpha(204),
              child: ListTile(
                title: Text(passenger['name']),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () => _showPassengerDialog(passengerToEdit: passenger),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        setState(() {
                          if (_selectedPassengerName == _passengers[index]['name']) {
                            _selectedPassengerName = null;
                          }
                          _passengers.removeAt(index);
                          if (_passengers.isNotEmpty) {
                            _selectedPassengerName = _passengers.first['name'];
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
      appBar: AppBar(title: const Text('Edit User Profile')),
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
                _buildTextFormField(_emailController, 'Email',
                    validator: (val) =>
                    val != null && val.contains('@') ? null : 'Enter valid email'),
                const SizedBox(height: 10),
                _buildTextFormField(_nameController, 'Display Name'),
                const SizedBox(height: 10),
                _buildTextFormField(_dcNumberController, 'DCNumber'),
                const SizedBox(height: 10),
                _buildTextFormField(
                    _probationOfficerController, 'Probation Officer'),
                const SizedBox(height: 10),
                _buildTextFormField(_passwordController, 'New Password (optional)',
                    obscureText: true),

                const Divider(height: 15, color: Colors.white, thickness: 1),
                _buildVehiclesSection(),

                // --- (6) ADDED: The passengers section UI ---
                const Divider(height: 15, color: Colors.white, thickness: 1),
                _buildPassengersSection(),

                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: _updateUserInfo,
                  style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16)),
                  child: const Text('Update User Info'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  Widget _buildTextFormField(TextEditingController controller, String label,
      {String? Function(String?)? validator, bool obscureText = false}) {
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