import 'dart:io';
import 'dart:typed_data'; // Image data සඳහා
import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart' as pdfx; 
import 'package:syncfusion_flutter_pdf/pdf.dart' as syncfusion; 
import 'package:path_provider/path_provider.dart';
import 'package:love_pdf/presentation/screens/pdf_preview_screen.dart';

enum SplitMode { keep, remove }

class VisualSplitScreen extends StatefulWidget {
  final String filePath;
  final SplitMode mode;

  const VisualSplitScreen({super.key, required this.filePath, required this.mode});

  @override
  State<VisualSplitScreen> createState() => _VisualSplitScreenState();
}

class _VisualSplitScreenState extends State<VisualSplitScreen> {
  late pdfx.PdfDocument _pdfDocument;
  final Set<int> _selectedIndices = {};
  bool _isInitLoading = true;
  bool _isSaving = false; // Save වෙනකොට පෙන්වන්න
  int _totalPages = 0;
  
  // පින්තූර ටික Store කරගන්න List එකක් (Cache)
  List<Uint8List?> _pageImages = [];

  @override
  void initState() {
    super.initState();
    _initPdf();
  }

  // 1. PDF එක Open කරලා, එකෙන් එක Images හදනවා
  Future<void> _initPdf() async {
    try {
      _pdfDocument = await pdfx.PdfDocument.openFile(widget.filePath);
      _totalPages = _pdfDocument.pagesCount;

      // මුලින් හිස් List එකක් හදාගන්නවා
      setState(() {
        _pageImages = List.filled(_totalPages, null);
        _isInitLoading = false;
      });

      // ඊට පස්සේ හිමින් සැරේ එකෙන් එක පින්තූර Load කරනවා (Background Process)
      _generateThumbnails();

    } catch (e) {
      debugPrint("Error loading PDF: $e");
    }
  }

  // එකවරක් එක පිටුව බැගින් Load කරන Function එක (මේක නිසා හිර වෙන්නේ නෑ)
  Future<void> _generateThumbnails() async {
    for (int i = 1; i <= _totalPages; i++) {
      if (!mounted) break; // Screen එකෙන් එළියට ගිහින් නම් නවත්තනවා
      
      try {
        final page = await _pdfDocument.getPage(i);
        // Resolution එක අඩු කළා (Width: 200) ඉක්මනට එන්න
        final pageImage = await page.render(
          width: 200, 
          height: 300, 
          format: pdfx.PdfPageImageFormat.png,
        );
        await page.close();

        if (mounted && pageImage != null) {
          setState(() {
            _pageImages[i - 1] = pageImage.bytes;
          });
        }
        // පොඩි විරාමයක් දෙනවා UI එක හිර නොවෙන්න
        await Future.delayed(const Duration(milliseconds: 10)); 
      } catch (e) {
        debugPrint("Error rendering page $i: $e");
      }
    }
  }

  // --- SAVE LOGIC ---
  Future<void> _processAndSave() async {
    if (_selectedIndices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select at least one page.")));
      return;
    }

    setState(() => _isSaving = true);

    try {
      final File inputFile = File(widget.filePath);
      final List<int> inputBytes = await inputFile.readAsBytes();
      final syncfusion.PdfDocument inputDocument = syncfusion.PdfDocument(inputBytes: inputBytes);
      
      final syncfusion.PdfDocument outputDocument = syncfusion.PdfDocument();
      outputDocument.pageSettings.margins.all = 0;

      List<int> pagesToInclude = [];

      for (int i = 0; i < inputDocument.pages.count; i++) {
        bool isSelected = _selectedIndices.contains(i);
        if (widget.mode == SplitMode.keep) {
          if (isSelected) pagesToInclude.add(i);
        } else {
          if (!isSelected) pagesToInclude.add(i);
        }
      }

      if (pagesToInclude.isEmpty) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Resulting PDF would be empty!")));
        return;
      }

      for (int index in pagesToInclude) {
        syncfusion.PdfTemplate template = inputDocument.pages[index].createTemplate();
        Size pageSize = inputDocument.pages[index].getClientSize();
        
        outputDocument.pageSettings.size = pageSize;
        outputDocument.pageSettings.orientation = 
            pageSize.width > pageSize.height ? syncfusion.PdfPageOrientation.landscape : syncfusion.PdfPageOrientation.portrait;

        outputDocument.pages.add().graphics.drawPdfTemplate(template, const Offset(0, 0));
      }

      final dir = await getApplicationDocumentsDirectory();
      final fileName = 'Split_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final path = '${dir.path}/$fileName';
      
      await File(path).writeAsBytes(await outputDocument.save());
      
      inputDocument.dispose();
      outputDocument.dispose();

      if (mounted) {
        setState(() => _isSaving = false);
        Navigator.push(context, MaterialPageRoute(builder: (_) => PdfPreviewScreen(filePath: path, fileName: fileName)));
      }

    } catch (e) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    String title = widget.mode == SplitMode.keep ? "Select Pages to KEEP" : "Select Pages to REMOVE";
    Color activeColor = widget.mode == SplitMode.keep ? Colors.green : Colors.red;

    return Scaffold(
      appBar: AppBar(title: Text(title, style: const TextStyle(fontSize: 16))),
      body: _isInitLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                Column(
                  children: [
                    Expanded(
                      child: GridView.builder(
                        padding: const EdgeInsets.all(10),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 0.7,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                        itemCount: _totalPages,
                        itemBuilder: (context, index) {
                          bool isSelected = _selectedIndices.contains(index);
                          // කලින් Load කරපු Image List එකෙන් පින්තූරය ගන්නවා
                          final imageBytes = _pageImages[index];

                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                if (isSelected) {
                                  _selectedIndices.remove(index);
                                } else {
                                  _selectedIndices.add(index);
                                }
                              });
                            },
                            child: Stack(
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    border: isSelected ? Border.all(color: activeColor, width: 3) : Border.all(color: Colors.grey[300]!),
                                    borderRadius: BorderRadius.circular(8),
                                    color: Colors.grey[100],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(5),
                                    child: imageBytes != null
                                        ? Image.memory(
                                            imageBytes,
                                            fit: BoxFit.contain,
                                            width: double.infinity,
                                            height: double.infinity,
                                          )
                                        : const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
                                  ),
                                ),
                                Positioned(
                                  top: 5, left: 5,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)),
                                    child: Text("${index + 1}", style: const TextStyle(color: Colors.white, fontSize: 10)),
                                  ),
                                ),
                                if (isSelected)
                                  Positioned(
                                    top: 5, right: 5,
                                    child: CircleAvatar(
                                      radius: 10,
                                      backgroundColor: activeColor,
                                      child: const Icon(Icons.check, size: 14, color: Colors.white),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: activeColor, foregroundColor: Colors.white),
                          onPressed: _isSaving ? null : _processAndSave,
                          child: Text(_isSaving ? "Processing..." : (widget.mode == SplitMode.keep ? "Extract Selected" : "Delete Selected")),
                        ),
                      ),
                    )
                  ],
                ),
                // Loading Overlay (Save වෙනකොට)
                if (_isSaving)
                  Container(
                    color: Colors.black54,
                    child: const Center(child: CircularProgressIndicator(color: Colors.white)),
                  )
              ],
            ),
    );
  }
}