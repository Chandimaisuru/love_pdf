import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdfx/pdfx.dart' as pdfx; // Preview පින්තූර පෙන්වන්න
import 'package:syncfusion_flutter_pdf/pdf.dart' as syncfusion; // Text ගන්න
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import 'package:love_pdf/presentation/screens/pdf_preview_screen.dart';

class PdfToTextScreen extends StatefulWidget {
  const PdfToTextScreen({super.key});

  @override
  State<PdfToTextScreen> createState() => _PdfToTextScreenState();
}

class _PdfToTextScreenState extends State<PdfToTextScreen> {
  // Visual Preview සඳහා
  String? _filePath;
  String? _fileName;
  pdfx.PdfDocument? _visualPdfDoc;
  
  // Text Extraction සඳහා
  syncfusion.PdfDocument? _extractionPdfDoc;
  
  List<Uint8List?> _pageThumbnails = [];
  bool _isLoading = false;

  // 1. PDF එක තෝරාගැනීම
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

  // 2. PDF එක Load කිරීම (Visual & Text Data)
  Future<void> _loadPdfData() async {
    try {
      // A. Visual Thumbnails සඳහා Load කිරීම
      _visualPdfDoc = await pdfx.PdfDocument.openFile(_filePath!);
      int pageCount = _visualPdfDoc!.pagesCount;
      
      // B. Text Extraction සඳහා Syncfusion Load කිරීම (Memory එකට)
      final File file = File(_filePath!);
      final List<int> bytes = await file.readAsBytes();
      _extractionPdfDoc = syncfusion.PdfDocument(inputBytes: bytes);

      setState(() {
        _pageThumbnails = List.filled(pageCount, null);
      });

      // Thumbnails හදනවා (Grid එකට)
      for (int i = 1; i <= pageCount; i++) {
        if (!mounted) break;
        final page = await _visualPdfDoc!.getPage(i);
        final pageImage = await page.render(
          width: 200, 
          height: 300, 
          format: pdfx.PdfPageImageFormat.png,
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

  // 3. තෝරාගත් පිටුවේ Text එක Edit කරන Dialog එක open කිරීම
  void _openPageEditor(int pageIndex) {
    if (_extractionPdfDoc == null) return;

    // අදාළ පිටුවේ Text එක Extract කරනවා
    String extractedText = "";
    try {
      extractedText = syncfusion.PdfTextExtractor(_extractionPdfDoc!)
          .extractText(startPageIndex: pageIndex, endPageIndex: pageIndex);
    } catch (e) {
      extractedText = "Error extracting text.";
    }

    if (extractedText.trim().isEmpty) {
      extractedText = "[No selectable text found on this page. It might be an image.]";
    }

    // Editor එක Open කරනවා
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
      appBar: AppBar(
        title: const Text("Tap Page to Edit Text"),
        actions: [
          if (_filePath != null)
            IconButton(
              icon: const Icon(Icons.upload_file),
              onPressed: _pickPdf,
              tooltip: "Pick New PDF",
            )
        ],
      ),
      body: Column(
        children: [
          // --- EMPTY STATE ---
          if (_filePath == null)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.touch_app, size: 80, color: Colors.grey[300]),
                    const SizedBox(height: 20),
                    const Text("Tap a page to extract & edit text"),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: _pickPdf,
                      icon: const Icon(Icons.folder_open),
                      label: const Text("Select PDF"),
                    ),
                  ],
                ),
              ),
            )
          
          // --- LOADING ---
          else if (_isLoading && _pageThumbnails.every((e) => e == null))
            const Expanded(child: Center(child: CircularProgressIndicator()))

          // --- GRID VIEW (PREVIEW) ---
          else
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(10),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 0.7,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: _pageThumbnails.length,
                itemBuilder: (context, index) {
                  final imageBytes = _pageThumbnails[index];
                  return GestureDetector(
                    onTap: () => _openPageEditor(index), // Click කළාම Editor එක එනවා
                    child: Stack(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(8),
                            color: Colors.grey[100],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(5),
                            child: imageBytes != null
                                ? Image.memory(imageBytes, fit: BoxFit.contain, width: double.infinity, height: double.infinity)
                                : const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
                          ),
                        ),
                        // Page Number Badge
                        Positioned(
                          top: 5, left: 5,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)),
                            child: Text("${index + 1}", style: const TextStyle(color: Colors.white, fontSize: 10)),
                          ),
                        ),
                        // Edit Icon Overlay
                        Positioned.fill(
                          child: Container(
                            color: Colors.transparent,
                            child: const Center(
                              child: Icon(Icons.edit, color: Colors.white54, size: 30),
                            ),
                          ),
                        )
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

// --- වෙන් කරපු EDITOR Dialog එක (Manual Control) ---
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
  late TextEditingController _titleController;
  late TextEditingController _bodyController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // === MANUAL LOGIC ===
    // Heading එක හිස්ව තබන්න.
    // මුළු Text එකම Body එකට දාන්න.
    // User ට අවශ්‍ය නම් Cut-Paste කරගන්න පුළුවන්.
    _titleController = TextEditingController(text: ""); 
    _bodyController = TextEditingController(text: widget.initialText);
  }

  // Copy Function
  void _copyText() {
    Clipboard.setData(ClipboardData(text: "${_titleController.text}\n\n${_bodyController.text}"));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Copied to Clipboard!")));
  }

  // Save as PDF Function
  Future<void> _saveAsPdf() async {
    setState(() => _isSaving = true);

    try {
      final syncfusion.PdfDocument document = syncfusion.PdfDocument();
      final syncfusion.PdfPage page = document.pages.add();

      // Fonts Definition
      final syncfusion.PdfFont titleFont = syncfusion.PdfStandardFont(
        syncfusion.PdfFontFamily.helvetica, 24, style: syncfusion.PdfFontStyle.bold
      );
      final syncfusion.PdfFont bodyFont = syncfusion.PdfStandardFont(
        syncfusion.PdfFontFamily.helvetica, 12
      );
      final syncfusion.PdfBrush brush = syncfusion.PdfSolidBrush(syncfusion.PdfColor(0, 0, 0));
      
      double yPos = 0;

      // 1. Heading එක ලියන්නේ User විසින් Type කරොත් විතරයි
      if (_titleController.text.trim().isNotEmpty) {
        page.graphics.drawString(
          _titleController.text,
          titleFont,
          brush: brush,
          bounds: Rect.fromLTWH(0, yPos, page.getClientSize().width, 60),
          format: syncfusion.PdfStringFormat(alignment: syncfusion.PdfTextAlignment.center), // Center Heading
        );
        yPos += 50;
        
        // ඉරක් ගහනවා Title යටින්
        page.graphics.drawLine(
          syncfusion.PdfPen(syncfusion.PdfColor(200, 200, 200)),
          Offset(20, yPos),
          Offset(page.getClientSize().width - 20, yPos)
        );
        yPos += 20;
      }

      // 2. Body එක ලිවීම (Multi-line text handling)
      syncfusion.PdfTextElement(
        text: _bodyController.text, 
        font: bodyFont,
        brush: brush
      ).draw(
        page: page,
        bounds: Rect.fromLTWH(0, yPos, page.getClientSize().width, page.getClientSize().height - yPos),
      );

      // Save File
      final dir = await getApplicationDocumentsDirectory();
      // නම: OriginalName_PageX_Edited.pdf
      final fileName = "${widget.originalFileName}_Page${widget.pageIndex + 1}_Edited.pdf";
      final path = '${dir.path}/$fileName';

      await File(path).writeAsBytes(await document.save());
      document.dispose();

      if (mounted) {
        setState(() => _isSaving = false);
        Navigator.pop(context); // Close Dialog
        Navigator.push(context, MaterialPageRoute(builder: (_) => PdfPreviewScreen(filePath: path, fileName: fileName)));
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Container(
        padding: const EdgeInsets.all(15),
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Edit Page ${widget.pageIndex + 1}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const Divider(),
            
            // --- Heading Input (හිස්ව පවතී) ---
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: "Heading (Optional - Type here to make Bold)",
                hintText: "Cut text from body and paste here if needed...",
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                prefixIcon: Icon(Icons.title),
                filled: true,
                fillColor: Colors.white,
              ),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 10),

            // --- Body Input (මුළු Text එකම මෙතන) ---
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(5),
                  color: Colors.grey[50],
                ),
                child: TextField(
                  controller: _bodyController,
                  maxLines: null,
                  expands: true,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: "Content goes here...",
                    contentPadding: EdgeInsets.all(10),
                  ),
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: _copyText,
                  icon: const Icon(Icons.copy, size: 20),
                  label: const Text("Copy All"),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                  onPressed: _isSaving ? null : _saveAsPdf,
                  icon: _isSaving 
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) 
                      : const Icon(Icons.save, size: 18),
                  label: Text(_isSaving ? "Saving..." : "Save PDF"),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}