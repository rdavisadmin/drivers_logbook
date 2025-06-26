import 'dart:io';
// import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';

class ReportMonthly extends StatefulWidget {
  const ReportMonthly({super.key});

  @override
  State<ReportMonthly> createState() => _ReportMonthlyState();
}

class _ReportMonthlyState extends State<ReportMonthly> {
  String? selectedMonth;
  int? selectedYear;
  bool _isGenerating = false;

  String? _dcNumber;
  String? _probationOfficer;

  // State for vehicle selection
  final List<Map<String, dynamic>> _vehicles = [];
  String? _selectedVehicleInfo; // e.g., "Toyota Camry - Tag: ABC-123"
  bool _isLoading = true; // Combined loading state

  final List<String> months = List.generate(12, (index) {
    final date = DateTime(0, index + 1);
    return DateFormat('MMMM').format(date);
  });

  final List<int> years =
  List.generate(11, (i) => DateTime.now().year - 5 + i);

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (userDoc.exists && mounted) {
          final data = userDoc.data() as Map<String, dynamic>;
          final List<dynamic> vehicleData = data['vehicles'] ?? [];

          setState(() {
            _dcNumber = data['dcNumber'] as String?;
            _probationOfficer = data['probationOfficer'] as String?;

            _vehicles.clear();
            for (var vehicle in vehicleData) {
              if (vehicle is Map<String, dynamic>) {
                _vehicles.add(vehicle);
              }
            }
          });
        }
      } catch (e) {
        // ignore: avoid_print
        print("Error fetching user data: $e");
      }
    }
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Monthly Trip Report'),
        backgroundColor: const Color.fromARGB(255, 123, 194, 252),
      ),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/road_lines.png'), // Background image
            fit: BoxFit.cover,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Show a single loading indicator for all initial data
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else
                _buildForm(), // Build the form once data is loaded
            ],
          ),
        ),
      ),
    );
  }

  /// Builds the main form content after initial data is loaded.
  Widget _buildForm() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: selectedMonth,
                decoration: const InputDecoration(
                  labelText: 'Select Month',
                  border: OutlineInputBorder(),
                  fillColor: Colors.white,
                  filled: true,
                ),
                items: months
                    .map((month) =>
                    DropdownMenuItem(value: month, child: Text(month)))
                    .toList(),
                onChanged: (value) {
                  setState(() => selectedMonth = value);
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: DropdownButtonFormField<int>(
                value: selectedYear,
                decoration: const InputDecoration(
                  labelText: 'Select Year',
                  border: OutlineInputBorder(),
                  fillColor: Colors.white,
                  filled: true,
                ),
                items: years
                    .map((year) =>
                    DropdownMenuItem(value: year, child: Text('$year')))
                    .toList(),
                onChanged: (value) {
                  setState(() => selectedYear = value);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Vehicle Dropdown
        if (_vehicles.isEmpty)
          Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(204), // FIX: Replaced withOpacity
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text('No vehicles found. Please add a vehicle in your profile.', textAlign: TextAlign.center, style: TextStyle(color: Colors.black))
          )
        else
          DropdownButtonFormField<String>(
            value: _selectedVehicleInfo,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Select Vehicle',
              border: OutlineInputBorder(),
              fillColor: Colors.white,
              filled: true,
            ),
            items: _vehicles.map((vehicle) {
              final displayText = '${vehicle['vehicle']} - Tag: ${vehicle['tag']}';
              return DropdownMenuItem(
                value: displayText,
                child: Text(displayText, overflow: TextOverflow.ellipsis),
              );
            }).toList(),
            onChanged: (value) {
              setState(() => _selectedVehicleInfo = value);
            },
            validator: (value) => value == null ? 'Please select a vehicle' : null,
          ),

        const SizedBox(height: 20),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color.fromARGB(255, 123, 194, 252),
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50), // Make button wider
          ),
          onPressed: (selectedMonth == null ||
              selectedYear == null ||
              _selectedVehicleInfo == null || // Check for vehicle selection
              _isGenerating ||
              _dcNumber == null ||
              _probationOfficer == null)
              ? null
              : _generatePdfReport,
          child: _isGenerating
              ? const CircularProgressIndicator(color: Colors.white)
              : const Text('Generate and Open PDF'),
        ),
        if (_dcNumber != null || _probationOfficer != null)
          Container(
            margin: const EdgeInsets.only(top: 20),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(204), // FIX: Replaced withOpacity
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'DC#: ${_dcNumber ?? 'N/A'}\nProbation Officer: ${_probationOfficer ?? 'N/A'}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
      ],
    );
  }

  Future<void> _generatePdfReport() async {
    // **FIX:** Capture context-dependent members before the async gap.
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _isGenerating = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || selectedMonth == null || selectedYear == null || _selectedVehicleInfo == null || _dcNumber == null || _probationOfficer == null) {
        messenger.showSnackBar(
          const SnackBar(content: Text("Please select a month, year, vehicle, and ensure user data is loaded.")),
        );
        return;
      }

      final ttf = pw.Font.helvetica();
      final driversName = user.displayName ?? 'N/A';

      final selectedMonthIndex = months.indexOf(selectedMonth!) + 1;
      final start = DateTime(selectedYear!, selectedMonthIndex, 1);
      final end = DateTime(selectedYear!, selectedMonthIndex + 1, 1).subtract(const Duration(milliseconds: 1));

      final snapshot = await FirebaseFirestore.instance
          .collection('trips')
          .where('userId', isEqualTo: user.uid)
          .where('vehicle', isEqualTo: _selectedVehicleInfo)
          .where('tripDate', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('tripDate', isLessThanOrEqualTo: Timestamp.fromDate(end))
          .get();

      final trips = snapshot.docs;

      if (trips.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(content: Text("No trips found for the selected vehicle and month.")),
        );
        return;
      }

      trips.sort((a, b) {
        final dataA = a.data();
        final dataB = b.data();
        final tsA = dataA['tripDate'] as Timestamp?;
        final tsB = dataB['tripDate'] as Timestamp?;
        if (tsA == null || tsB == null) return 0;
        return tsA.compareTo(tsB);
      });

      final pdf = pw.Document();
      final dateFormatter = DateFormat('yyyy-MM-dd');
      final timeFormatter = DateFormat('HH:mm');

      const headers = [
        'Date', 'Point of Departure', 'Time of Departure', 'Odometer at Departure',
        'Accompanied By', 'Destination', 'Time of Arrival', 'Odometer at Arrival',
      ];

      List<List<String>> dataRows = trips.map((doc) {
        final Map<String, dynamic> data = doc.data();
        String formatTime(dynamic ts) => ts is Timestamp ? timeFormatter.format(ts.toDate()) : 'N/A';
        String formatDate(dynamic ts) => ts is Timestamp ? dateFormatter.format(ts.toDate()) : 'N/A';
        return [
          formatDate(data['tripDate']),
          data['departedFrom']?.toString() ?? 'N/A',
          formatTime(data['tripStartTime']),
          data['startOdometer']?.toString() ?? 'N/A',
          data['passenger']?.toString() ?? ' ',
          data['destination']?.toString() ?? 'N/A',
          formatTime(data['tripEndTime']),
          data['endOdometer']?.toString() ?? 'N/A',
        ];
      }).toList();

      const rowsPerPage = 25;
      for (var i = 0; i < dataRows.length; i += rowsPerPage) {
        final pageRows = dataRows.sublist(i, (i + rowsPerPage > dataRows.length) ? dataRows.length : i + rowsPerPage);

        pdf.addPage(
          pw.MultiPage(
            pageFormat: PdfPageFormat.letter.landscape,
            margin: const pw.EdgeInsets.all(20),
            header: (pw.Context context) {
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Center(child: pw.Text('STATE OF FLORIDA', style: pw.TextStyle(font: ttf, fontSize: 12, fontWeight: pw.FontWeight.bold))),
                  pw.Center(child: pw.Text('SEX OFFENDER PROBATION DRIVING LOG', style: pw.TextStyle(font: ttf, fontSize: 12, fontWeight: pw.FontWeight.bold))),
                  pw.SizedBox(height: 10),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Name: $driversName', style: pw.TextStyle(font: ttf, fontSize: 12, decoration: pw.TextDecoration.underline)),
                      pw.Text('DC#: ${_dcNumber ?? 'N/A'}', style: pw.TextStyle(font: ttf, fontSize: 12, decoration: pw.TextDecoration.underline)),
                      pw.Text('Probation Officer: ${_probationOfficer ?? 'N/A'}', style: pw.TextStyle(font: ttf, fontSize: 12, decoration: pw.TextDecoration.underline)),
                    ],
                  ),
                  pw.SizedBox(height: 5),
                  pw.Text('Vehicle: $_selectedVehicleInfo', style: pw.TextStyle(font: ttf, fontSize: 12)),

                ],
              );
            },
            footer: (pw.Context context) {
              return pw.Container(
                alignment: pw.Alignment.center,
                margin: const pw.EdgeInsets.only(top: 1.0 * PdfPageFormat.cm),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('DC3-244 (Revised 6-02)', style: pw.TextStyle(font: ttf, fontSize: 8, color: PdfColors.black)),
                    pw.Text('Page ${context.pageNumber} of ${context.pagesCount}', style: pw.TextStyle(font: ttf, fontSize: 8, color: PdfColors.black)),
                    pw.Text(driversName, style: pw.TextStyle(font: ttf, fontSize: 8, color: PdfColors.black)),
                  ],
                ),
              );
            },
            build: (pw.Context context) => [
              pw.SizedBox(height: 6),
              pw.TableHelper.fromTextArray(
                headers: headers,
                data: pageRows,
                border: pw.TableBorder.all(width: 0.5),
                headerStyle: pw.TextStyle(font: ttf, fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.black),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.grey400),
                cellStyle: pw.TextStyle(font: ttf, fontSize: 8),
                cellPadding: const pw.EdgeInsets.symmetric(vertical: 2.0, horizontal: 2.0),
                cellAlignment: pw.Alignment.center,
                columnWidths: {
                  0: const pw.FixedColumnWidth(55), 1: const pw.FixedColumnWidth(140),
                  2: const pw.FixedColumnWidth(50), 3: const pw.FixedColumnWidth(60),
                  4: const pw.FixedColumnWidth(140), 6: const pw.FixedColumnWidth(50),
                  7: const pw.FixedColumnWidth(55),
                },
              )
            ],
          ),
        );
      }

      final Directory directory = await getApplicationDocumentsDirectory();
      final String path = directory.path;
      final safeMonth = selectedMonth!.replaceAll(' ', '_');
      final filename = 'Trip_Report_${safeMonth}_$selectedYear.pdf';
      final filePath = '$path/$filename';
      final file = File(filePath);
      await file.writeAsBytes(await pdf.save());

      messenger.showSnackBar(SnackBar(content: Text("PDF saved to: $filename")));

      final result = await OpenFile.open(file.path);
      if (result.type != ResultType.done) {
        messenger.showSnackBar(SnackBar(content: Text("Error opening file: ${result.message}")));
      }
    } on FirebaseException catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text("Database Error: ${e.message}. This may require a composite index in Firestore.")),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text("An unexpected error occurred: ${e.toString()}")),
      );
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }
}