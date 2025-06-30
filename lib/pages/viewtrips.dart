import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logger/logger.dart';

class ViewTripsScreen extends StatelessWidget {
  const ViewTripsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('View Trips'),
        backgroundColor: const Color.fromARGB(255, 123, 194, 252),
      ),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/road_lines.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: const ListPage(),
      ),
    );
  }
}

// --- LIST PAGE
class ListPage extends StatefulWidget {
  const ListPage({super.key});

  @override
  State<ListPage> createState() => ListPageState();
}

class ListPageState extends State<ListPage> {
  late Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _tripsFuture;
  final _logger = Logger();

  @override
  void initState() {
    super.initState();
    _tripsFuture = _getSortedTrips();
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _getSortedTrips() async {
    FirebaseFirestore firestore = FirebaseFirestore.instance;
    User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      _logger.w("User not logged in. Cannot fetch trips.");
      return [];
    }

    _logger.i("Fetching trips for user: ${currentUser.uid}");

    QuerySnapshot<Map<String, dynamic>> tripsSnapshot = await firestore
        .collection('trips')
        .where('userId', isEqualTo: currentUser.uid)
        .orderBy('tripDate', descending: true)
        .get();

    return tripsSnapshot.docs;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
      future: _tripsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.white)));
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No trips found.', style: TextStyle(color: Colors.white, fontSize: 18)));
        }

        final trips = snapshot.data!;

        return ListView.separated(
          itemCount: trips.length,
          separatorBuilder: (context, index) => const Divider(color: Colors.transparent, height: 8),
          padding: const EdgeInsets.all(8),
          itemBuilder: (context, index) {
            final tripData = trips[index].data();
            final String driverName = tripData['driverName'] ?? 'Unnamed Trip';
            final String destination = tripData['destination'] ?? 'No destination';
            final String departedFrom = tripData['departedFrom'] ?? 'No departure';

            final Timestamp? tripDateRaw = tripData['tripDate'];
            final String tripDateFormatted = tripDateRaw != null
                ? DateFormat('MMMM d, yyyy HH:mm').format(tripDateRaw.toDate())
                : 'No date';

            return Card(
              color: Colors.black.withAlpha(150),
              elevation: 4,
              child: ListTile(
                isThreeLine: true,
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                    'From: $departedFrom',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    Text(
                      'To: $destination',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                    )
                  ],
                ),
                subtitle: Text('$driverName - $tripDateFormatted', style: const TextStyle(color: Colors.white70)),
                trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DetailPage(trip: trips[index]),
                    ),
                  ).then((_) {
                    // Refresh the list after returning from the detail page
                    setState(() {
                      _tripsFuture = _getSortedTrips();
                    });
                  });
                },
              ),
            );
          },
        );
      },
    );
  }
}


// --- DETAIL PAGE (MODIFIED) ---
class DetailPage extends StatefulWidget {
  final DocumentSnapshot trip;

  const DetailPage({super.key, required this.trip});

  @override
  DetailPageState createState() => DetailPageState();
}

class DetailPageState extends State<DetailPage> {
  // Use a local variable to hold the trip data, so it can be refreshed.
  late Map<String, dynamic> _tripData;

  @override
  void initState() {
    super.initState();
    _tripData = widget.trip.data() as Map<String, dynamic>;
  }

  // Method to refresh trip data from Firestore
  Future<void> _refreshTripData() async {
    DocumentSnapshot updatedTrip = await widget.trip.reference.get();
    setState(() {
      _tripData = updatedTrip.data() as Map<String, dynamic>;
    });
  }

  Widget _buildDetailRow(String title, String? value) {
    return ListTile(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
      subtitle: Text(value ?? 'N/A', style: const TextStyle(color: Colors.white70)),
    );
  }

  @override
  Widget build(BuildContext context) {
    DateTime? tripDate = (_tripData["tripDate"] as Timestamp?)?.toDate();
    DateTime? tripStartTime = (_tripData["tripStartTime"] as Timestamp?)?.toDate();
    DateTime? tripEndTime = (_tripData["tripEndTime"] as Timestamp?)?.toDate();

    final String formattedDate = tripDate != null ? DateFormat('MMMM d, y').format(tripDate) : 'N/A';
    final String formattedStartTime = tripStartTime != null ? DateFormat('h:mm a').format(tripStartTime) : 'N/A';
    final String formattedEndTime = tripEndTime != null ? DateFormat('h:mm a').format(tripEndTime) : 'N/A';

    return Scaffold(
      appBar: AppBar(
        title: Text(_tripData["destination"] ?? 'Trip Details'),
        backgroundColor: const Color.fromARGB(255, 123, 194, 252),
        actions: [
          // ADDED: Edit button
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              // Navigate to the new EditTripScreen
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditTripScreen(trip: widget.trip),
                ),
              ).then((value) {
                // When we return from the Edit screen, refresh the data
                if (value == true) {
                  _refreshTripData();
                }
              });
            },
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/road_lines.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            Card(
              color: Colors.black.withAlpha(200),
              child: Column(
                children: [
                  _buildDetailRow('Driver Name', _tripData["driverName"]),
                  _buildDetailRow('Trip Date', formattedDate),
                  _buildDetailRow('Vehicle', _tripData["vehicle"]),
                  const Divider(color: Colors.white30),
                  _buildDetailRow('Departed From', _tripData["departedFrom"]),
                  _buildDetailRow('Start Time', formattedStartTime),
                  _buildDetailRow('Start Odometer', _tripData["startOdometer"]?.toString()),
                  const Divider(color: Colors.white30),
                  _buildDetailRow('Destination', _tripData["destination"]),
                  _buildDetailRow('End Time', formattedEndTime),
                  _buildDetailRow('End Odometer', _tripData["endOdometer"]?.toString()),
                  const Divider(color: Colors.white30),
                  _buildDetailRow('Passenger(s) Name', _tripData["passenger"]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- EDIT TRIP SCREEN (NEW WIDGET) ---
class EditTripScreen extends StatefulWidget {
  final DocumentSnapshot trip;

  const EditTripScreen({super.key, required this.trip});

  @override
  State<EditTripScreen> createState() => _EditTripScreenState();
}

class _EditTripScreenState extends State<EditTripScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _driverNameController;
  late TextEditingController _vehicleController;
  late TextEditingController _departedFromController;
  late TextEditingController _destinationController;
  late TextEditingController _passengerController;
  late TextEditingController _startOdometerController;
  late TextEditingController _endOdometerController;

  late DateTime _tripDate;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;

  @override
  void initState() {
    super.initState();
    final data = widget.trip.data() as Map<String, dynamic>;

    // Initialize Controllers
    _driverNameController = TextEditingController(text: data['driverName']);
    _vehicleController = TextEditingController(text: data['vehicle']);
    _departedFromController = TextEditingController(text: data['departedFrom']);
    _destinationController = TextEditingController(text: data['destination']);
    _passengerController = TextEditingController(text: data['passenger']);
    _startOdometerController = TextEditingController(text: data['startOdometer']?.toString());
    _endOdometerController = TextEditingController(text: data['endOdometer']?.toString());

    // Initialize Date and Time
    _tripDate = (data['tripDate'] as Timestamp?)?.toDate() ?? DateTime.now();
    _startTime = TimeOfDay.fromDateTime((data['tripStartTime'] as Timestamp?)?.toDate() ?? DateTime.now());
    _endTime = TimeOfDay.fromDateTime((data['tripEndTime'] as Timestamp?)?.toDate() ?? DateTime.now());
  }

  @override
  void dispose() {
    // Dispose controllers
    _driverNameController.dispose();
    _vehicleController.dispose();
    _departedFromController.dispose();
    _destinationController.dispose();
    _passengerController.dispose();
    _startOdometerController.dispose();
    _endOdometerController.dispose();
    super.dispose();
  }

  Future<void> _updateTrip() async {
    if (_formKey.currentState!.validate()) {
      try {
        // Combine Date and Time for Firestore Timestamps
        final fullStartTime = DateTime(_tripDate.year, _tripDate.month, _tripDate.day, _startTime.hour, _startTime.minute);
        final fullEndTime = DateTime(_tripDate.year, _tripDate.month, _tripDate.day, _endTime.hour, _endTime.minute);

        await widget.trip.reference.update({
          'driverName': _driverNameController.text,
          'vehicle': _vehicleController.text,
          'departedFrom': _departedFromController.text,
          'destination': _destinationController.text,
          'passenger': _passengerController.text,
          'startOdometer': int.tryParse(_startOdometerController.text) ?? 0,
          'endOdometer': int.tryParse(_endOdometerController.text) ?? 0,
          'tripDate': Timestamp.fromDate(_tripDate),
          'tripStartTime': Timestamp.fromDate(fullStartTime),
          'tripEndTime': Timestamp.fromDate(fullEndTime),
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Trip updated successfully!')),
        );

        // Pop the screen and return true to indicate success
        if (mounted) Navigator.pop(context, true);

      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update trip: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Trip'),
        backgroundColor: const Color.fromARGB(255, 123, 194, 252),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _updateTrip,
          )
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/road_lines.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              TextFormField(controller: _driverNameController, decoration: const InputDecoration(labelText: 'Driver Name', labelStyle: TextStyle(color: Colors.white)), style: const TextStyle(color: Colors.white)),
              TextFormField(controller: _vehicleController, decoration: const InputDecoration(labelText: 'Vehicle', labelStyle: TextStyle(color: Colors.white)), style: const TextStyle(color: Colors.white)),
              TextFormField(controller: _departedFromController, decoration: const InputDecoration(labelText: 'Departed From', labelStyle: TextStyle(color: Colors.white)), style: const TextStyle(color: Colors.white)),
              TextFormField(controller: _destinationController, decoration: const InputDecoration(labelText: 'Destination', labelStyle: TextStyle(color: Colors.white)), style: const TextStyle(color: Colors.white)),
              TextFormField(controller: _startOdometerController, decoration: const InputDecoration(labelText: 'Start Odometer', labelStyle: TextStyle(color: Colors.white)), style: const TextStyle(color: Colors.white), keyboardType: TextInputType.number),
              TextFormField(controller: _endOdometerController, decoration: const InputDecoration(labelText: 'End Odometer', labelStyle: TextStyle(color: Colors.white)), style: const TextStyle(color: Colors.white), keyboardType: TextInputType.number),
              TextFormField(controller: _passengerController, decoration: const InputDecoration(labelText: 'Passenger(s)', labelStyle: TextStyle(color: Colors.white)), style: const TextStyle(color: Colors.white)),
              const SizedBox(height: 20),
              ListTile(
                title: const Text('Trip Date', style: TextStyle(color: Colors.white)),
                subtitle: Text(DateFormat.yMMMMd().format(_tripDate), style: const TextStyle(color: Colors.white70)),
                trailing: const Icon(Icons.calendar_today, color: Colors.white),
                onTap: () async {
                  final pickedDate = await showDatePicker(
                    context: context,
                    initialDate: _tripDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2101),
                  );
                  if (pickedDate != null) setState(() => _tripDate = pickedDate);
                },
              ),
              ListTile(
                title: const Text('Start Time', style: TextStyle(color: Colors.white)),
                subtitle: Text(_startTime.format(context), style: const TextStyle(color: Colors.white70)),
                trailing: const Icon(Icons.access_time, color: Colors.white),
                onTap: () async {
                  final pickedTime = await showTimePicker(
                    context: context,
                    initialTime: _startTime,
                  );
                  if (pickedTime != null) setState(() => _startTime = pickedTime);
                },
              ),
              ListTile(
                title: const Text('End Time', style: TextStyle(color: Colors.white)),
                subtitle: Text(_endTime.format(context), style: const TextStyle(color: Colors.white70)),
                trailing: const Icon(Icons.access_time_filled, color: Colors.white),
                onTap: () async {
                  final pickedTime = await showTimePicker(
                    context: context,
                    initialTime: _endTime,
                  );
                  if (pickedTime != null) setState(() => _endTime = pickedTime);
                },
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _updateTrip,
                child: const Text('Save Changes'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}