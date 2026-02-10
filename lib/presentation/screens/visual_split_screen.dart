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
  bool _isSaving = false;
  int _totalPages = 0;
  
  List<Uint8List?> _pageImages = [];

  @override
  void initState() {
    super.initState();
    _initPdf();
  }

  Future<void> _initPdf() async {
    try {
      _pdfDocument = await pdfx.PdfDocument.openFile(widget.filePath);
      _totalPages = _pdfDocument.pagesCount;

      setState(() {
        _pageImages = List.filled(_totalPages, null);
        _isInitLoading = false;
      });

      _generateThumbnails();
    } catch (e) {
      debugPrint("Error loading PDF: $e");
    }
  }

  Future<void> _generateThumbnails() async {
    for (int i = 1; i <= _totalPages; i++) {
      if (!mounted) break;
      
      try {
        final page = await _pdfDocument.getPage(i);
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
        await Future.delayed(const Duration(milliseconds: 10)); 
      } catch (e) {
        debugPrint("Error rendering page $i: $e");
      }
    }
  }

  // --- SAVE LOGIC (Same as before) ---
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
    // පාට වෙනස් කළා Dark Theme එකට කැපී පේන්න
    Color activeColor = widget.mode == SplitMode.keep ? const Color(0xFF00E676) : const Color(0xFFFF5252);

    return Scaffold(
      extendBodyBehindAppBar: true, // Gradient එක උඩටම යන්න
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: const Color(0xFF0F2027).withOpacity(0.9), // අඳුරු පසුබිම
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
      ),
      body: Container(
        // Dark Theme Gradient Background
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
        child: _isInitLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : SafeArea(
                child: Column(
                  children: [
                    // Grid View එක
                    Expanded(
                      child: GridView.builder(
                        padding: const EdgeInsets.all(15),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 0.7,
                          crossAxisSpacing: 15,
                          mainAxisSpacing: 15,
                        ),
                        itemCount: _totalPages,
                        itemBuilder: (context, index) {
                          bool isSelected = _selectedIndices.contains(index);
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
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              decoration: BoxDecoration(
                                // Select වුණාම පාට වෙනස් වෙනවා
                                border: isSelected 
                                    ? Border.all(color: activeColor, width: 3) 
                                    : Border.all(color: Colors.white.withOpacity(0.2), width: 1),
                                borderRadius: BorderRadius.circular(12),
                                color: isSelected ? activeColor.withOpacity(0.2) : Colors.white.withOpacity(0.05),
                              ),
                              child: Stack(
                                children: [
                                  // PDF Image
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(9),
                                    child: imageBytes != null
                                        ? Image.memory(
                                            imageBytes,
                                            fit: BoxFit.contain,
                                            width: double.infinity,
                                            height: double.infinity,
                                          )
                                        : const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))),
                                  ),
                                  
                                  // Page Number Tag
                                  Positioned(
                                    top: 5,
                                    left: 5,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.7),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        "${index + 1}",
                                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),

                                  // Checkbox Icon (Select වුණාම පේනවා)
                                  if (isSelected)
                                    Positioned(
                                      top: 5,
                                      right: 5,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: activeColor,
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 4)
                                          ]
                                        ),
                                        padding: const EdgeInsets.all(4),
                                        child: const Icon(Icons.check, size: 14, color: Colors.black),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    // Bottom Button Section
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F2027).withOpacity(0.9), // යට බාර් එකේ පාට
                        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: activeColor,
                            foregroundColor: Colors.black, // අකුරු කලු පාටයි (Green/Red උඩ හොඳට පේනවා)
                            elevation: 5,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          ),
                          onPressed: _isSaving ? null : _processAndSave,
                          child: _isSaving 
                              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                              : Text(
                                  widget.mode == SplitMode.keep ? "Extract Selected Pages" : "Delete Selected Pages",
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                        ),
                      ),
                    )
                  ],
                ),
              ),
      ),
    );
  }
}