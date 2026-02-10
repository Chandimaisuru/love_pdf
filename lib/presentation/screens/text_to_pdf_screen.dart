import 'dart:io';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart'; // PDF හදන්න
import 'package:path_provider/path_provider.dart'; // Save කරන්න
import 'package:love_pdf/presentation/screens/pdf_preview_screen.dart'; // Preview කරන්න

class TextToPdfScreen extends StatefulWidget {
  const TextToPdfScreen({super.key});

  @override
  State<TextToPdfScreen> createState() => _TextToPdfScreenState();
}

class _TextToPdfScreenState extends State<TextToPdfScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();
  bool _isGenerating = false;

  // PDF Generation Logic
  Future<void> _generatePdf() async {
    if (_titleController.text.isEmpty && _bodyController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter some text first!")),
      );
      return;
    }

    setState(() => _isGenerating = true);

    try {
      // 1. අලුත් PDF Document එකක් හදනවා
      final PdfDocument document = PdfDocument();
      final PdfPage page = document.pages.add();

      // 2. Fonts සහ Colors සකස් කරගැනීම
      final PdfFont titleFont = PdfStandardFont(PdfFontFamily.helvetica, 24, style: PdfFontStyle.bold);
      final PdfFont bodyFont = PdfStandardFont(PdfFontFamily.helvetica, 14);
      final PdfBrush brush = PdfSolidBrush(PdfColor(0, 0, 0));

      // 3. Title එක ලිවීම
      double yPos = 0;

      if (_titleController.text.isNotEmpty) {
        page.graphics.drawString(
          _titleController.text,
          titleFont,
          brush: brush,
          bounds: Rect.fromLTWH(0, yPos, page.getClientSize().width, 50),
          format: PdfStringFormat(alignment: PdfTextAlignment.center),
        );
        yPos += 50;
      }

      // ඉරක් ගහනවා Title එකට යටින්
      page.graphics.drawLine(
        PdfPen(PdfColor(200, 200, 200), width: 1),
        Offset(0, yPos),
        Offset(page.getClientSize().width, yPos)
      );
      yPos += 20;

      // 4. Body එක ලිවීම
      PdfTextElement textElement = PdfTextElement(
        text: _bodyController.text,
        font: bodyFont,
        brush: brush,
      );

      PdfLayoutResult? layoutResult = textElement.draw(
        page: page,
        bounds: Rect.fromLTWH(0, yPos, page.getClientSize().width, page.getClientSize().height - yPos),
      );

      // 5. Save කරනවා
      final directory = await getApplicationDocumentsDirectory();
      final String fileName = 'Note_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final String path = '${directory.path}/$fileName';
      final File file = File(path);

      await file.writeAsBytes(await document.save());
      document.dispose();

      // 6. Preview එකට යවනවා
      if (mounted) {
        setState(() => _isGenerating = false);
        
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PdfPreviewScreen(filePath: path, fileName: fileName),
          ),
        );
      }

    } catch (e) {
      setState(() => _isGenerating = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true, // Gradient එක උඩටම යවන්න
      appBar: AppBar(
        title: const Text("Text to PDF", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent, // Transparent
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        actions: [
          // Clear Button
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined, color: Colors.tealAccent),
            tooltip: "Clear Text",
            onPressed: () {
              _titleController.clear();
              _bodyController.clear();
            },
          )
        ],
      ),
      body: Container(
        // Dark Theme Gradient
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // --- Icon Area ---
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white.withOpacity(0.1)),
                            boxShadow: [
                              BoxShadow(color: Colors.tealAccent.withOpacity(0.1), blurRadius: 10, spreadRadius: 2)
                            ]
                          ),
                          child: const Icon(Icons.edit_note, size: 40, color: Colors.tealAccent),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // --- Title Input (Glass Effect) ---
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: Colors.white.withOpacity(0.1)),
                        ),
                        child: TextField(
                          controller: _titleController,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                          cursorColor: Colors.tealAccent,
                          decoration: InputDecoration(
                            labelText: "Document Title",
                            labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                            hintText: "Enter a topic...",
                            hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                            border: InputBorder.none,
                            prefixIcon: const Icon(Icons.title, color: Colors.tealAccent),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // --- Body Input (Glass Effect) ---
                      Container(
                        height: MediaQuery.of(context).size.height * 0.45, // Fixed height for body
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: Colors.white.withOpacity(0.1)),
                        ),
                        child: TextField(
                          controller: _bodyController,
                          keyboardType: TextInputType.multiline,
                          maxLines: null,
                          expands: true, // Fills the container
                          textAlignVertical: TextAlignVertical.top,
                          style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.5),
                          cursorColor: Colors.tealAccent,
                          decoration: InputDecoration(
                            labelText: "Content",
                            labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                            hintText: "Type your notes here...",
                            hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                            border: InputBorder.none,
                            alignLabelWithHint: true,
                            contentPadding: const EdgeInsets.all(20),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // --- Bottom Action Button ---
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F2027).withOpacity(0.95), // Dark Bottom Bar
                  border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal, // Teal Button
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      elevation: 5,
                    ),
                    onPressed: _isGenerating ? null : _generatePdf,
                    icon: _isGenerating
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.picture_as_pdf),
                    label: Text(
                      _isGenerating ? "Creating PDF..." : "Create PDF",
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}