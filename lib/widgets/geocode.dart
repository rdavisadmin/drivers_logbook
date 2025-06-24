import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class ReverseGeocodeWidget extends StatefulWidget {
  const ReverseGeocodeWidget({super.key});

  @override
  State<ReverseGeocodeWidget> createState() => _ReverseGeocodeWidgetState();
}

class _ReverseGeocodeWidgetState extends State<ReverseGeocodeWidget> {
  // IMPORTANT: Replace with your actual API key.
  // For production, use flutter_dotenv or other secure methods to store your API key.
  final String _apiKey = 'AIzaSyAtiAITIP8tgtPL20CCsl3GIG5z2sEzkYA';

  String? _currentAddress;
  Position? _currentPosition;
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _getAddressFromLatLng() async {
    if (_apiKey == 'YOUR_GOOGLE_MAPS_API_KEY') {
      setState(() {
        _errorMessage =
        'Please replace "YOUR_GOOGLE_MAPS_API_KEY" with your actual Google Maps API key.';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _currentAddress = null;
    });

    try {
      // Get current position
      _currentPosition = await _determinePosition();

      // Make API call
      final Uri uri = Uri.parse(
          'https://maps.googleapis.com/maps/api/geocode/json?latlng=${_currentPosition!.latitude},${_currentPosition!.longitude}&key=$_apiKey');

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final responseBody = json.decode(response.body);
        if (responseBody['status'] == 'OK' &&
            responseBody['results'] != null &&
            responseBody['results'].isNotEmpty) {
          setState(() {
            _currentAddress = responseBody['results'][0]['formatted_address'];
          });
        } else {
          setState(() {
            _errorMessage =
            'Could not get address: ${responseBody['status']} - ${responseBody['error_message'] ?? 'Unknown API error'}';
          });
        }
      } else {
        setState(() {
          _errorMessage =
          'Failed to connect to Geocoding API: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'An error occurred: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<Position> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permissions are denied.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception(
          'Location permissions are permanently denied, we cannot request permissions.');
    }
    return await Geolocator.getCurrentPosition();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          ElevatedButton(
            onPressed: _isLoading ? null : _getAddressFromLatLng,
            child: const Text('Get Current Address'),
          ),
          const SizedBox(height: 20),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_errorMessage != null)
            Text(
              'Error: $_errorMessage',
              style: const TextStyle(color: Colors.red, fontSize: 16),
              textAlign: TextAlign.center,
            )
          else if (_currentAddress != null)
              Column(
                children: [
                  Text(
                    'Current Address:',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _currentAddress!,
                    style: const TextStyle(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  if (_currentPosition != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      '(Lat: ${_currentPosition!.latitude.toStringAsFixed(4)}, Lng: ${_currentPosition!.longitude.toStringAsFixed(4)})',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ]
                ],
              )
            else
              const Text(
                'Tap the button to get your current address.',
                style: TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
        ],
      ),
    );
  }
}
