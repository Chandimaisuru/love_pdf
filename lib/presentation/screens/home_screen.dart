import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart'; // අලුතින් දැම්මා
import 'package:love_pdf/presentation/screens/edit_pdf_screen.dart';
import 'package:love_pdf/presentation/screens/image_to_pdf_screen.dart';
import 'package:love_pdf/presentation/screens/merge_pdf_screen.dart';
import 'package:love_pdf/presentation/screens/pdf_preview_screen.dart';
import 'package:love_pdf/presentation/screens/split_options_sheet.dart';
import 'package:love_pdf/presentation/screens/text_to_pdf_screen.dart';
import 'package:love_pdf/presentation/screens/visual_split_screen.dart'; // අලුතින් දැම්මා

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  // --- New Logic: Pick and Open PDF ---
  Future<void> _pickAndOpenPdf(BuildContext context) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null && result.files.single.path != null) {
      String path = result.files.single.path!;
      String name = result.files.single.name;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PdfPreviewScreen(
            filePath: path, 
            fileName: name
          ),
        ),
      );
    }
  }
// --- New Logic: Pick and Split PDF ---
  Future<void> _pickAndSplitPdf(BuildContext context) async {
  // 1. File එක තෝරනවා
  FilePickerResult? result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['pdf'],
  );

  if (result != null && result.files.single.path != null) {
    String path = result.files.single.path!;

    // 2. Bottom Sheet එක පෙන්වනවා
    if (context.mounted) {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (context) => SplitOptionsSheet(
          // Option A: Extract
          onExtract: () {
            Navigator.pop(context); // Sheet එක වහනවා
            Navigator.push(context, MaterialPageRoute(
              builder: (_) => VisualSplitScreen(filePath: path, mode: SplitMode.keep)
            ));
          },
          // Option B: Delete
          onDelete: () {
            Navigator.pop(context);
            Navigator.push(context, MaterialPageRoute(
              builder: (_) => VisualSplitScreen(filePath: path, mode: SplitMode.remove)
            ));
          },
          // Option C: Range (මේක අපි ඊළඟට කතා කරමු, දැනට TODO)
          onRange: () {
            Navigator.pop(context);
            // _showRangeSplitDialog(context, path); // අපි ඊළඟට මේක හදමු
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
                  () { 
                    Navigator.push(
                      context, 
                      MaterialPageRoute(builder: (context) => const MergePdfScreen())
                    );
                  }
                ),
              _buildToolCard(
                context, "Split PDF", Icons.call_split, Colors.orange, 
                () { _pickAndSplitPdf(context); } // Function call
              ),
              _buildToolCard(
                context, "Edit PDF", Icons.edit_note, Colors.green, 
                () { 
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const EditPdfScreen()));
                }
              ),
                // --- Updated View PDF Card ---
                _buildToolCard(
                  context, "View PDF", Icons.picture_as_pdf, Colors.redAccent, 
                  () { 
                    _pickAndOpenPdf(context); // Function එක call කළා
                  }
                ),
              ],
            ),

            const SizedBox(height: 30),

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
                _buildToolCard(
                  context, "Image to PDF", Icons.image, Colors.purple, 
                  () { 
                    Navigator.push(
                      context, 
                      MaterialPageRoute(builder: (context) => const ImageToPdfScreen())
                    );
                  }
                ),
              _buildToolCard(
                context, "Text to PDF", Icons.text_fields, Colors.teal, 
                () { 
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const TextToPdfScreen()));
                }
              ),
                _buildToolCard(
                  context, "PDF to Image", Icons.collections, Colors.indigo, 
                  () { /* TODO: PDF to Image */ }
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

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