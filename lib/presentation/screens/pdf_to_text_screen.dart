import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdfx/pdfx.dart' as pdfx; 
import 'package:syncfusion_flutter_pdf/pdf.dart' as syncfusion; 
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import 'package:love_pdf/presentation/screens/pdf_preview_screen.dart';

class PdfToTextScreen extends StatefulWidget {
  const PdfToTextScreen({super.key});

  @override
  State<PdfToTextScreen> createState() => _PdfToTextScreenState();
}

class _PdfToTextScreenState extends State<PdfToTextScreen> {
  String? _filePath;
  String? _fileName;
  pdfx.PdfDocument? _visualPdfDoc;
  syncfusion.PdfDocument? _extractionPdfDoc;
  List<Uint8List?> _pageThumbnails = [];
  bool _isLoading = false;

  Future<void> _pickPdf() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _filePath = result.files.single.path!;
        _fileName = result.files.single.name.replaceAll('.pdf', '');
        _isLoading = true;
        _pageThumbnails = [];
      });
      _loadPdfData();
    }
  }

  Future<void> _loadPdfData() async {
    try {
      _visualPdfDoc = await pdfx.PdfDocument.openFile(_filePath!);
      int pageCount = _visualPdfDoc!.pagesCount;
      
      final File file = File(_filePath!);
      final List<int> bytes = await file.readAsBytes();
      _extractionPdfDoc = syncfusion.PdfDocument(inputBytes: bytes);

      setState(() {
        _pageThumbnails = List.filled(pageCount, null);
      });

      for (int i = 1; i <= pageCount; i++) {
        if (!mounted) break;
        final page = await _visualPdfDoc!.getPage(i);
        final pageImage = await page.render(
          width: 200, height: 300, format: pdfx.PdfPageImageFormat.png,
        );
        await page.close();

        if (mounted && pageImage != null) {
          setState(() {
            _pageThumbnails[i - 1] = pageImage.bytes;
          });
        }
        await Future.delayed(const Duration(milliseconds: 10));
      }
      setState(() => _isLoading = false);
    } catch (e) {
      debugPrint("Error: $e");
      setState(() => _isLoading = false);
    }
  }

  // 🔥 UPDATED: 1st Line එක තියලා, මැදට Space එකක් දෙනවා
  String _cleanText(String text) {
    if (text.isEmpty) return "";

    // 1. Text එක පේළි වලට කඩනවා
    List<String> lines = text.split(RegExp(r'\r?\n'));

    // 2. හිස් පේළි අයින් කරනවා
    lines.removeWhere((line) => line.trim().isEmpty);

    if (lines.isEmpty) return "";

    // 3. පළවෙනි පේළිය (Header) වෙන් කරගන්නවා
    String heading = lines[0].trim();

    // 4. ඉතුරු ටික (Body) එකතු කරලා Paragraph එකක් කරනවා
    String body = "";
    if (lines.length > 1) {
      // ඉතුරු පේළි ටික එකතු කරනවා (Newlines වෙනුවට Spaces දාලා)
      body = lines.sublist(1).join(" ");
      
      // අනවශ්‍ය Symbols අයින් කරනවා
      body = body.replaceAll(RegExp(r'\s+'), ' ').trim(); 
      body = body.replaceAll('- ', ''); // Hyphenation fix
    }

    // 5. Header එකයි Body එකයි එකතු කරනවා (මැදට Newlines 2ක් දාලා)
    if (body.isNotEmpty) {
      return "$heading\n\n$body";
    } else {
      return heading;
    }
  }

  void _openPageEditor(int pageIndex) {
    if (_extractionPdfDoc == null) return;

    String extractedText = "";
    try {
      extractedText = syncfusion.PdfTextExtractor(_extractionPdfDoc!)
          .extractText(startPageIndex: pageIndex, endPageIndex: pageIndex);
    } catch (e) {
      extractedText = "Error extracting text.";
    }

    if (extractedText.trim().isEmpty) {
      extractedText = "[No selectable text found]";
    } else {
      // Clean කරනවා
      extractedText = _cleanText(extractedText);
    }

    showDialog(
      context: context,
      barrierDismissible: false, 
      builder: (context) => _PageTextEditorDialog(
        initialText: extractedText,
        pageIndex: pageIndex,
        originalFileName: _fileName ?? "Doc",
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true, 
      appBar: AppBar(
        title: const Text("PDF to Text", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        actions: [
          if (_filePath != null)
            IconButton(
              icon: const Icon(Icons.upload_file, color: Colors.amberAccent),
              onPressed: _pickPdf,
              tooltip: "Pick New PDF",
            )
        ],
      ),
      body: Container(
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
                child: _filePath == null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(35),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.05),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white.withOpacity(0.1)),
                                boxShadow: [BoxShadow(color: Colors.amberAccent.withOpacity(0.2), blurRadius: 20, spreadRadius: 5)]
                              ),
                              child: const Icon(Icons.text_snippet, size: 80, color: Colors.amberAccent),
                            ),
                            const SizedBox(height: 40),
                            const Text("PDF to Text", style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white)),
                            const SizedBox(height: 15),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 40),
                              child: Text("Extract editable text from your PDF documents instantly.", textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: Colors.white70, height: 1.5)),
                            ),
                            const SizedBox(height: 60),
                            SizedBox(
                              width: 250, height: 55,
                              child: ElevatedButton.icon(
                                onPressed: _pickPdf,
                                icon: const Icon(Icons.folder_open),
                                label: const Text("Select PDF File"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color.fromARGB(204, 237, 237, 19), foregroundColor: const Color.fromARGB(255, 255, 253, 253), elevation: 8,
                                  textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                                ),
                              ),
                            )
                          ],
                        ),
                      )
                    : (_isLoading && _pageThumbnails.every((e) => e == null))
                        ? const Center(child: CircularProgressIndicator(color: Colors.white))
                        : GridView.builder(
                            padding: const EdgeInsets.all(15),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3, childAspectRatio: 0.7, crossAxisSpacing: 15, mainAxisSpacing: 15,
                            ),
                            itemCount: _pageThumbnails.length,
                            itemBuilder: (context, index) {
                              final imageBytes = _pageThumbnails[index];
                              return GestureDetector(
                                onTap: () => _openPageEditor(index),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                                  ),
                                  child: Stack(
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: imageBytes != null
                                              ? Image.memory(imageBytes, fit: BoxFit.contain, width: double.infinity, height: double.infinity)
                                              : const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))),
                                        ),
                                      ),
                                      Positioned(
                                        top: 5, left: 5,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(color: Colors.black.withOpacity(0.7), borderRadius: BorderRadius.circular(4)),
                                          child: Text("${index + 1}", style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                        ),
                                      ),
                                      Positioned(
                                        bottom: 5, right: 5,
                                        child: Container(
                                          padding: const EdgeInsets.all(5),
                                          decoration: BoxDecoration(color: Colors.amberAccent.withOpacity(0.8), shape: BoxShape.circle),
                                          child: const Icon(Icons.edit, size: 14, color: Colors.black),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PageTextEditorDialog extends StatefulWidget {
  final String initialText;
  final int pageIndex;
  final String originalFileName;

  const _PageTextEditorDialog({
    required this.initialText,
    required this.pageIndex,
    required this.originalFileName,
  });

  @override
  State<_PageTextEditorDialog> createState() => _PageTextEditorDialogState();
}

class _PageTextEditorDialogState extends State<_PageTextEditorDialog> {
  late TextEditingController _bodyController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _bodyController = TextEditingController(text: widget.initialText);
  }

  void _copyText() {
    Clipboard.setData(ClipboardData(text: _bodyController.text));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Copied to Clipboard!")));
  }

  Future<void> _saveAsTextFile() async {
    setState(() => _isSaving = true);

    try {
      Directory? directory;
      if (Platform.isAndroid) {
        directory = Directory('/storage/emulated/0/Download');
      } else {
        directory = await getDownloadsDirectory();
      }
      
      if (directory == null || !directory.existsSync()) {
        directory = await getApplicationDocumentsDirectory();
      }

      String finalContent = _bodyController.text;

      final fileName = "${widget.originalFileName}_Page${widget.pageIndex + 1}.txt";
      final path = '${directory.path}/$fileName';
      final File file = File(path);

      await file.writeAsString(finalContent);

      if (mounted) {
        setState(() => _isSaving = false);
        Navigator.pop(context); 
        
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Saved as Text File!"),
            content: Text("File saved to Downloads:\n\n$fileName"),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK")),
            ],
          ),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(15),
      backgroundColor: const Color(0xFF1E2F38), 
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Container(
        padding: const EdgeInsets.all(15),
        height: MediaQuery.of(context).size.height * 0.7, 
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Edit Page ${widget.pageIndex + 1}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                IconButton(icon: const Icon(Icons.close, color: Colors.white70), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const Divider(color: Colors.white24),
            
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white.withOpacity(0.3)),
                  borderRadius: BorderRadius.circular(5),
                  color: Colors.black12,
                ),
                child: TextField(
                  controller: _bodyController,
                  maxLines: null,
                  expands: true,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: "Content goes here...",
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                    contentPadding: const EdgeInsets.all(10),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 15),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: _copyText,
                  icon: const Icon(Icons.copy, size: 20, color: Colors.amberAccent),
                  label: const Text("Copy Text", style: TextStyle(color: Colors.amberAccent)),
                ),
                
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.amberAccent, foregroundColor: Colors.black),
                  onPressed: _isSaving ? null : _saveAsTextFile, 
                  icon: _isSaving 
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black)) 
                      : const Icon(Icons.description, size: 18), 
                  label: Text(_isSaving ? "Saving..." : "Save as .txt"),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}