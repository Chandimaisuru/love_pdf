import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:love_pdf/presentation/screens/edit_pdf_screen.dart';
import 'package:love_pdf/presentation/screens/image_to_pdf_screen.dart';
import 'package:love_pdf/presentation/screens/merge_pdf_screen.dart';
import 'package:love_pdf/presentation/screens/pdf_preview_screen.dart';
import 'package:love_pdf/presentation/screens/pdf_to_image_screen.dart';
import 'package:love_pdf/presentation/screens/pdf_to_text_screen.dart';
import 'package:love_pdf/presentation/screens/split_options_sheet.dart';
import 'package:love_pdf/presentation/screens/text_to_pdf_screen.dart';
import 'package:love_pdf/presentation/screens/visual_split_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  // --- Logic: Pick and Open PDF ---
  Future<void> _pickAndOpenPdf(BuildContext context) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null && result.files.single.path != null) {
      String path = result.files.single.path!;
      String name = result.files.single.name;

      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PdfPreviewScreen(filePath: path, fileName: name),
          ),
        );
      }
    }
  }

  // --- Logic: Pick and Split PDF ---
  Future<void> _pickAndSplitPdf(BuildContext context) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null && result.files.single.path != null) {
      String path = result.files.single.path!;

      if (context.mounted) {
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          builder: (context) => SplitOptionsSheet(
            onExtract: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => VisualSplitScreen(filePath: path, mode: SplitMode.keep)));
            },
            onDelete: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => VisualSplitScreen(filePath: path, mode: SplitMode.remove)));
            },
            onRange: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Range Split Coming Soon!")));
            },
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true, 
      appBar: AppBar(
        title: const Text(
          'Love PDF Tools',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color:        Color(0xFF232526), // Fallback color
        // --- 1. BLACK GRADIENT BACKGROUND ---
  
        child: SafeArea(
          child: SingleChildScrollView(
            // --- 2. SIZE REDUCTION TRICK ---
            // horizontal padding එක 40ක් කළා (කලින් 20යි). 
            // මේකෙන් වෙන්නේ මැද තියෙන ඉඩ අඩු වෙලා බොක්ස් ටික ඉබේම පොඩි වෙන එකයි.
            padding: const EdgeInsets.symmetric(horizontal: 34.0, vertical: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader("Core PDF Tools"),
                const SizedBox(height: 15),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2, // පේළියට බොක්ස් 2යි
                  crossAxisSpacing: 15,
                  mainAxisSpacing: 15,
                  childAspectRatio: 1.1, // බොක්ස් එක ටිකක් කොට (Flat) කළා ලස්සනට පේන්න
                  children: [

                     _buildToolCard(
                      context, "View PDF", Icons.picture_as_pdf, Colors.redAccent, 
                      () => _pickAndOpenPdf(context)
                    ),

                      _buildToolCard(
                      context, "Edit PDF", Icons.edit_note, Colors.green, 
                      () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EditPdfScreen()))
                    ),
                    _buildToolCard(
                      context, "Merge PDF", Icons.merge_type, Colors.blue, 
                      () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MergePdfScreen()))
                    ),
                    _buildToolCard(
                      context, "Split PDF", Icons.call_split, Colors.orange, 
                      () => _pickAndSplitPdf(context)
                    ),

                    // Original Icon & Name kept

                  ],
                ),

                const SizedBox(height: 30),

                _buildSectionHeader("Converters"),
                const SizedBox(height: 15),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2, // පේළියට බොක්ස් 2යි
                  crossAxisSpacing: 15,
                  mainAxisSpacing: 15,
                  childAspectRatio: 1.1,
                  children: [
                    _buildToolCard(
                      context, "Image to PDF", Icons.picture_as_pdf_rounded, Colors.purple, 
                      () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ImageToPdfScreen()))
                    ),
                                        _buildToolCard(
                      context, "PDF to Image", Icons.collections, Colors.indigo, 
                      () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PdfToImageScreen()))
                    ),
                    _buildToolCard(
                      context, "Text to PDF", Icons.text_fields, Colors.teal, 
                      () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TextToPdfScreen()))
                    ),

                    _buildToolCard(
                      context, "PDF to Text", Icons.article, Colors.orange, 
                      () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PdfToTextScreen()))
                    ),
                  ],
                ),
                
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- WHITE HEADER TEXT ---
  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.white, // සුදු පාට
        letterSpacing: 0.5,
      ),
    );
  }

  // --- GLASSMORPHISM CARD (BLACK THEME) ---
  Widget _buildToolCard(BuildContext context, String title, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          // Glass Effect: White with 10% opacity
          color: Colors.white.withOpacity(0.1), 
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.2), width: 1), // තුනී සුදු ඉරක්
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2), // Icon Background Glow
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 30), // Original Size
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.white, // Text White
              ),
            ),
          ],
        ),
      ),
    );
  }
}