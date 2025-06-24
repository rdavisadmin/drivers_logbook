import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:permission_handler/permission_handler.dart';
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

  final List<String> months = List.generate(12, (index) {
    final date = DateTime(0, index + 1);
    return DateFormat('MMMM').format(date);
  });

  final List<int> years =
  List.generate(11, (i) => DateTime.now().year - 5 + i); // +/- 5 years

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
              onPressed: (selectedMonth == null || selectedYear == null)
                  ? null
                  : _generatePdfReport,
              child: const Text('Generate PDF'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _generatePdfReport() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || selectedMonth == null || selectedYear == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a month and year.")),
      );
      return;
    }

    // ✅ Use default font for safety
    final ttf = pw.Font.helvetica();

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
        const SnackBar(content: Text("No trips found for selected month")),
      );
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

      String formatTime(dynamic ts) {
        if (ts is Timestamp) return timeFormatter.format(ts.toDate());
        return 'N/A';
      }

      String formatDate(dynamic ts) {
        if (ts is Timestamp) return dateFormatter.format(ts.toDate());
        return 'N/A';
      }

      return [
        formatDate(data['tripDate']),
        data['departedFrom']?.toString() ?? 'N/A',
        formatTime(data['tripStartTime']),
        data['startOdometer']?.toString() ?? 'N/A',
        data['passenger']?.toString() ?? 'N/A',
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
        pw.Page(
          pageFormat: PdfPageFormat.letter.landscape,
          margin: const pw.EdgeInsets.all(20),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Trip Report for $selectedMonth $selectedYear - Page ${(i ~/ rowsPerPage) + 1}',
                  style: pw.TextStyle(font: ttf, fontSize: 8),
                ),
                pw.SizedBox(height: 10),
                pw.Table(
                  border: pw.TableBorder.all(width: 0.5),
                  columnWidths: {
                    0: const pw.FixedColumnWidth(60),
                    1: const pw.FlexColumnWidth(2),
                    2: const pw.FixedColumnWidth(70),
                    3: const pw.FixedColumnWidth(70),
                    4: const pw.FlexColumnWidth(2),
                    5: const pw.FlexColumnWidth(2),
                    6: const pw.FixedColumnWidth(70),
                    7: const pw.FixedColumnWidth(70),
                  },
                  children: [
                    pw.TableRow(
                      decoration:
                      const pw.BoxDecoration(color: PdfColors.grey300),
                      children: headers.map((header) {
                        return pw.Container(
                          alignment: pw.Alignment.center,
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(
                            header,
                            style: pw.TextStyle(
                              font: ttf,
                              fontSize: 8,
                              fontWeight: pw.FontWeight.bold,
                            ),
                            textAlign: pw.TextAlign.center,
                          ),
                        );
                      }).toList(),
                    ),
                    ...pageRows.map((row) => pw.TableRow(
                      children: row.map((cell) {
                        return pw.Container(
                          alignment: pw.Alignment.center,
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(
                            cell,
                            style: pw.TextStyle(font: ttf, fontSize: 8),
                            textAlign: pw.TextAlign.center,
                          ),
                        );
                      }).toList(),
                    )),
                  ],
                )
              ],
            );
          },
        ),
      );
    }

    // ✅ Permission and path setup
    if (!kIsWeb && Platform.isAndroid) {
      final status = await Permission.storage.request();
      if (!status.isGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Storage permission denied")),
        );
        return;
      }
    }

    Directory? downloadsDir;
    if (Platform.isAndroid) {
      downloadsDir = await getExternalStorageDirectory(); // safer than /Download
    } else if (Platform.isIOS) {
      downloadsDir = await getApplicationDocumentsDirectory();
    } else {
      downloadsDir = await getDownloadsDirectory();
    }

    final safeMonth = selectedMonth!.replaceAll(' ', '_');
    final filename = 'Trip_Report_${safeMonth}_$selectedYear.pdf';
    final filePath = '${downloadsDir!.path}/$filename';
    final file = File(filePath);
    await file.writeAsBytes(await pdf.save());

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("PDF saved as $filename")),
    );

    await OpenFile.open(file.path);
  }
}
