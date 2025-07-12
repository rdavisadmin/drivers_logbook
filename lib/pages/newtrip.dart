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
  final TextEditingController _manualPassengerController =
  TextEditingController();
  String? _fileName;
  File? _file;
  final List<Map<String, dynamic>> _vehicles = [];
  String? _selectedVehicle;
  bool _isLoadingVehicles = true;
  final List<Map<String, dynamic>> _passengers = [];
  bool _isLoadingPassengers = true;
  final List<String> _selectedPassengers = [];

  @override
  void initState() {
    super.initState();
    final User? currentUser = _auth.currentUser;
    _driverNameController =
        TextEditingController(text: currentUser?.displayName ?? '');
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final user = _auth.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() {
          _isLoadingVehicles = false;
          _isLoadingPassengers = false;
        });
      }
      return;
    }
    try {
      final docSnapshot =
      await _firestore.collection('users').doc(user.uid).get();
      if (docSnapshot.exists && docSnapshot.data() != null) {
        final data = docSnapshot.data() as Map<String, dynamic>;

        final List<dynamic> vehicleData = data['vehicles'] ?? [];
        _vehicles.clear();
        for (var vehicle in vehicleData) {
          if (vehicle is Map<String, dynamic>) {
            _vehicles.add(vehicle);
          }
        }
        if (_vehicles.isNotEmpty) {
          _selectedVehicle =
          '${_vehicles.first['vehicle']} - Tag: ${_vehicles.first['tag']}';
        }
        final List<dynamic> passengerData = data['passengers'] ?? [];
        _passengers.clear();
        for (var passenger in passengerData) {
          if (passenger is Map<String, dynamic>) {
            _passengers.add(passenger);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching user data: $e')),
        );
      }
      print("Error fetching user data: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingVehicles = false;
          _isLoadingPassengers = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _driverNameController.dispose();
    _departedFromController.dispose();
    _manualPassengerController.dispose();
    super.dispose();
  }

  void _showPassengerSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title:
          const Text('Select a Passenger', style: TextStyle(fontSize: 50)),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _passengers.length,
              itemBuilder: (context, index) {
                final passengerName = _passengers[index]['name'] as String;
                return ListTile(
                  title:
                  Text(passengerName, style: const TextStyle(fontSize: 50)),
                  onTap: () {
                    setState(() {
                      if (!_selectedPassengers.contains(passengerName)) {
                        _selectedPassengers.add(passengerName);
                      }
                    });
                    Navigator.of(context).pop();
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close', style: TextStyle(fontSize: 25)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPassengerInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Passenger(s)',
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 25),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(
            children: [
              Wrap(
                spacing: 8.0,
                runSpacing: 4.0,
                children: _selectedPassengers.map((passenger) {
                  return Chip(
                    label: Text(passenger, style: const TextStyle(fontSize: 25)),
                    onDeleted: () {
                      setState(() {
                        _selectedPassengers.remove(passenger);
                      });
                    },
                  );
                }).toList(),
              ),
              if (_selectedPassengers.isNotEmpty) const Divider(),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _manualPassengerController,
                      style: const TextStyle(fontSize: 25),
                      decoration: const InputDecoration(
                        hintText: 'Type a new name...',
                        hintStyle: TextStyle(fontSize: 25),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle, color: Colors.green),
                    tooltip: 'Add typed name',
                    onPressed: () {
                      final name = _manualPassengerController.text;
                      if (name.isNotEmpty &&
                          !_selectedPassengers.contains(name)) {
                        setState(() {
                          _selectedPassengers.add(name);
                          _manualPassengerController.clear();
                        });
                      }
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.person_search, color: Colors.blue),
                    tooltip: 'Select from list',
                    onPressed: _showPassengerSelectionDialog,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
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

  Future<void> _getCurrentLocationAndGeocode(String fieldName) async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Fetching location...')),
    );
    try {
      bool serviceEnabled;
      LocationPermission permission;
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!mounted) return;
      if (!serviceEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Location services are disabled. Please enable them.')),
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
      final LocationSettings locationSettings;
      if (defaultTargetPlatform == TargetPlatform.android) {
        locationSettings = AndroidSettings(
            accuracy: LocationAccuracy.high, forceLocationManager: true);
      } else if (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS) {
        locationSettings = AppleSettings(
          accuracy: LocationAccuracy.high,
          activityType: ActivityType.automotiveNavigation,
          pauseLocationUpdatesAutomatically: true,
        );
      } else {
        locationSettings =
        const LocationSettings(accuracy: LocationAccuracy.high);
      }
      Position position = await Geolocator.getCurrentPosition(
          locationSettings: locationSettings);
      if (!mounted) return;
      List<Placemark> placemarks =
      await placemarkFromCoordinates(position.latitude, position.longitude);
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        String address =
            "${place.street}, ${place.locality}, ${place.administrativeArea} ${place.postalCode}";
        _formKey.currentState?.fields[fieldName]?.didChange(address);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$fieldName set to: $address')),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Could not determine address from location.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error getting location: ${e.toString()}')),
      );
      print(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: const TextScaler.linear(1.0),
      ),
      child: DefaultTextStyle(
        style: const TextStyle(fontSize: 25),
        child: Scaffold(
          appBar: AppBar(
            centerTitle: true,
            title: const Text('Log New Trip', style: TextStyle(fontSize: 25, color: Colors.white)),
            backgroundColor: const Color.fromARGB(255, 123, 194, 252),
          ),
          body: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Container(
                  decoration: const BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage('assets/images/road_lines.png'),
                      fit: BoxFit.cover,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: FormBuilder(
                      key: _formKey,
                      autovalidateMode: AutovalidateMode.disabled,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          FormBuilderTextField(
                            name: 'driverName',
                            controller: _driverNameController,
                            style: const TextStyle(fontSize: 25),
                            decoration: const InputDecoration(
                                labelText: 'Driver Name',
                                labelStyle: TextStyle(fontSize: 25),
                                border: OutlineInputBorder(),
                                fillColor: Colors.white,
                                filled: true),
                            validator: FormBuilderValidators.compose(
                                [FormBuilderValidators.maxLength(100)]),
                          ),
                          const SizedBox(height: 16),
                          if (_isLoadingVehicles)
                            const Center(child: CircularProgressIndicator())
                          else if (_vehicles.isEmpty)
                            Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                    color: Colors.white.withAlpha(204),
                                    borderRadius: BorderRadius.circular(4)),
                                child: const Text(
                                    'No vehicles found. Please add a vehicle in your profile.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        color: Colors.black, fontSize: 25)))
                          else
                            FormBuilderDropdown<String>(
                              name: 'vehicle',
                              style: const TextStyle(fontSize: 25),
                              decoration: const InputDecoration(
                                  labelText: 'Vehicle',
                                  labelStyle: TextStyle(fontSize: 25),
                                  border: OutlineInputBorder(),
                                  fillColor: Colors.white,
                                  filled: true),
                              initialValue: _selectedVehicle,
                              items: _vehicles.map((vehicle) {
                                final displayText =
                                    '${vehicle['vehicle']} - Tag: ${vehicle['tag']}';
                                return DropdownMenuItem(
                                    value: displayText,
                                    child: Text(displayText,
                                        style: const TextStyle(fontSize: 25)));
                              }).toList(),
                              validator: FormBuilderValidators.compose(
                                  [FormBuilderValidators.required()]),
                            ),
                          const SizedBox(height: 16),
                          FormBuilderDateTimePicker(
                            name: 'tripDate',
                            style: const TextStyle(fontSize: 25),
                            inputType: InputType.date,
                            format: DateFormat('yyyy-MM-dd'),
                            decoration: const InputDecoration(
                                labelText: 'Trip Date',
                                labelStyle: TextStyle(fontSize: 25),
                                border: OutlineInputBorder(),
                                suffixIcon: Icon(Icons.calendar_today),
                                fillColor: Colors.white,
                                filled: true),
                            initialValue: DateTime.now(),
                            validator: FormBuilderValidators.compose(
                                [FormBuilderValidators.required()]),
                          ),
                          const SizedBox(height: 16),
                          FormBuilderDateTimePicker(
                            name: 'tripStartTime',
                            style: const TextStyle(fontSize: 25),
                            inputType: InputType.time,
                            format: DateFormat('h:mm a'),
                            decoration: const InputDecoration(
                                labelText: 'Trip Start Time',
                                labelStyle: TextStyle(fontSize: 25),
                                border: OutlineInputBorder(),
                                suffixIcon: Icon(Icons.access_time),
                                fillColor: Colors.white,
                                filled: true),
                            initialValue: DateTime.now(),
                            validator: FormBuilderValidators.compose(
                                [FormBuilderValidators.required()]),
                          ),
                          const SizedBox(height: 16),
                          FormBuilderTextField(
                            name: 'departedFrom',
                            style: const TextStyle(fontSize: 25),
                            controller: _departedFromController,
                            decoration: InputDecoration(
                              labelText: 'Departed From',
                              labelStyle: const TextStyle(fontSize: 25),
                              border: const OutlineInputBorder(),
                              suffixIcon: IconButton(
                                  icon: const Icon(Icons.gps_fixed),
                                  tooltip: 'Get current address from GPS',
                                  onPressed: () => _getCurrentLocationAndGeocode(
                                      'departedFrom')),
                              fillColor: Colors.white,
                              filled: true,
                            ),
                            validator: FormBuilderValidators.compose(
                                [FormBuilderValidators.maxLength(150)]),
                          ),
                          const SizedBox(height: 16),
                          FormBuilderTextField(
                            name: 'startOdometer',
                            style: const TextStyle(fontSize: 25),
                            decoration: const InputDecoration(
                                labelText: 'Start Odometer',
                                labelStyle: TextStyle(fontSize: 25),
                                border: OutlineInputBorder(),
                                fillColor: Colors.white,
                                filled: true),
                            keyboardType: TextInputType.number,
                            validator: FormBuilderValidators.compose([
                              FormBuilderValidators.required(),
                              FormBuilderValidators.numeric(),
                              FormBuilderValidators.min(0),
                            ]),
                          ),
                          const SizedBox(height: 16),
                          FormBuilderDateTimePicker(
                            name: 'tripEndTime',
                            style: const TextStyle(fontSize: 25),
                            inputType: InputType.time,
                            format: DateFormat('h:mm a'),
                            decoration: InputDecoration(
                              labelText: 'Trip End Time',
                              labelStyle: const TextStyle(fontSize: 25),
                              border: const OutlineInputBorder(),
                              suffixIcon: IconButton(
                                  icon: const Icon(Icons.timer_outlined),
                                  tooltip: 'Set To Current Time',
                                  onPressed: () {
                                    _formKey.currentState?.fields['tripEndTime']
                                        ?.didChange(DateTime.now());
                                  }),
                              fillColor: Colors.white,
                              filled: true,
                            ),
                            validator: FormBuilderValidators.compose(
                                [FormBuilderValidators.required()]),
                          ),
                          const SizedBox(height: 16),
                          FormBuilderTextField(
                            name: 'destination',
                            style: const TextStyle(fontSize: 25),
                            decoration: InputDecoration(
                              labelText: 'Destination',
                              labelStyle: const TextStyle(fontSize: 25),
                              border: const OutlineInputBorder(),
                              suffixIcon: IconButton(
                                  icon: const Icon(Icons.location_searching),
                                  tooltip: 'Get Current Location',
                                  onPressed: () =>
                                      _getCurrentLocationAndGeocode('destination')),
                              fillColor: Colors.white,
                              filled: true,
                            ),
                            validator: FormBuilderValidators.compose(
                                [FormBuilderValidators.maxLength(150)]),
                          ),
                          const SizedBox(height: 16),
                          FormBuilderTextField(
                            name: 'endOdometer',
                            style: const TextStyle(fontSize: 25),
                            decoration: const InputDecoration(
                                labelText: 'End Odometer',
                                labelStyle: TextStyle(fontSize: 25),
                                border: OutlineInputBorder(),
                                fillColor: Colors.white,
                                filled: true),
                            keyboardType: TextInputType.number,
                            validator: FormBuilderValidators.compose([
                              FormBuilderValidators.required(),
                              FormBuilderValidators.numeric(),
                              FormBuilderValidators.min(0),
                            ]),
                          ),
                          const SizedBox(height: 16),
                          _buildPassengerInput(),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _pickFile,
                            icon: const Icon(Icons.attach_file),
                            label: Text(_fileName ?? 'Upload Trip Notes',
                                style: const TextStyle(fontSize: 25)),
                          ),
                          const SizedBox(height: 50),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                                backgroundColor:
                                const Color.fromARGB(255, 123, 194, 252),
                                padding:
                                const EdgeInsets.symmetric(vertical: 16.0)),
                            onPressed: () {
                              if (_formKey.currentState?.saveAndValidate() ??
                                  false) {
                                final formData = _formKey.currentState?.value;
                                final User? currentUser = _auth.currentUser;

                                if (formData != null && currentUser != null) {
                                  _submitTripData(formData, currentUser);
                                }
                              }
                            },
                            child: const Text('Submit Trip',
                                style:
                                TextStyle(fontSize: 25, color: Colors.white)),
                          ),
                        ],
                      ),
                    ),
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Submitting trip...')),
    );

    try {
      Map<String, dynamic> tripData = Map<String, dynamic>.from(formData);
      tripData['userId'] = currentUser.uid;
      tripData['userEmail'] = currentUser.email;
      tripData['passenger'] = _selectedPassengers.join(', ');

      if (tripData['startOdometer'] is String) {
        tripData['startOdometer'] =
            num.tryParse(tripData['startOdometer'].toString()) ?? 0;
      }
      if (tripData['endOdometer'] is String) {
        tripData['endOdometer'] =
            num.tryParse(tripData['endOdometer'].toString()) ?? 0;
      }

      final docRef = await _firestore.collection('trips').add(tripData);
      final downloadUrl = await _uploadFile(docRef.id);
      if (downloadUrl != null) {
        await docRef.update({'proofOfDeliveryUrl': downloadUrl});
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Trip for ${tripData['driverName'] ?? 'N/A'} submitted successfully!')),
      );

      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit trip: ${e.toString()}')),
      );
      print('Error saving trip to Firestore: $e');
    }
  }
}