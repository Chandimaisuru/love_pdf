import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:love_pdf/presentation/screens/pdf_preview_screen.dart'; 
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:path_provider/path_provider.dart';

class ImageToPdfScreen extends StatefulWidget {
  const ImageToPdfScreen({super.key});

  @override
  State<ImageToPdfScreen> createState() => _ImageToPdfScreenState();
}

class _ImageToPdfScreenState extends State<ImageToPdfScreen> {
  final ImagePicker _picker = ImagePicker();
  List<XFile> _selectedImages = []; // තෝරාගත් පින්තූර list එක
  bool _isGenerating = false;

  // 1. පින්තූර තෝරාගැනීමේ Function එක
  // (මෙතන addAll නිසා තියෙන ලිස්ට් එකට අලුත් ඒවා එකතු වෙනවා)
  Future<void> _pickImages() async {
    final List<XFile> images = await _picker.pickMultiImage();
    if (images.isNotEmpty) {
      setState(() {
        _selectedImages.addAll(images);
      });
    }
  }

  // 2. PDF එක හදන Function එක (Quality & Ratio Fixed)
  Future<void> _createPdf() async {
    if (_selectedImages.isEmpty) return;

    setState(() {
      _isGenerating = true;
    });

    try {
      final PdfDocument document = PdfDocument();
      document.pageSettings.margins.all = 0; // Margins අයින් කරනවා

      for (var imageFile in _selectedImages) {
        final PdfPage page = document.pages.add();
        final List<int> imageBytes = await imageFile.readAsBytes();
        final PdfBitmap bitmap = PdfBitmap(imageBytes);

        // --- ASPECT RATIO FIX ---
        final double pageWidth = page.getClientSize().width;
        final double pageHeight = page.getClientSize().height;
        final double imgWidth = bitmap.width.toDouble();
        final double imgHeight = bitmap.height.toDouble();

        // Scale Factor
        double scaleFactor = (pageWidth / imgWidth) < (pageHeight / imgHeight)
            ? (pageWidth / imgWidth)
            : (pageHeight / imgHeight);

        double newWidth = imgWidth * scaleFactor;
        double newHeight = imgHeight * scaleFactor;

        // Centering
        double xOffset = (pageWidth - newWidth) / 2;
        double yOffset = (pageHeight - newHeight) / 2;

        page.graphics.drawImage(
          bitmap,
          Rect.fromLTWH(xOffset, yOffset, newWidth, newHeight),
        );
      }

      // Save Logic
      final Directory directory = await getApplicationDocumentsDirectory();
      final String fileName = 'LovePDF_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final String path = '${directory.path}/$fileName';
      final File file = File(path);

      await file.writeAsBytes(await document.save());
      document.dispose();

      if (mounted) {
        setState(() {
          _isGenerating = false;
          _selectedImages.clear(); 
        });

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PdfPreviewScreen(
              filePath: path, 
              fileName: fileName
            ),
          ),
        );
      }

    } catch (e) {
      setState(() {
        _isGenerating = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Image to PDF"),
        actions: [
          // --- 1. Add Button (අලුත් පින්තූර එකතු කරන්න) ---
          IconButton(
            tooltip: "Add more images",
            icon: const Icon(Icons.add_circle_outline, size: 28, color: Colors.blue),
            onPressed: _pickImages,
          ),

          // --- 2. Clear All Button ---
          if (_selectedImages.isNotEmpty)
            IconButton(
              tooltip: "Clear all",
              icon: const Icon(Icons.delete_sweep, color: Colors.redAccent),
              onPressed: () {
                setState(() {
                  _selectedImages.clear();
                });
              },
            ),
          const SizedBox(width: 10),
        ],
      ),
      body: Column(
        children: [
          // --- Image List Area (Reorderable) ---
          Expanded(
            child: _selectedImages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.image_search, size: 80, color: Colors.grey[300]),
                        const SizedBox(height: 10),
                        const Text("No images selected"),
                        TextButton.icon(
                          onPressed: _pickImages,
                          icon: const Icon(Icons.add_photo_alternate),
                          label: const Text("Select Images"),
                        )
                      ],
                    ),
                  )
                : ReorderableListView.builder(
                    padding: const EdgeInsets.all(10),
                    itemCount: _selectedImages.length,
                    // --- Drag & Drop Logic ---
                    onReorder: (oldIndex, newIndex) {
                      setState(() {
                        if (newIndex > oldIndex) newIndex -= 1;
                        final item = _selectedImages.removeAt(oldIndex);
                        _selectedImages.insert(newIndex, item);
                      });
                    },
                    itemBuilder: (context, index) {
                      final image = _selectedImages[index]; // Note: _selectedFiles කියල වැරදීමකින් තිබ්බොත් _selectedImages කියල හදාගන්න. මෙතන _selectedImages තියෙන්න ඕනේ.
                      // Corrected variable usage below:
                      return Card(
                        key: ValueKey(_selectedImages[index].path), // Unique Key එකක් ඕනේ Drag කරන්න
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(5),
                            child: Image.file(
                              File(_selectedImages[index].path),
                              width: 50,
                              height: 50,
                              fit: BoxFit.cover,
                            ),
                          ),
                          title: Text("Page ${index + 1}"),
                          // Drag Handle එක (Optional - නැතත් වැඩ කරනවා)
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.close, color: Colors.red),
                                onPressed: () {
                                  setState(() {
                                    _selectedImages.removeAt(index);
                                  });
                                },
                              ),
                              const Icon(Icons.drag_handle, color: Colors.grey),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // --- Bottom Action Button ---
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                onPressed: (_selectedImages.isEmpty || _isGenerating) ? null : _createPdf,
                icon: _isGenerating 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                    : const Icon(Icons.picture_as_pdf),
                label: Text(_isGenerating ? "Generating PDF..." : "Convert to PDF"),
              ),
            ),
          ),
        ],
      ),
    );
  }
}