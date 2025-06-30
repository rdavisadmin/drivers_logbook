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
    final messenger = ScaffoldMessenger.of(context);
    final uri = Uri.parse(url);
    if (!await launchUrl(uri)) {
      // Handle the error gracefully
      _logger.e('Could not launch $url');
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Could not open the Forms. Please try again later.'),
        ),
      );
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('View Forms You Can Download'),
        backgroundColor: const Color.fromARGB(255, 123, 194, 252),
      ),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/road_lines.png'), // Apply background
            fit: BoxFit.cover,
          ),
        ),
        child: FutureBuilder<List<Reference>>(
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
            // Use ListView.separated to automatically add dividers
            return ListView.separated(
              itemCount: files.length,
              separatorBuilder: (context, index) => const Divider(color: Colors.white70), // Define the divider
              itemBuilder: (context, index) {
                final file = files[index];
                return Container(
                  color: Colors.black.withAlpha(204),
                  // Add a semi-transparent background to list items for readability
                  child: ListTile(
                    title: Text(
                      file.name.replaceAll('.pdf', ''), // Clean up the name for display
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    leading: const Icon(Icons.picture_as_pdf, color: Colors.white),
                    onTap: () async {
                      // **FIX:** Capture context-dependent members before the async gap.
                      final messenger = ScaffoldMessenger.of(context);
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Preparing to open form...')),
                      );
                      try {
                        final String downloadUrl = await file.getDownloadURL();
                        // The 'mounted' check is still good practice before the final async call.
                        if (!mounted) return;
                        await _openPdf(downloadUrl);
                      } catch (e) {
                        _logger.e('Error getting download URL: $e');
                        // Use the captured messenger instance.
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text('Error opening report: ${file.name}'),
                          ),
                        );
                      }
                    },
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}