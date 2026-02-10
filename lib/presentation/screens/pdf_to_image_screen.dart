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
      // PDF එකේ නම ගන්නවා
      String originalName = result.files.single.name;
      String cleanName = originalName.replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '');
      cleanName = cleanName.replaceAll(' ', '_');

      setState(() {
        _filePath = result.files.single.path!;
        _fileName = cleanName;
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
      
      // Default විදිහට ඔක්කොම Select කරනවා (User ට ලේසි වෙන්න)
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

  // 3. Images Save කිරීම
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
            title: const Text("Saved to Downloads!", style: TextStyle(color: Colors.indigo)),
            content: Text("$savedCount images saved.\n\nFiles usually start with '${_fileName ?? 'PDF'}_Page...'"),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK", style: TextStyle(color: Colors.indigo))),
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
      extendBodyBehindAppBar: true, // Gradient එක උඩටම යවන්න
      appBar: AppBar(
        title: const Text("PDF to Image", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent, // Transparent
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        actions: [
           if (_filePath != null)
             IconButton(
               icon: const Icon(Icons.upload_file, color: Colors.indigoAccent),
               tooltip: "Pick new PDF",
               onPressed: _pickPdf,
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
              // --- Main Content ---
              Expanded(
                // 👇👇👇 NEW LANDING PAGE 👇👇👇
                child: _filePath == null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // 1. Icon Container with Glow
                            Container(
                              padding: const EdgeInsets.all(35),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.05), // Glass Effect
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white.withOpacity(0.1)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.indigoAccent.withOpacity(0.2), // Indigo Glow
                                    blurRadius: 20,
                                    spreadRadius: 5,
                                  )
                                ]
                              ),
                              child: const Icon(Icons.image_search, size: 80, color: Colors.indigoAccent),
                            ),
                            const SizedBox(height: 40),
                            
                            // 2. Title
                            const Text(
                              "PDF to Image",
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 15),
                            
                            // 3. Description
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 40),
                              child: Text(
                                "Convert PDF pages into high-quality images and save them to your gallery.",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.white70,
                                  height: 1.5,
                                ),
                              ),
                            ),
                            const SizedBox(height: 60),

                            // 4. Action Button
                            SizedBox(
                              width: 250,
                              height: 55,
                              child: ElevatedButton.icon(
                                onPressed: _pickPdf,
                                icon: const Icon(Icons.folder_open),
                                label: const Text("Select PDF File"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.indigoAccent, // Indigo Button
                                  foregroundColor: Colors.white,
                                  elevation: 8,
                                  textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                ),
                              ),
                            )
                          ],
                        ),
                      )
                  
                  // 👇👇👇 LOADING STATE 👇👇👇
                  : (_isLoading && _pageThumbnails.every((e) => e == null))
                    ? const Center(child: CircularProgressIndicator(color: Colors.white))

                  // 👇👇👇 GRID VIEW (Glass Effect) 👇👇👇
                    : GridView.builder(
                        padding: const EdgeInsets.all(15),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 0.7,
                          crossAxisSpacing: 15,
                          mainAxisSpacing: 15,
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
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              decoration: BoxDecoration(
                                // Selection Border (Indigo)
                                border: isSelected 
                                  ? Border.all(color: Colors.indigoAccent, width: 3) 
                                  : Border.all(color: Colors.white.withOpacity(0.1)),
                                borderRadius: BorderRadius.circular(12),
                                // Glass Background
                                color: isSelected 
                                  ? Colors.indigoAccent.withOpacity(0.2) 
                                  : Colors.white.withOpacity(0.08),
                              ),
                              child: Stack(
                                children: [
                                  // Thumbnail Image
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
                                    top: 5, left: 5,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(color: Colors.black.withOpacity(0.7), borderRadius: BorderRadius.circular(4)),
                                      child: Text("${index + 1}", style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                  
                                  // Checkmark Icon
                                  if (isSelected)
                                    Positioned(
                                      top: 5, right: 5,
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: const BoxDecoration(color: Colors.indigoAccent, shape: BoxShape.circle),
                                        child: const Icon(Icons.check, size: 12, color: Colors.white),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),

              // 👇👇👇 BOTTOM SAVE BUTTON 👇👇👇
              if (_filePath != null)
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
                        backgroundColor: Colors.indigoAccent, // Indigo Button
                        foregroundColor: Colors.white,
                        
                        // Disable Style
                        disabledBackgroundColor: Colors.white.withOpacity(0.12),
                        disabledForegroundColor: Colors.white.withOpacity(0.3),
                        
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        elevation: 5,
                      ),
                      onPressed: _isSaving || _selectedIndices.isEmpty ? null : _saveAsImages,
                      icon: _isSaving 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.save_alt),
                      label: Text(
                        _isSaving 
                          ? "Saving Images..." 
                          : _selectedIndices.isEmpty 
                              ? "Select Pages to Save"
                              : "Save ${_selectedIndices.length} Images",
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