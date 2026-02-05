import 'package:flutter/material.dart';
import 'package:love_pdf/presentation/screens/image_to_pdf_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text(
          'Love PDF Tools',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Section 1: Core Tools ---
            _buildSectionHeader("Core PDF Tools"),
            const SizedBox(height: 15),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 15,
              mainAxisSpacing: 15,
              childAspectRatio: 1.1,
              children: [
                _buildToolCard(
                  context, "Merge PDF", Icons.merge_type, Colors.blue, 
                  () { /* TODO: Navigate to Merge Screen */ }
                ),
                _buildToolCard(
                  context, "Split PDF", Icons.call_split, Colors.orange, 
                  () { /* TODO: Navigate to Split Screen */ }
                ),
                _buildToolCard(
                  context, "Edit PDF", Icons.edit_note, Colors.green, 
                  () { /* TODO: Navigate to Edit Screen */ }
                ),
                _buildToolCard(
                  context, "View PDF", Icons.picture_as_pdf, Colors.redAccent, 
                  () { /* TODO: Navigate to Viewer */ }
                ),
              ],
            ),

            const SizedBox(height: 30),

            // --- Section 2: Converters ---
            _buildSectionHeader("Converters"),
            const SizedBox(height: 15),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 15,
              mainAxisSpacing: 15,
              childAspectRatio: 1.1,
              children: [
 // home_screen.dart ඇතුළේ...

        _buildToolCard(
          context, "Image to PDF", Icons.image, Colors.purple, 
          () { 
          // මෙන්න මේ කොටස අලුතින් දාන්න
              Navigator.push(
                context, 
                MaterialPageRoute(builder: (context) => const ImageToPdfScreen())
              );
            }
          ),
                          _buildToolCard(
                  context, "Text to PDF", Icons.text_fields, Colors.teal, 
                  () { /* TODO: Navigate to Text to PDF */ }
                ),
                _buildToolCard(
                  context, "PDF to Image", Icons.collections, Colors.indigo, 
                  () { /* TODO: Navigate to PDF to Image */ }
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Section Header Widget
  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.blueGrey,
      ),
    );
  }

  // Card Widget
  Widget _buildToolCard(BuildContext context, String title, IconData icon, Color color, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 30),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}