import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:drivers_logbook/pages/newtrip.dart';
import 'package:drivers_logbook/pages/forms.dart';
//import 'package:drivers_logbook/pages/tripreports.dart';
import 'package:drivers_logbook/pages/viewtrips.dart';
import 'package:drivers_logbook/pages/edituser.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:drivers_logbook/pages/reportmonthly.dart';

final userData = FirebaseAuth.instance.currentUser;

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final String formattedDate =
    DateFormat('EEEE, MMMM d, yyyy').format(DateTime.now());
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: const Color.fromARGB(255, 123, 194, 252),
        title: Text(
          formattedDate,
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Image.asset(
            'assets/images/road_lines.png',
            fit: BoxFit.cover,
          ),
          Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'Driving  Log',
                      style: TextStyle(
                        fontSize: 60.0,
                        fontWeight: FontWeight.bold,
                        color: const Color.fromARGB(
                            255, 255, 251, 0), // Adjust text color for visibility
                        shadows: [
                          Shadow(
                            blurRadius: 10.0,
                            color: Colors.black,
                            offset: Offset(5.0, 5.0),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(
                      width: 200.0,
                      height: 50.0), // Spacing between title and buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Column(
                        children: [
                          ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => const NewTripScreen()),
                              );
                              // Button new trip action
                            },
                            child: Text('New Trip'),
                          ),
                          SizedBox(height: 20.0), // Spacing between buttons
                          ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => const ViewTripsScreen()),
                              );
                              // Button view trips action
                            },
                            child: Text('View Trips'),
                          ),
                          SizedBox(height: 20.0), // Spacing between buttons
                          ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) =>
                                    const ReportMonthly()),
                              );
                              // Button view trips action
                            },
                            child: Text('Trip Reports'),
                          ),
                        ],
                      ),
                      Column(
                        children: [

                          SizedBox(height: 20.0), // Spacing between buttons
                          ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => const ViewFormsScreen()),
                              );
                              // Button view reports action
                            },
                            child: Text('View Forms'),
                          ),
                          SizedBox(height: 20.0), // Spacing between buttons
                          ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => EditUser(
                                    userData: {
                                      'uid': userData?.uid,
                                      'email': userData?.email,
                                      'displayName': userData?.displayName,
                                      // Add other fields as needed
                                    },
                                  ),
                                ),
                              );
                              // Button Edit User Info action
                            },
                            child: Text('Edit User Info'),
                          ),
                          SizedBox(height: 20.0), // Spacing between buttons
                          ElevatedButton(
                            onPressed: () {
                              SystemNavigator.pop(); // Close the app
                              // Button close app action
                            },
                            child: Text('Close App'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
