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
      extendBodyBehindAppBar: true, // Gradient එක උඩටම යවන්න
      appBar: AppBar(
        title: const Text("Image to PDF", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent, // Transparent AppBar
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        actions: [
          // --- Add & Clear Buttons (Only show if images exist) ---
          if (_selectedImages.isNotEmpty) ...[
            IconButton(
              tooltip: "Add more images",
              icon: const Icon(Icons.add_photo_alternate_outlined, size: 28, color: Colors.purpleAccent),
              onPressed: _pickImages,
            ),
            IconButton(
              tooltip: "Clear all",
              icon: const Icon(Icons.delete_sweep_outlined, color: Colors.redAccent),
              onPressed: () {
                setState(() {
                  _selectedImages.clear();
                });
              },
            ),
            const SizedBox(width: 10),
          ]
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
              // --- Main Content Area ---
              Expanded(
                child: _selectedImages.isEmpty
                    // 👇👇👇 NEW LANDING PAGE (Consistent Style) 👇👇👇
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
                                    color: Colors.purpleAccent.withOpacity(0.2), // Purple Glow
                                    blurRadius: 20,
                                    spreadRadius: 5,
                                  )
                                ]
                              ),
                              child: const Icon(Icons.image_search, size: 80, color: Colors.purpleAccent),
                            ),
                            const SizedBox(height: 40),
                            
                            // 2. Title Text
                            const Text(
                              "Image to PDF",
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 15),
                            
                            // 3. Description Text
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 40),
                              child: Text(
                                "Convert your photos into a single PDF document instantly.",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.white70,
                                  height: 1.5,
                                ),
                              ),
                            ),
                            const SizedBox(height: 60),

                            // 4. Large Action Button
                            SizedBox(
                              width: 250,
                              height: 55,
                              child: ElevatedButton.icon(
                                onPressed: _pickImages,
                                icon: const Icon(Icons.add_photo_alternate),
                                label: const Text("Select Images"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.purpleAccent, // Purple Button
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
                    
                    // 👇👇👇 LIST VIEW (Glass Effect) 👇👇👇
                    : ReorderableListView.builder(
                        padding: const EdgeInsets.all(15),
                        itemCount: _selectedImages.length,
                        onReorder: (oldIndex, newIndex) {
                          setState(() {
                            if (newIndex > oldIndex) newIndex -= 1;
                            final item = _selectedImages.removeAt(oldIndex);
                            _selectedImages.insert(newIndex, item);
                          });
                        },
                        itemBuilder: (context, index) {
                          final image = _selectedImages[index];
                          return Container(
                            key: ValueKey(image.path), // Unique Key for dragging
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.08), // Glass Effect
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white.withOpacity(0.1)),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              // Thumbnail Image
                              leading: Container(
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.white24),
                                  borderRadius: BorderRadius.circular(6)
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(5),
                                  child: Image.file(
                                    File(image.path),
                                    width: 50,
                                    height: 50,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              // Title
                              title: Text(
                                "Page ${index + 1}",
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                              ),
                              // Actions (Delete & Drag Handle)
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.close, color: Colors.white70),
                                    onPressed: () {
                                      setState(() {
                                        _selectedImages.removeAt(index);
                                      });
                                    },
                                  ),
                                  Icon(Icons.drag_handle, color: Colors.white.withOpacity(0.3)),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),

              // 👇👇👇 BOTTOM ACTION BUTTON (Fixed at bottom) 👇👇👇
              if (_selectedImages.isNotEmpty)
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
                        backgroundColor: Colors.purpleAccent, // Purple for Convert
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        elevation: 5,
                      ),
                      onPressed: (_isGenerating) ? null : _createPdf,
                      icon: _isGenerating 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                        : const Icon(Icons.picture_as_pdf),
                      label: Text(
                        _isGenerating ? "Generating..." : "Convert to PDF",
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