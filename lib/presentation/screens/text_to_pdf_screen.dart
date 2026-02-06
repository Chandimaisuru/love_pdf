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
      final PdfPage page = document.pages.add(); // පළමු පිටුව එකතු කරනවා

      // 2. Fonts සහ Colors සකස් කරගැනීම
      // Title Font (ලොකු සහ Bold)
      final PdfFont titleFont = PdfStandardFont(PdfFontFamily.helvetica, 24, style: PdfFontStyle.bold);
      // Body Font (සාමාන්‍ය)
      final PdfFont bodyFont = PdfStandardFont(PdfFontFamily.helvetica, 14);

      final PdfBrush brush = PdfSolidBrush(PdfColor(0, 0, 0)); // කළු පාට

      // 3. Title එක ලිවීම
      double yPos = 0; // උඩ ඉඳන් පහළට දුර (Cursor position වගේ)

      if (_titleController.text.isNotEmpty) {
        page.graphics.drawString(
          _titleController.text,
          titleFont,
          brush: brush,
          bounds: Rect.fromLTWH(0, yPos, page.getClientSize().width, 50),
          format: PdfStringFormat(alignment: PdfTextAlignment.center), // මැදට
        );
        yPos += 50; // ඊළඟ පේළියට ඉඩ තියනවා
      }

      // ඉරක් ගහනවා Title එකට යටින් (Optional)
      page.graphics.drawLine(
        PdfPen(PdfColor(200, 200, 200), width: 1),
        Offset(0, yPos),
        Offset(page.getClientSize().width, yPos)
      );
      yPos += 20; // තව පොඩි ඉඩක්

      // 4. Body එක ලිවීම (දිග Text එකක් වුනත් පිටුවෙන් පිටුවට යන්න හදනවා)
      // Syncfusion එකේදි දිග Text එකක් ඉබේම කඩලා ලියන්න 'PdfTextElement' පාවිච්චි කරනවා.
      PdfTextElement textElement = PdfTextElement(
        text: _bodyController.text,
        font: bodyFont,
        brush: brush,
      );

      // Layout එක හදනවා (මේකෙන් තමයි පිටුව ඉවර වුනාම අලුත් පිටුවක් ඉබේම ගන්නේ)
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
        // Input Fields සුද්ද කරනවා (Optional)
        // _titleController.clear();
        // _bodyController.clear();
        
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
      appBar: AppBar(
        title: const Text("Text to PDF"),
        actions: [
          // Clear Button
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: "Clear Text",
            onPressed: () {
              _titleController.clear();
              _bodyController.clear();
            },
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // --- Title Input ---
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: "Document Title",
                hintText: "Enter a topic...",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.title),
              ),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 20),

            // --- Body Input (Expanded) ---
            Expanded(
              child: TextField(
                controller: _bodyController,
                keyboardType: TextInputType.multiline,
                maxLines: null, // ඕන තරම් පේළි ගහන්න පුළුවන්
                textAlignVertical: TextAlignVertical.top, // අකුරු උඩින් පටන් ගන්නවා
                decoration: const InputDecoration(
                  labelText: "Content",
                  hintText: "Type your notes here...",
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true, // Label එක උඩට ගන්නවා
                ),
                style: const TextStyle(fontSize: 16),
              ),
            ),
            const SizedBox(height: 20),

            // --- Generate Button ---
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _isGenerating ? null : _generatePdf,
                icon: _isGenerating
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.picture_as_pdf),
                label: Text(
                  _isGenerating ? "Creating PDF..." : "Create PDF",
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}