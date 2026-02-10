import 'dart:async';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:love_pdf/presentation/screens/split_pdf_screen.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import 'package:love_pdf/presentation/screens/edit_pdf_screen.dart';
import 'package:love_pdf/presentation/screens/image_to_pdf_screen.dart';
import 'package:love_pdf/presentation/screens/merge_pdf_screen.dart';
import 'package:love_pdf/presentation/screens/pdf_preview_screen.dart';
import 'package:love_pdf/presentation/screens/pdf_to_image_screen.dart';
import 'package:love_pdf/presentation/screens/pdf_to_text_screen.dart';
import 'package:love_pdf/presentation/screens/split_options_sheet.dart';
import 'package:love_pdf/presentation/screens/text_to_pdf_screen.dart';
import 'package:love_pdf/presentation/screens/visual_split_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  StreamSubscription? _intentDataStreamSubscription;

  @override
  void initState() {
    super.initState();
    _setupInteractedMessage();
  }

  @override
  void dispose() {
    _intentDataStreamSubscription?.cancel();
    super.dispose();
  }

  // ---------- SHARE INTENT ----------
  void _setupInteractedMessage() {
    _intentDataStreamSubscription =
        ReceiveSharingIntent.instance.getMediaStream().listen(
      (value) {
        if (value.isNotEmpty) {
          _openSharedFile(value.first.path);
        }
      },
    );

    ReceiveSharingIntent.instance.getInitialMedia().then((value) {
      if (value.isNotEmpty) {
        _openSharedFile(value.first.path);
        ReceiveSharingIntent.instance.reset();
      }
    });
  }

  void _openSharedFile(String path) {
    if (path.toLowerCase().endsWith('.pdf')) {
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PdfPreviewScreen(
                filePath: path,
                fileName: path.split('/').last,
              ),
            ),
          );
        }
      });
    }
  }

  // ---------- PICK PDF ----------
  Future<void> _pickAndOpenPdf(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null && result.files.single.path != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PdfPreviewScreen(
            filePath: result.files.single.path!,
            fileName: result.files.single.name,
          ),
        ),
      );
    }
  }

  Future<void> _pickAndSplitPdf(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null && result.files.single.path != null) {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (_) => SplitOptionsSheet(
          onExtract: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => VisualSplitScreen(
                  filePath: result.files.single.path!,
                  mode: SplitMode.keep,
                ),
              ),
            );
          },
          onDelete: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => VisualSplitScreen(
                  filePath: result.files.single.path!,
                  mode: SplitMode.remove,
                ),
              ),
            );
          },
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

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF0F2027),
              Color(0xFF203A43),
              Color(0xFF2C5364),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle("Core PDF Tools"),
                const SizedBox(height: 14),
                _grid([
                  _toolCard("View PDF", Icons.picture_as_pdf, Colors.redAccent,
                      () => _pickAndOpenPdf(context)),
                  _toolCard("Edit PDF", Icons.edit_note, Colors.green,
                      () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const EditPdfScreen()))),
                  _toolCard("Merge PDF", Icons.merge_type, Colors.blue,
                      () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const MergePdfScreen()))),
                  _toolCard("Split PDF", Icons.call_split, Colors.orange,
                      // දැන් කෙලින්ම අලුත් Landing Page එකට යනවා
                      () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const SplitPdfScreen())))
                ]),
                const SizedBox(height: 28),
                _sectionTitle("Converters"),
                const SizedBox(height: 14),
                _grid([
                  _toolCard("Image to PDF", Icons.image, Colors.purple,
                      () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const ImageToPdfScreen()))),
                  _toolCard("PDF to Image", Icons.collections, Colors.indigo,
                      () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const PdfToImageScreen()))),
                  _toolCard("Text to PDF", Icons.text_fields, Colors.teal,
                      () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const TextToPdfScreen()))),
                  _toolCard("PDF to Text", Icons.article, Colors.orange,
                      () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const PdfToTextScreen()))),
                ]),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------- APP BAR ----------
  AppBar _buildAppBar() {
    return AppBar(
      elevation: 0,
      centerTitle: false,
      titleSpacing: 22,
      backgroundColor: const Color(0xFF0F2027),
      title: const Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: "Click ",
              style: TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w500,
              ),
            ),
            TextSpan(
              text: "PDF",
              style: TextStyle(
                color: Color(0xFFD32F2F),
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- SECTION TITLE (NO UNDERLINE) ----------
  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: Colors.white,
        letterSpacing: 0.6,
      ),
    );
  }

  // ---------- GRID ----------
  Widget _grid(List<Widget> children) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 18,
      crossAxisSpacing: 18,
      childAspectRatio: 1.2, // 👈 cards smaller & smarter
      children: children,
    );
  }

  // ---------- TOOL CARD (COMPACT) ----------
  Widget _toolCard(
      String title, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: Colors.white.withOpacity(0.08),
          border: Border.all(color: Colors.white.withOpacity(0.18)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              height: 48,
              width: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withOpacity(0.85),
              ),
              child: Icon(icon, color: Colors.white, size: 26),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
         
          ],
        ),
      ),
    );
  }
}
