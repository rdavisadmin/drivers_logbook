import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:drivers_logbook/pages/forms.dart';
import 'package:drivers_logbook/pages/newtriptablet.dart';
import 'package:drivers_logbook/pages/viewtrips.dart';
import 'package:drivers_logbook/pages/edituser.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:drivers_logbook/pages/reportmonthly.dart';
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final userName = user?.displayName ?? 'Welcome';
    final String formattedDate =
    DateFormat('EEEE, MMMM d, yyyy').format(DateTime.now());
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: const Color.fromARGB(255, 0, 72, 255),
        title: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              userName,
              style: const TextStyle(
                fontSize: 25.0,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              formattedDate,
              style: const TextStyle(
                fontSize: 20.0,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: <Widget>[

          Image.asset(
            'assets/animated/jeepinside.gif',
            height: 180, // You can adjust the height of the GIF container
            width: double.infinity, // Make it span the full width
            fit: BoxFit.cover,
          ),
          Expanded(
            child: Stack(
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
                        const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text(
                            'Driving Log',
                            style: TextStyle(
                              fontSize: 60.0,
                              fontWeight: FontWeight.bold,
                              color: Color.fromARGB(
                                  255, 255, 251, 0),
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
                                          builder: (context) => const NewTripTablet()),
                                    );
                                  },
                                  child: const Text('New Trip'),
                                ),
                                const SizedBox(height: 20.0),
                                ElevatedButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) => const ViewTripsScreen()),
                                    );
                                  },
                                  child: const Text('View Trips'),
                                ),
                                const SizedBox(height: 20.0),
                                ElevatedButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) =>
                                          const ReportMonthly()),
                                    );
                                  },
                                  child: const Text('Trip Reports'),
                                ),
                              ],
                            ),
                            Column(
                              children: [
                                const SizedBox(height: 20.0),
                                ElevatedButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) => const ViewFormsScreen()),
                                    );
                                  },
                                  child: const Text('View Forms'),
                                ),
                                const SizedBox(height: 20.0),
                                ElevatedButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => EditUser(
                                          userData: {
                                            'uid': user?.uid,
                                            'email': user?.email,
                                            'displayName': user?.displayName,
                                          },
                                        ),
                                      ),
                                    );
                                  },
                                  child: const Text('Edit User Info'),
                                ),
                                const SizedBox(height: 20.0),
                                ElevatedButton(
                                  onPressed: () {
                                    SystemNavigator.pop();
                                  },
                                  child: const Text('Close App'),
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
          ),
        ],
      ),
    );
  }
}