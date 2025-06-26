// ignore_for_file: avoid_print

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geocoding/geocoding.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

final GlobalKey<FormBuilderState> _formKey = GlobalKey<FormBuilderState>();

class NewTripScreen extends StatefulWidget {
  const NewTripScreen({super.key});

  @override
  State<NewTripScreen> createState() => _NewTripScreenState();
}

class _NewTripScreenState extends State<NewTripScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  late TextEditingController _driverNameController;
  final TextEditingController _departedFromController = TextEditingController();
  String? _fileName;
  File? _file;

  // State for vehicle dropdown
  final List<Map<String, dynamic>> _vehicles = [];
  String? _selectedVehicle;
  bool _isLoadingVehicles = true;

  @override
  void initState() {
    super.initState();
    final User? currentUser = _auth.currentUser;
    _driverNameController =
        TextEditingController(text: currentUser?.displayName ?? '');
    _fetchUserVehicles();
  }

  /// Fetches the list of vehicles for the current user from Firestore
  Future<void> _fetchUserVehicles() async {
    final user = _auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoadingVehicles = false);
      return;
    }
    try {
      final docSnapshot = await _firestore.collection('users').doc(user.uid).get();
      if (docSnapshot.exists && docSnapshot.data() != null) {
        final data = docSnapshot.data() as Map<String, dynamic>;
        if (mounted) {
          final List<dynamic> vehicleData = data['vehicles'] ?? [];
          setState(() {
            _vehicles.clear();
            for (var vehicle in vehicleData) {
              if (vehicle is Map<String, dynamic>) {
                _vehicles.add(vehicle);
              }
            }
            if (_vehicles.isNotEmpty) {
              // Create a unique string for the value and display text.
              _selectedVehicle = '${_vehicles.first['vehicle']} - Tag: ${_vehicles.first['tag']}';
            }
            _isLoadingVehicles = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoadingVehicles = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching vehicles: $e')),
        );
        setState(() => _isLoadingVehicles = false);
      }
      print("Error fetching vehicles: $e");
    }
  }


  @override
  void dispose() {
    _driverNameController.dispose();
    _departedFromController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles();
    if (result != null) {
      setState(() {
        _fileName = result.files.single.name;
        _file = File(result.files.single.path!);
      });
    }
  }

  Future<String?> _uploadFile(String tripId) async {
    if (_file == null) return null;
    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('trip_proofs')
          .child('$tripId/${_fileName!}');
      await ref.putFile(_file!);
      return await ref.getDownloadURL();
    } catch (e) {
      print('Error uploading file: $e');
      return null;
    }
  }

  // Reusable function to get current location and geocode it
  Future<void> _getCurrentLocationAndGeocode(String fieldName) async {
    if (!mounted) return;
    // Show a loading indicator or message
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Fetching location...')),
    );

    try {
      bool serviceEnabled;
      LocationPermission permission;

      // Test if location services are enabled.
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!mounted) return;
      if (!serviceEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Location services are disabled. Please enable them.')),
        );
        return;
      }

      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permissions are denied.')),
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Location permissions are permanently denied, we cannot request permissions.')),
        );
        return;
      }

      // When we reach here, permissions are granted and we can
      // continue accessing the position of the device.
      final LocationSettings locationSettings;

      if (defaultTargetPlatform == TargetPlatform.android) {
        locationSettings = AndroidSettings(
          accuracy: LocationAccuracy.high,
          forceLocationManager: true,
        );
      } else if (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS) {
        locationSettings = AppleSettings(
          accuracy: LocationAccuracy.high,
          activityType: ActivityType.automotiveNavigation,
          pauseLocationUpdatesAutomatically: true,
        );
      } else {
        locationSettings = const LocationSettings(
          accuracy: LocationAccuracy.high,
        );
      }

      Position position = await Geolocator.getCurrentPosition(
          locationSettings: locationSettings);
      if (!mounted) return;
      List<Placemark> placemarks =
      await placemarkFromCoordinates(position.latitude, position.longitude);

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        // Construct a readable address. You might want to customize this further.
        String address =
            "${place.street}, ${place.locality}, ${place.administrativeArea} ${place.postalCode}"; // ${place.country}";

        // Update the specific FormBuilderTextField using its name
        _formKey.currentState?.fields[fieldName]?.didChange(address);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$fieldName set to: $address')),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not determine address from location.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error getting location: ${e.toString()}')),
      );
      print(e); // Log the error for debugging
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Log New Trip'),
        backgroundColor: const Color.fromARGB(255, 123, 194, 252),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Container(
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/images/road_lines.png'), // Make sure this path is correct
                  fit: BoxFit.cover,
                ),
              ),
              // Form
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: FormBuilder(
                  key: _formKey,
                  autovalidateMode: AutovalidateMode.disabled,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      // Driver Name
                      FormBuilderTextField(
                        name: 'driverName',
                        controller: _driverNameController, // Assign the controller
                        decoration: const InputDecoration(
                          labelText: 'Driver Name',
                          border: OutlineInputBorder(),
                          fillColor: Colors.white,
                          filled: true,
                        ),
                        validator: FormBuilderValidators.compose([
                          FormBuilderValidators.maxLength(100),
                        ]),
                      ),

                      // Vehicle Selection Dropdown
                      const SizedBox(height: 16),
                      if (_isLoadingVehicles)
                        const Center(child: CircularProgressIndicator())
                      else if (_vehicles.isEmpty)
                        Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(204),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('No vehicles found. Please add a vehicle in your profile.', textAlign: TextAlign.center, style: TextStyle(color: Colors.black))
                        )
                      else
                        FormBuilderDropdown<String>(
                          name: 'vehicle',
                          decoration: const InputDecoration(
                            labelText: 'Vehicle',
                            border: OutlineInputBorder(),
                            fillColor: Colors.white,
                            filled: true,
                          ),
                          initialValue: _selectedVehicle,
                          items: _vehicles.map((vehicle) {
                            final displayText = '${vehicle['vehicle']} - Tag: ${vehicle['tag']}';
                            return DropdownMenuItem(
                              value: displayText, // The value will be the combined string
                              child: Text(displayText),
                            );
                          }).toList(),
                          validator: FormBuilderValidators.compose([
                            FormBuilderValidators.required(),
                          ]),
                        ),


                      // Trip Date
                      const SizedBox(height: 16, width: 25),
                      FormBuilderDateTimePicker(
                        name: 'tripDate',
                        inputType: InputType.date,
                        format: DateFormat('yyyy-MM-dd'),
                        decoration: const InputDecoration(
                          labelText: 'Trip Date',
                          border: OutlineInputBorder(),
                          suffixIcon: Icon(Icons.calendar_today),
                          fillColor: Colors.white,
                          filled: true,
                        ),
                        initialValue: DateTime.now(),
                        validator: FormBuilderValidators.compose([
                          FormBuilderValidators.required(),
                        ]),
                      ),
                      // Trip Start Time
                      const SizedBox(height: 16, width: 25),
                      FormBuilderDateTimePicker(
                        name: 'tripStartTime',
                        inputType: InputType.time,
                        format: DateFormat('h:mm a'),
                        decoration: const InputDecoration(
                          labelText: 'Trip Start Time',
                          border: OutlineInputBorder(),
                          suffixIcon: Icon(Icons.access_time),
                          fillColor: Colors.white,
                          filled: true,
                        ),
                        initialValue: DateTime.now(),
                        validator: FormBuilderValidators.compose([
                          FormBuilderValidators.required(),
                        ]),
                      ),
                      // Trip Departed From
                      const SizedBox(height: 16),
                      FormBuilderTextField(
                        name: 'departedFrom',
                        controller: _departedFromController, // Assign the controller
                        decoration: InputDecoration(
                          labelText: 'Departed From',
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.gps_fixed), // Changed to GPS icon for clarity
                            tooltip: 'Get current address from GPS',
                            onPressed: () => _getCurrentLocationAndGeocode('departedFrom'),
                          ),
                          fillColor: Colors.white,
                          filled: true,
                        ),
                        validator: FormBuilderValidators.compose([
                          FormBuilderValidators.maxLength(150),
                        ]),
                      ),
                      // Trip Start Odometer
                      const SizedBox(height: 16, width: 25),
                      FormBuilderTextField(
                        name: 'startOdometer',
                        decoration: const InputDecoration(
                          labelText: 'Start Odometer',
                          border: OutlineInputBorder(),
                          fillColor: Colors.white,
                          filled: true,
                        ),
                        keyboardType: TextInputType.number,
                        validator: FormBuilderValidators.compose([
                          FormBuilderValidators.required(),
                          FormBuilderValidators.numeric(),
                          FormBuilderValidators.min(0),
                        ]),
                      ),
                      // Trip End Time
                      const SizedBox(height: 16, width: 25),
                      FormBuilderDateTimePicker(
                        name: 'tripEndTime',
                        inputType: InputType.time,
                        format: DateFormat('h:mm a'),
                        decoration: InputDecoration(
                          labelText: 'Trip End Time',
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.timer_outlined),
                            tooltip: 'Set To Current Time',
                            onPressed: () {
                              _formKey.currentState?.fields['tripEndTime']?.didChange(DateTime.now());
                            },
                          ),
                          fillColor: Colors.white,
                          filled: true,
                        ),
                        // initialValue: DateTime.now(),
                        validator: FormBuilderValidators.compose([
                          FormBuilderValidators.required(),
                        ]),
                      ),

                      // Trip Destination
                      const SizedBox(height: 16),
                      FormBuilderTextField(
                        name: 'destination', // This is the field we want to populate
                        decoration: InputDecoration(
                          labelText: 'Destination',
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.location_searching),
                            tooltip: 'Get Current Location',
                            onPressed: () => _getCurrentLocationAndGeocode('destination'),
                          ),
                          fillColor: Colors.white,
                          filled: true,
                        ),
                        validator: FormBuilderValidators.compose([
                          FormBuilderValidators.maxLength(150),
                        ]),
                      ),
                      // Trip End Odometer
                      const SizedBox(height: 16, width: 25),
                      FormBuilderTextField(
                        name: 'endOdometer',
                        decoration: const InputDecoration(
                          labelText: 'End Odometer',
                          border: OutlineInputBorder(),
                          fillColor: Colors.white,
                          filled: true,
                        ),
                        keyboardType: TextInputType.number,
                        validator: FormBuilderValidators.compose([
                          FormBuilderValidators.required(),
                          FormBuilderValidators.numeric(),
                          FormBuilderValidators.min(0),
                          // Custom validator for endOdometer > startOdometer can be added here
                          // or checked in the submit logic.
                        ]),
                      ),
                      // Trip Passenger(s)
                      const SizedBox(height: 16),
                      FormBuilderTextField(
                        name: 'passenger',
                        decoration: const InputDecoration(
                          labelText: 'Passenger(s) Name',
                          border: OutlineInputBorder(),
                          fillColor: Colors.white,
                          filled: true,
                        ),
                        maxLines: 1,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _pickFile,
                        icon: const Icon(Icons.attach_file),
                        label: Text(_fileName ?? 'Upload Trip Notes'),
                      ),
                      // Submit Button
                      const SizedBox(height: 24),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: const Color.fromARGB(255, 123, 194, 252),
                            padding: const EdgeInsets.symmetric(vertical: 16.0)),
                        onPressed: () {
                          if (_formKey.currentState?.saveAndValidate() ?? false) {
                            final formData = _formKey.currentState?.value;
                            final User? currentUser = _auth.currentUser;

                            if (formData != null && currentUser != null) {
                              _submitTripData(formData, currentUser);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        'User not logged in or form data is missing.')),
                              );
                            }
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content:
                                  Text('Please correct the errors in the form.')),
                            );
                          }
                        },
                        child: const Text('Submit Trip',
                            style: TextStyle(fontSize: 16, color: Colors.white)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submitTripData(
      Map<String, dynamic> formData, User currentUser) async {
    if (!mounted) return;
    // Show a loading indicator while saving
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Submitting trip...')),
    );

    try {
      Map<String, dynamic> tripData = Map<String, dynamic>.from(formData);
      tripData['userId'] = currentUser.uid;
      tripData['userEmail'] = currentUser.email; // Storing user's email

      // Ensure numeric fields are stored as numbers if they are strings
      if (tripData['startOdometer'] is String) {
        tripData['startOdometer'] = num.tryParse(tripData['startOdometer'].toString()) ?? 0;
      }
      if (tripData['endOdometer'] is String) {
        tripData['endOdometer'] = num.tryParse(tripData['endOdometer'].toString()) ?? 0;
      }

      final docRef = await _firestore.collection('trips').add(tripData);
      final downloadUrl = await _uploadFile(docRef.id);
      if (downloadUrl != null) {
        await docRef.update({'proofOfDeliveryUrl': downloadUrl});
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Trip for ${tripData['driverName'] ?? tripData['destination'] ?? 'N/A'} submitted successfully!')),
      );
      _formKey.currentState?.reset();
      setState(() {
        _fileName = null;
        _file = null;
        // After reset, re-fetch vehicles to reset the dropdown to the initial state
        _isLoadingVehicles = true;
      });
      _fetchUserVehicles();

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit trip: ${e.toString()}')),
      );
      print('Error saving trip to Firestore: $e'); // For debugging
    }
  }
}
