import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:love_pdf/presentation/screens/pdf_preview_screen.dart'; // හරියටම import කරගන්න
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

  // 2. PDF එක හදන Function එක (UPDATED: Fixed Aspect Ratio + Zero Margins)
  Future<void> _createPdf() async {
    if (_selectedImages.isEmpty) return;

    setState(() {
      _isGenerating = true;
    });

    try {
      final PdfDocument document = PdfDocument();

      // ** විශේෂ වෙනස්කම 1: පිටුවේ වටේ තියෙන Default Margins (හිස් ඉඩ) අයින් කිරීම **
      document.pageSettings.margins.all = 0;

      for (var imageFile in _selectedImages) {
        // PDF පිටුවක් හදාගන්නවා (Default A4 Portrait)
        final PdfPage page = document.pages.add();
        
        final List<int> imageBytes = await imageFile.readAsBytes();
        final PdfBitmap bitmap = PdfBitmap(imageBytes);

        // --- ASPECT RATIO FIX & CENTERING ---
        
        // A. පිටුවේ සහ පින්තූරයේ ප්‍රමාණයන් ගන්නවා
        final double pageWidth = page.getClientSize().width;
        final double pageHeight = page.getClientSize().height;
        final double imgWidth = bitmap.width.toDouble();
        final double imgHeight = bitmap.height.toDouble();

        // B. පින්තූරය පිටුවට හරියන්න කුඩා/විශාල කළ යුතු ප්‍රමාණය (Scale) ගණනය කිරීම
        // (පළල සහ උස යන දෙකෙන් පිටුවට වඩාත්ම තද වෙන පැත්ත තෝරාගන්නවා. එවිට පින්තූරය පිටුවෙන් එළියට පනින්නේ නෑ.)
        double scaleFactor = (pageWidth / imgWidth) < (pageHeight / imgHeight)
            ? (pageWidth / imgWidth)
            : (pageHeight / imgHeight);

        // C. අලුත් පළල සහ උස
        double newWidth = imgWidth * scaleFactor;
        double newHeight = imgHeight * scaleFactor;

        // D. මැදට ගන්න ඕනේ දුර (Centering Logic)
        double xOffset = (pageWidth - newWidth) / 2;
        double yOffset = (pageHeight - newHeight) / 2;

        // E. දැන් හරිම ප්‍රමාණයට, හරිම තැන පින්තූරය අඳිනවා
        page.graphics.drawImage(
          bitmap,
          Rect.fromLTWH(xOffset, yOffset, newWidth, newHeight),
        );
      }

      // App එකේ තාවකාලික storage එකට save කරනවා
      final Directory directory = await getApplicationDocumentsDirectory();
      final String fileName = 'LovePDF_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final String path = '${directory.path}/$fileName';
      final File file = File(path);

      await file.writeAsBytes(await document.save());
      document.dispose();

      // PDF එක හැදුන ගමන් Preview Screen එකට Navigate කරනවා
      if (mounted) {
        setState(() {
          _isGenerating = false;
          _selectedImages.clear(); // වැඩේ ඉවර නිසා ලිස්ට් එක clear කරනවා
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
          // Clear Button
          if (_selectedImages.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () {
                setState(() {
                  _selectedImages.clear();
                });
              },
            )
        ],
      ),
      body: Column(
        children: [
          // --- Image List Area ---
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
                : ListView.builder(
                    padding: const EdgeInsets.all(10),
                    itemCount: _selectedImages.length,
                    itemBuilder: (context, index) {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          leading: Image.file(
                            File(_selectedImages[index].path),
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                          ),
                          title: Text("Image ${index + 1}"),
                          trailing: IconButton(
                            icon: const Icon(Icons.close, color: Colors.red),
                            onPressed: () {
                              setState(() {
                                _selectedImages.removeAt(index);
                              });
                            },
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