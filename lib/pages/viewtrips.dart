import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ViewTripsScreen extends StatelessWidget {
  const ViewTripsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('View Trips'),
      ),
      body: const ListPage(),
    );
  }
}

class ListPage extends StatefulWidget {
  const ListPage({super.key});

  @override
  State<ListPage> createState() => _ListPageState();
}

class _ListPageState extends State<ListPage> {
  late Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _tripsFuture;

  @override
  void initState() {
    super.initState();
    _tripsFuture = _getSortedTrips();
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _getSortedTrips() async {
    FirebaseFirestore firestore = FirebaseFirestore.instance;
    User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      print("User not logged in. Cannot fetch trips.");
      return [];
    }

    print("Fetching trips for user: ${currentUser.uid}");

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
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No trips found.'));
        }

        final trips = snapshot.data!;

        return ListView.builder(
          itemCount: trips.length,
          itemBuilder: (context, index) {
            final tripData = trips[index].data();
            final String driverName = tripData['driverName'] ?? 'No driver name';

            // Format trip date
            final Timestamp? tripDateRaw = tripData['tripDate'];
            final String tripDateFormatted = tripDateRaw != null
                ? DateFormat('yMMMd h:mm a').format(tripDateRaw.toDate())
                : 'No date';

            return ListTile(
              title: Text(driverName),
              subtitle: Text(tripDateFormatted),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DetailPage(trip: trips[index]),
                  ),
                );
              },
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
  _DetailPageState createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  @override
  Widget build(BuildContext context) {
    final trip = widget.trip.data() as Map<String, dynamic>;

    // Parse Firestore timestamps
    DateTime? tripDate;
    DateTime? tripStartTime;
    DateTime? tripEndTime;

    if (trip["tripDate"] != null) {
      tripDate = (trip["tripDate"] as Timestamp).toDate();
    }

    if (trip["tripStartTime"] != null) {
      tripStartTime = (trip["tripStartTime"] as Timestamp).toDate();
    }

    if (trip["tripEndTime"] != null) {
      tripEndTime = (trip["tripEndTime"] as Timestamp).toDate();
    }

    final String formattedDate =
    tripDate != null ? DateFormat('MMMM d, y').format(tripDate) : 'Unknown Date';
    final String formattedStartTime =
    tripStartTime != null ? DateFormat('h:mm a').format(tripStartTime) : 'Unknown Start Time';
    final String formattedEndTime =
    tripEndTime != null ? DateFormat('h:mm a').format(tripEndTime) : 'Unknown End Time';

    return Scaffold(
      appBar: AppBar(title: const Text('Trip Details')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Card(
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                title: const Text('Driver Name'),
                subtitle: Text(trip["driverName"] ?? 'N/A'),
              ),
              ListTile(
                title: const Text('Trip Date'),
                subtitle: Text(formattedDate),
              ),
              ListTile(
                title: const Text('Departed From'),
                subtitle: Text(trip["departedFrom"] ?? 'N/A'),
              ),
              ListTile(
                title: const Text('Start Time'),
                subtitle: Text(formattedStartTime),
              ),
              ListTile(
                title: const Text('Start Odometer'),
                subtitle: Text(trip["startOdometer"]?.toString() ?? 'N/A'),
              ),
              ListTile(
                title: const Text('Passenger Name'),
                subtitle: Text(trip["passenger"] ?? 'N/A'),
              ),
              ListTile(
                title: const Text('Destination'),
                subtitle: Text(trip["destination"] ?? 'N/A'),
              ),
              ListTile(
                title: const Text('End Time'),
                subtitle: Text(formattedEndTime),
              ),
              ListTile(
                title: const Text('End Odometer'),
                subtitle: Text(trip["endOdometer"]?.toString() ?? 'N/A'),
              ),


            ],
          ),
        ),
      ),
    );
  }
}
