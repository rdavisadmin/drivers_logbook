import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:logger/logger.dart';

class ViewFormsScreen extends StatefulWidget {
  const ViewFormsScreen({super.key});

  @override
  ViewFormsScreenState createState() => ViewFormsScreenState();
}

class ViewFormsScreenState extends State<ViewFormsScreen> {
  late Future<List<Reference>> _pdfFiles;
  final storage = FirebaseStorage.instance;
  final _logger = Logger();

  @override
  void initState() {
    super.initState();
    _pdfFiles = _fetchPdfFiles();
  }

  Future<List<Reference>> _fetchPdfFiles() async {
    // Explicitly check if the user is authenticated before making the call
    if (FirebaseAuth.instance.currentUser == null) {
      _logger.e("User is not authenticated. Cannot fetch files.");
      return [];
    }

    try {
      // List all items in the 'Forms' directory.
      final ListResult result = await storage.ref('forms').listAll();
      return result.items;
    } catch (e) {
      // Handle errors, e.g., folder not found, permissions issue.
      _logger.e('Error fetching files: $e');
      return [];
    }
  }

  Future<void> _openPdf(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri)) {
      // Handle the error gracefully
      _logger.e('Could not launch $url');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open the Forms. Please try again later.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('View Forms You Can Download'),
      ),
      body: FutureBuilder<List<Reference>>(
        future: _pdfFiles,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Error loading forms.'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No Files found in the "Forms" folder.'));
          }

          final files = snapshot.data!;
          return ListView.builder(
            itemCount: files.length,
            itemBuilder: (context, index) {
              final file = files[index];
              return ListTile(
                title: Text(file.name),
                leading: const Icon(Icons.picture_as_pdf),
                onTap: () async {
                  if (!mounted) return;
                  try {
                    final String downloadUrl = await file.getDownloadURL();
                    if (!mounted) return;
                    await _openPdf(downloadUrl);
                  } catch (e) {
                    _logger.e('Error getting download URL: $e');
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error opening report: ${file.name}'),
                        ),
                      );
                    }
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}
