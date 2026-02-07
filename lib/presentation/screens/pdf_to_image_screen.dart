import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdfx/pdfx.dart' as pdfx; 
import 'package:path_provider/path_provider.dart';

class PdfToImageScreen extends StatefulWidget {
  const PdfToImageScreen({super.key});

  @override
  State<PdfToImageScreen> createState() => _PdfToImageScreenState();
}

class _PdfToImageScreenState extends State<PdfToImageScreen> {
  String? _filePath;
  String? _fileName; // PDF එකේ නම මතක තියාගන්න variable එක
  pdfx.PdfDocument? _pdfDocument;
  int _totalPages = 0;
  
  final Set<int> _selectedIndices = {}; 
  List<Uint8List?> _pageThumbnails = [];
  
  bool _isLoading = false;
  bool _isSaving = false;

  // 1. PDF එක තෝරාගැනීම (නම ලබා ගැනීමත් සමඟ)
  Future<void> _pickPdf() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null && result.files.single.path != null) {
      // PDF එකේ නම ගන්නවා (extension එක නැතුව)
      String originalName = result.files.single.name;
      String cleanName = originalName.replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '');
      // නමේ හිස්තැන් (spaces) තිබේ නම් ඒවා underscore (_) කරන්න (Optional - ෆයිල් වලට හොඳ නිසා)
      cleanName = cleanName.replaceAll(' ', '_');

      setState(() {
        _filePath = result.files.single.path!;
        _fileName = cleanName; // නම සේව් කරගන්නවා
        _isLoading = true;
        _selectedIndices.clear(); 
      });
      _loadPdf();
    }
  }

  // 2. PDF එක Load කර Thumbnails හදාගැනීම
  Future<void> _loadPdf() async {
    try {
      _pdfDocument = await pdfx.PdfDocument.openFile(_filePath!);
      _totalPages = _pdfDocument!.pagesCount;
      
      for (int i = 0; i < _totalPages; i++) {
        _selectedIndices.add(i);
      }

      setState(() {
        _pageThumbnails = List.filled(_totalPages, null);
      });

      for (int i = 1; i <= _totalPages; i++) {
        if (!mounted) break;
        final page = await _pdfDocument!.getPage(i);
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
      debugPrint("Error loading PDF: $e");
      setState(() => _isLoading = false);
    }
  }

  // 3. Images Save කිරීම (PDF නම + කෙලින්ම Downloads වෙත)
  Future<void> _saveAsImages() async {
    if (_selectedIndices.isEmpty || _pdfDocument == null) return;
    
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

      // අගට Timestamp එකක් දානවා පරණ ඒව මැකෙන එක නවත්තන්න
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      
      int savedCount = 0;

      for (int index in _selectedIndices) {
        final page = await _pdfDocument!.getPage(index + 1);
        final pageImage = await page.render(
          width: page.width * 2, 
          height: page.height * 2,
          format: pdfx.PdfPageImageFormat.png, 
        );
        await page.close();

        if (pageImage != null) {
          // Format: [PDF_NAME]_Page_[NO]_[TIMESTAMP].png
          // උදා: Science_Report_Page_1_17233...png
          String finalName = "${_fileName ?? 'PDF'}_Page_${index + 1}_$timestamp.png";
          
          final File file = File('${directory.path}/$finalName');
          
          await file.writeAsBytes(pageImage.bytes);
          savedCount++;
        }
      }

      setState(() => _isSaving = false);

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Saved to Downloads!"),
            content: Text("$savedCount images saved.\n\nFiles usually start with '${_fileName ?? 'PDF'}_Page...'"),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text("PDF to Image"),
        actions: [
           if (_filePath != null)
             IconButton(
               icon: const Icon(Icons.upload_file),
               tooltip: "Pick new PDF",
               onPressed: _pickPdf,
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
                    Icon(Icons.image_search, size: 80, color: Colors.grey[300]),
                    const SizedBox(height: 20),
                    const Text("Convert PDF Pages to Images"),
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

          // --- GRID VIEW ---
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
                itemCount: _totalPages,
                itemBuilder: (context, index) {
                  final isSelected = _selectedIndices.contains(index);
                  final imageBytes = _pageThumbnails[index];

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
                            border: isSelected 
                              ? Border.all(color: Colors.blue, width: 3) 
                              : Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(8),
                            color: Colors.grey[100],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(5),
                            child: imageBytes != null
                                ? Image.memory(imageBytes, fit: BoxFit.contain)
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
                          const Positioned(
                            top: 5, right: 5,
                            child: CircleAvatar(
                              radius: 10,
                              backgroundColor: Colors.blue,
                              child: Icon(Icons.check, size: 14, color: Colors.white),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),

          // --- SAVE BUTTON ---
          if (_filePath != null)
            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
                  onPressed: _isSaving || _selectedIndices.isEmpty ? null : _saveAsImages,
                  icon: _isSaving 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.save_alt),
                  label: Text(_isSaving ? "Saving Images..." : "Save Selected Images"),
                ),
              ),
            ),
        ],
      ),
    );
  }
}