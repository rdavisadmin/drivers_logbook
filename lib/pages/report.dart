// ignore_for_file: avoid_print

import 'package:flutter/material.dart';

class GenerateReportScreen extends StatefulWidget {
  const GenerateReportScreen({super.key});

  @override
  State<GenerateReportScreen> createState() => _GenerateReportScreenState();
}

class _GenerateReportScreenState extends State<GenerateReportScreen> {
  String? _selectedMonth;
  late TextEditingController _yearController;
  final List<String> _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December'
  ];

  @override
  void initState() {
    super.initState();
    _yearController =
        TextEditingController(text: DateTime.now().year.toString());
  }

  @override
  void dispose() {
    _yearController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Generate Report'),
      ),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/road_lines.png'), // Make sure this path is correct
            fit: BoxFit.cover,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // TextField for the year
              TextField(
                controller: _yearController,
                decoration: InputDecoration(
                  label: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                    decoration: BoxDecoration(
                      color: Colors.grey[300], // Lite gray background for the label
                      borderRadius: BorderRadius.circular(4.0),
                    ),
                    child: const Text('Enter Year'),
                  ),
                  filled: true,
                  fillColor: Colors.grey[200], // Field background
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),

              // Dropdown for selecting the month
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  label: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                    decoration: BoxDecoration(
                      color: Colors.grey[300], // Lite gray background for the label
                      borderRadius: BorderRadius.circular(4.0),
                    ),
                    child: const Text('Select Month'),
                  ),
                  filled: true,
                  fillColor: Colors.grey[300], // Field background
                  border: OutlineInputBorder(),
                ),
                value: _selectedMonth,
                hint: const Text('Choose a month'),
                isExpanded: true,
                items: _months.map((String month) {
                  return DropdownMenuItem<String>(
                    value: month,
                    child: Text(month),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedMonth = newValue;
                  });
                },
              ),
              const SizedBox(height: 20),

              // Monthly Report Button
              ElevatedButton(
                onPressed: () {
                  final String year = _yearController.text;
                  if (_selectedMonth != null) {
                    // TODO: Implement monthly report generation logic
                    print(
                        'Generating Monthly Report for: $_selectedMonth $year');
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(
                              'Generating Monthly Report for: $_selectedMonth $year')),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Please select a month first!')),
                    );
                  }
                },
                child: const Text('Monthly Report'),
              ),
              const SizedBox(height: 10),

              // Yearly Report Button
              ElevatedButton(
                onPressed: () {
                  // TODO: Implement yearly report generation logic
                  print('Generating Yearly Report');
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Generating Yearly Report')),
                  );
                },
                child: const Text('Yearly Report'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}