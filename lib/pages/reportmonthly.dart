import 'dart:io';
import 'package:flutter/foundation.dart';
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
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (userDoc.exists) {
          setState(() {
            _dcNumber = userDoc['dcNumber'] as String?;
            _probationOfficer = userDoc['probationOfficer'] as String?;
          });
        }
      } catch (e) {
        print("Error fetching user data: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Monthly Trip Report')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: selectedMonth,
                    decoration: const InputDecoration(
                      labelText: 'Select Month',
                      border: OutlineInputBorder(),
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
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: (selectedMonth == null ||
                  selectedYear == null ||
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
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Text('DC#: ${_dcNumber ?? 'N/A'}, Probation Officer: ${_probationOfficer ?? 'N/A'}'),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _generatePdfReport() async {
    setState(() => _isGenerating = true);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null || selectedMonth == null || selectedYear == null || _dcNumber == null || _probationOfficer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a month and year, and ensure user data is loaded.")),
      );
      setState(() => _isGenerating = false);
      return;
    }

    final ttf = pw.Font.helvetica();
    final driversName = user.displayName ?? 'N/A';

    final selectedMonthIndex = months.indexOf(selectedMonth!) + 1;
    final start = DateTime(selectedYear!, selectedMonthIndex, 1);
    final end = DateTime(selectedYear!, selectedMonthIndex + 1, 1)
        .subtract(const Duration(milliseconds: 1));

    final snapshot = await FirebaseFirestore.instance
        .collection('trips')
        .where('userId', isEqualTo: user.uid)
        .where('tripDate', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('tripDate', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .orderBy('tripDate')
        .get();

    final trips = snapshot.docs;

    if (trips.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No trips found for the selected month.")),
      );
      setState(() => _isGenerating = false);
      return;
    }

    final pdf = pw.Document();
    final dateFormatter = DateFormat('yyyy-MM-dd');
    final timeFormatter = DateFormat('HH:mm');

    const headers = [
      'Date',
      'Point of Departure',
      'Time of Departure',
      'Odometer at Departure',
      'Accompanied By',
      'Destination',
      'Time of Arrival',
      'Odometer at Arrival',
    ];

    List<List<String>> dataRows = trips.map((doc) {
      final Map<String, dynamic> data = doc.data();
      String formatTime(dynamic ts) =>
          ts is Timestamp ? timeFormatter.format(ts.toDate()) : 'N/A';
      String formatDate(dynamic ts) =>
          ts is Timestamp ? dateFormatter.format(ts.toDate()) : 'N/A';
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
      final pageRows = dataRows.sublist(
        i,
        (i + rowsPerPage > dataRows.length) ? dataRows.length : i + rowsPerPage,
      );

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.letter.landscape,
          margin: const pw.EdgeInsets.all(20),
          header: (pw.Context context) {
            // Only show header on odd-numbered pages
            if (context.pageNumber % 2 != 0) {
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Center(
                    child: pw.Text(
                      'STATE OF FLORIDA',
                      style: pw.TextStyle(font: ttf, fontSize: 12, fontWeight: pw.FontWeight.bold),
                    ),
                  ),
                  pw.Center(
                    child: pw.Text(
                      'SEX OFFENDER PROBATION DRIVING LOG',
                      style: pw.TextStyle(font: ttf, fontSize: 12, fontWeight: pw.FontWeight.bold),
                    ),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'Name: $driversName',
                        style: pw.TextStyle(font: ttf, fontSize: 12),
                      ),
                      pw.Text(
                        'DC#: ${_dcNumber ?? 'N/A'}',
                        style: pw.TextStyle(font: ttf, fontSize: 12),
                      ),
                      pw.Text(
                        'Probation Officer: ${_probationOfficer ?? 'N/A'}',
                        style: pw.TextStyle(font: ttf, fontSize: 12),
                      ),
                    ],
                  ),
                  pw.Divider(),
                  pw.SizedBox(height: 1),
                ],
              );
            }
            // Return an empty Container for even pages so nothing is rendered
            return pw.Container();
          },
          footer: (pw.Context context) {
            return pw.Container(
              alignment: pw.Alignment.center,
              margin: const pw.EdgeInsets.only(top: 1.0 * PdfPageFormat.cm),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'DC3-244 (Revised 6-02)',
                    style: pw.TextStyle(font: ttf, fontSize: 8, color: PdfColors.black),
                  ),
                  pw.Text(
                    'Page ${context.pageNumber} of ${context.pagesCount}',
                    style: pw.TextStyle(font: ttf, fontSize: 8, color: PdfColors.black),
                  ),
                  pw.Text(
                    driversName,
                    style: pw.TextStyle(font: ttf, fontSize: 8, color: PdfColors.black),
                  ),
                ],
              ),
            );
          },
          build: (pw.Context context) => [
            pw.SizedBox(height: 6),
            pw.Table.fromTextArray(
              headers: headers,
              data: pageRows,
              border: pw.TableBorder.all(width: 0.5),
              headerStyle: pw.TextStyle(
                font: ttf,
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.black,
              ),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey400),
              cellStyle: pw.TextStyle(font: ttf, fontSize: 8),
              cellPadding: const pw.EdgeInsets.symmetric(vertical: 2.0, horizontal: 2.0),
              cellAlignment: pw.Alignment.center,
              columnWidths: {
                0: const pw.FixedColumnWidth(55),
                1: const pw.FixedColumnWidth(140),
                2: const pw.FixedColumnWidth(50),
                3: const pw.FixedColumnWidth(60),
                4: const pw.FixedColumnWidth(140),
                6: const pw.FixedColumnWidth(50),
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

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("PDF saved to: $filename")),
    );

    final result = await OpenFile.open(file.path);

    if (result.type != ResultType.done) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error opening file: ${result.message}")),
      );
    }

    setState(() => _isGenerating = false);
  }
}