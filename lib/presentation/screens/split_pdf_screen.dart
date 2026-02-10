import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:love_pdf/presentation/screens/split_options_sheet.dart';
import 'package:love_pdf/presentation/screens/visual_split_screen.dart';

class SplitPdfScreen extends StatefulWidget {
  const SplitPdfScreen({super.key});

  @override
  State<SplitPdfScreen> createState() => _SplitPdfScreenState();
}

class _SplitPdfScreenState extends State<SplitPdfScreen> {
  
  // ෆයිල් එක තෝරාගැනීමේ සහ ඊළඟට Options පෙන්වීමේ Logic එක
  Future<void> _pickAndSplitPdf(BuildContext context) async {
    // 1. File Picker එක Open කිරීම
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null && result.files.single.path != null) {
      if (!mounted) return;

      // 2. ෆයිල් එක තේරුවට පස්සේ Options Sheet එක පෙන්වීම
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (_) => SplitOptionsSheet(
          // Extract (Keep) තේරුවොත්
          onExtract: () {
            Navigator.pop(context); // Sheet එක වහනවා
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => VisualSplitScreen(
                  filePath: result.files.single.path!,
                  mode: SplitMode.keep, // Keep Mode එකට යවනවා
                ),
              ),
            );
          },
          // Delete (Remove) තේරුවොත්
          onDelete: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => VisualSplitScreen(
                  filePath: result.files.single.path!,
                  mode: SplitMode.remove, // Remove Mode එකට යවනවා
                ),
              ),
            );
          },
          // Range තේරුවොත් (තවම හදලා නෑ)
          onRange: () {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Range Split Coming Soon")),
            );
          },
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Split PDF", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent, // Gradient එක පේන්න
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
      ),
      body: Container(
        width: double.infinity,
        // Merge Screen එකේ වගේම Dark Gradient එක
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // --- Icon Area ---
            Container(
              padding: const EdgeInsets.all(35),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05), // Glass Effect
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.1)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.orange.withOpacity(0.2),
                    blurRadius: 20,
                    spreadRadius: 5,
                  )
                ]
              ),
              child: const Icon(
                Icons.call_split, // Split Icon
                size: 80,
                color: Colors.orangeAccent,
              ),
            ),
            const SizedBox(height: 40),
            
            // --- Text Area ---
            const Text(
              "Split PDF Pages",
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 15),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                "Extract specific pages or remove unwanted pages from your PDF document easily.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 60),

            // --- Action Button ---
            SizedBox(
              width: 250,
              height: 55,
              child: ElevatedButton.icon(
                onPressed: () => _pickAndSplitPdf(context),
                icon: const Icon(Icons.upload_file),
                label: const Text("Select PDF File"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange, // Split එකට Orange පාට
                  foregroundColor: Colors.white,
                  elevation: 8,
                  textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}