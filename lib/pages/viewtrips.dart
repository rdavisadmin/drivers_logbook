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

            final Timestamp? tripDateRaw = tripData['tripDate'];
            final String tripDateFormatted = tripDateRaw != null
                ? DateFormat('MMMM d, yyyy').format(tripDateRaw.toDate())
                : 'No date';

            return Card(
              color: Colors.black.withAlpha(150),
              elevation: 4,
              child: ListTile(
                title: Text(destination, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: Text('$driverName - $tripDateFormatted', style: const TextStyle(color: Colors.white70)),
                trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DetailPage(trip: trips[index]),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}

class DetailPage extends StatefulWidget {
  final DocumentSnapshot trip;

  const DetailPage({super.key, required this.trip});

  @override
  DetailPageState createState() => DetailPageState();
}

class DetailPageState extends State<DetailPage> {

  Widget _buildDetailRow(String title, String? value) {
    return ListTile(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
      subtitle: Text(value ?? 'N/A', style: const TextStyle(color: Colors.white70)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final trip = widget.trip.data() as Map<String, dynamic>;

    DateTime? tripDate = (trip["tripDate"] as Timestamp?)?.toDate();
    DateTime? tripStartTime = (trip["tripStartTime"] as Timestamp?)?.toDate();
    DateTime? tripEndTime = (trip["tripEndTime"] as Timestamp?)?.toDate();

    final String formattedDate = tripDate != null ? DateFormat('MMMM d, y').format(tripDate) : 'N/A';
    final String formattedStartTime = tripStartTime != null ? DateFormat('h:mm a').format(tripStartTime) : 'N/A';
    final String formattedEndTime = tripEndTime != null ? DateFormat('h:mm a').format(tripEndTime) : 'N/A';

    return Scaffold(
      appBar: AppBar(
        title: Text(trip["destination"] ?? 'Trip Details'),
        backgroundColor: const Color.fromARGB(255, 123, 194, 252),
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
                  _buildDetailRow('Driver Name', trip["driverName"]),
                  _buildDetailRow('Trip Date', formattedDate),
                  _buildDetailRow('Vehicle', trip["vehicle"]),
                  const Divider(color: Colors.white30),
                  _buildDetailRow('Departed From', trip["departedFrom"]),
                  _buildDetailRow('Start Time', formattedStartTime),
                  _buildDetailRow('Start Odometer', trip["startOdometer"]?.toString()),
                  const Divider(color: Colors.white30),
                  _buildDetailRow('Destination', trip["destination"]),
                  _buildDetailRow('End Time', formattedEndTime),
                  _buildDetailRow('End Odometer', trip["endOdometer"]?.toString()),
                  const Divider(color: Colors.white30),
                  _buildDetailRow('Passenger(s) Name', trip["passenger"]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}