import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart'; 
import 'package:image_picker/image_picker.dart'; // Photos ගන්න
import 'package:pdfx/pdfx.dart' as pdfx; 
import 'package:syncfusion_flutter_pdf/pdf.dart' as syncfusion; 
import 'package:path_provider/path_provider.dart';
import 'package:love_pdf/presentation/screens/pdf_preview_screen.dart';

// පිටුවේ වර්ගය (PDF පිටුවක්ද? Image එකක්ද?)
enum PageType { pdfPage, image }

// පිටුවක විස්තර තියාගන්න පන්තිය
class PdfPageItem {
  final PageType type;
  final String? pdfPath; // PDF එකක් නම්, ඒ ෆයිල් එකේ path එක
  final int? pdfPageIndex; // PDF එකක් නම්, පිටු අංකය
  final File? imageFile; // Image එකක් නම්, ඒ ෆයිල් එක
  final Uint8List thumbnailBytes; // පෙන්වන පොඩි පින්තූරය
  int rotationAngle;

  PdfPageItem({
    required this.type,
    required this.thumbnailBytes,
    this.pdfPath,
    this.pdfPageIndex,
    this.imageFile,
    this.rotationAngle = 0,
  });
}

class EditPdfScreen extends StatefulWidget {
  const EditPdfScreen({super.key});

  @override
  State<EditPdfScreen> createState() => _EditPdfScreenState();
}

class _EditPdfScreenState extends State<EditPdfScreen> {
  final List<PdfPageItem> _pages = []; // පිටු ලිස්ට් එක
  bool _isLoading = false;
  bool _isSaving = false;
  final ImagePicker _imagePicker = ImagePicker();

  // 1. අලුතින් PDF එකක් එකතු කිරීම (Append PDF)
  Future<void> _pickAndAddPdf() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null && result.files.single.path != null) {
      String path = result.files.single.path!;
      setState(() => _isLoading = true);
      await _generatePdfThumbnails(path);
    }
  }

  // PDF පිටු කියවා List එකට එකතු කිරීම
  Future<void> _generatePdfThumbnails(String filePath) async {
    try {
      final document = await pdfx.PdfDocument.openFile(filePath);
      int count = document.pagesCount;

      for (int i = 1; i <= count; i++) {
        if (!mounted) break;

        final page = await document.getPage(i);
        final pageImage = await page.render(
          width: 200, height: 300,
          format: pdfx.PdfPageImageFormat.png,
        );
        await page.close();

        if (pageImage != null) {
          setState(() {
            _pages.add(PdfPageItem(
              type: PageType.pdfPage,
              thumbnailBytes: pageImage.bytes,
              pdfPath: filePath, // මේ පිටුව ආවේ කොහෙන්ද කියල මතක තියාගන්නවා
              pdfPageIndex: i - 1,
            ));
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

  // 2. අලුතින් Image එකක් එකතු කිරීම (Add Image)
  Future<void> _pickAndAddImage() async {
    final List<XFile> images = await _imagePicker.pickMultiImage();
    if (images.isNotEmpty) {
      setState(() => _isLoading = true);
      
      for (var img in images) {
        File imgFile = File(img.path);
        Uint8List bytes = await imgFile.readAsBytes();
        
        setState(() {
          _pages.add(PdfPageItem(
            type: PageType.image,
            thumbnailBytes: bytes, // Image එකම පාවිච්චි කරනවා thumbnail එකට
            imageFile: imgFile,
          ));
        });
      }
      setState(() => _isLoading = false);
    }
  }

  // 3. Save Logic (Complex: Mix of PDF Pages & Images)
  Future<void> _savePdf() async {
    if (_pages.isEmpty) return;
    setState(() => _isSaving = true);

    try {
      final syncfusion.PdfDocument outputDocument = syncfusion.PdfDocument();
      outputDocument.pageSettings.margins.all = 0;

      // හැම පිටුවක් හරහාම යනවා
      for (var pageItem in _pages) {
        syncfusion.PdfPage? newPage;
        
        // --- CASE A: පිටුව PDF එකකින් ආපු එකක් නම් ---
        if (pageItem.type == PageType.pdfPage && pageItem.pdfPath != null) {
          // අදාළ PDF එක තාවකාලිකව open කරනවා
          final File inputFile = File(pageItem.pdfPath!);
          final syncfusion.PdfDocument inputDoc = syncfusion.PdfDocument(inputBytes: await inputFile.readAsBytes());
          
          // Template එකක් හදාගන්නවා
          int index = pageItem.pdfPageIndex!;
          syncfusion.PdfTemplate template = inputDoc.pages[index].createTemplate();
          Size pageSize = inputDoc.pages[index].getClientSize();

          // Rotation Logic (Width/Height මාරු කිරීම)
          bool isSideways = pageItem.rotationAngle == 90 || pageItem.rotationAngle == 270;
          outputDocument.pageSettings.size = isSideways ? Size(pageSize.height, pageSize.width) : pageSize;
          outputDocument.pageSettings.orientation = syncfusion.PdfPageOrientation.portrait;

          newPage = outputDocument.pages.add();
          
          // Rotate property
          _applyRotation(newPage, pageItem.rotationAngle);

          // Draw
          newPage.graphics.drawPdfTemplate(template, const Offset(0, 0));
          
          // Memory free
          inputDoc.dispose();
        } 
        
        // --- CASE B: පිටුව Image එකක් නම් ---
        else if (pageItem.type == PageType.image && pageItem.imageFile != null) {
          final Uint8List imgBytes = await pageItem.imageFile!.readAsBytes();
          final syncfusion.PdfBitmap bitmap = syncfusion.PdfBitmap(imgBytes);

          // Image Dimensions
          Size pageSize = Size(bitmap.width.toDouble(), bitmap.height.toDouble());
          
          bool isSideways = pageItem.rotationAngle == 90 || pageItem.rotationAngle == 270;
          outputDocument.pageSettings.size = isSideways ? Size(pageSize.height, pageSize.width) : pageSize;
          outputDocument.pageSettings.orientation = syncfusion.PdfPageOrientation.portrait;

          newPage = outputDocument.pages.add();
          
          _applyRotation(newPage, pageItem.rotationAngle);

          // Image එක අඳිනවා
          newPage.graphics.drawImage(bitmap, Rect.fromLTWH(0, 0, newPage.getClientSize().width, newPage.getClientSize().height));
        }
      }

      // Save File
      final dir = await getApplicationDocumentsDirectory();
      final fileName = 'Edit_Mix_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final path = '${dir.path}/$fileName';
      
      await File(path).writeAsBytes(await outputDocument.save());
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

  void _applyRotation(syncfusion.PdfPage page, int angle) {
    if (angle == 90) page.rotation = syncfusion.PdfPageRotateAngle.rotateAngle90;
    else if (angle == 180) page.rotation = syncfusion.PdfPageRotateAngle.rotateAngle180;
    else if (angle == 270) page.rotation = syncfusion.PdfPageRotateAngle.rotateAngle270;
  }

  // --- Add Options පෙන්වන Bottom Sheet ---
// --- Add Options පෙන්වන Bottom Sheet (Fixed Overflow) ---
  void _showAddOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea( // යටින් ආරක්ෂිත ඉඩක් තියන්න SafeArea දැම්මා
          child: Container(
            padding: const EdgeInsets.all(20),
            // height: 180, // <--- මේ පේළිය අයින් කළා (Fixed Height එපා)
            child: Column(
              mainAxisSize: MainAxisSize.min, // <--- මෙය දැම්මාම අවශ්‍ය ප්‍රමාණයට විතරක් උස හැදෙනවා
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Add Pages", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 15),
                ListTile(
                  leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                  title: const Text("Add from PDF"),
                  onTap: () {
                    Navigator.pop(context);
                    _pickAndAddPdf();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.image, color: Colors.blue),
                  title: const Text("Add Images"),
                  onTap: () {
                    Navigator.pop(context);
                    _pickAndAddImage();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Edit PDF"),
        actions: [
          // (+) Button එක දැන් පෙන්වන්නේ pages තිබුණොත් විතරයි (තව add කරන්න)
          if (_pages.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.add_circle_outline, size: 28, color: Colors.blue),
              tooltip: "Add Pages",
              onPressed: _showAddOptions,
            ),
          const SizedBox(width: 10),
        ],
      ),
      body: Column(
        children: [
          // --- EMPTY STATE (මුලින්ම පෙන්වන කොටස) ---
          if (_pages.isEmpty && !_isLoading)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.edit_document, size: 80, color: Colors.grey[300]),
                    const SizedBox(height: 20),
                    const Text("Select a PDF to Organize"),
                    const SizedBox(height: 20),
                    
                    // --- වෙනස් කළ කොටස ---
                    // මෙතන click කළාම කෙලින්ම PDF එක තෝරන්න දෙනවා. (No Option Sheet)
                    ElevatedButton.icon(
                      onPressed: _pickAndAddPdf, // Direct PDF Pick
                      icon: const Icon(Icons.upload_file), 
                      label: const Text("Select PDF File"),
                    ),
                  ],
                ),
              ),
            )
          
          // --- LOADING STATE ---
          else if (_isLoading && _pages.isEmpty)
             const Expanded(child: Center(child: CircularProgressIndicator()))

          // --- LIST STATE (පිටු පෙන්වන කොටස) ---
          else
            Expanded(
              child: ReorderableListView.builder(
                padding: const EdgeInsets.all(10),
                itemCount: _pages.length,
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (newIndex > oldIndex) newIndex -= 1;
                    final item = _pages.removeAt(oldIndex);
                    _pages.insert(newIndex, item);
                  });
                },
                itemBuilder: (context, index) {
                  final item = _pages[index];
                  // Card UI එක 
                  return Card(
                    key: ValueKey(item.hashCode),
                    margin: const EdgeInsets.only(bottom: 10),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        children: [
                          Container(
                            width: 60, height: 80,
                            decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!), color: Colors.grey[200]),
                            child: RotatedBox(
                              quarterTurns: item.rotationAngle ~/ 90,
                              child: Image.memory(item.thumbnailBytes, fit: BoxFit.contain),
                            ),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Page ${index + 1}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                Text(item.type == PageType.pdfPage ? "Source: PDF" : "Source: Image", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    InkWell(
                                      onTap: () => setState(() => item.rotationAngle = (item.rotationAngle + 90) % 360),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(4)),
                                        child: const Icon(Icons.rotate_right, size: 20, color: Colors.blue),
                                      ),
                                    ),
                                    const SizedBox(width: 15),
                                    InkWell(
                                      onTap: () => setState(() => _pages.removeAt(index)),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(4)),
                                        child: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                                      ),
                                    ),
                                  ],
                                )
                              ],
                            ),
                          ),
                          const Icon(Icons.drag_handle, color: Colors.grey),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

          // --- SAVE BUTTON ---
          if (_pages.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                  onPressed: _isSaving ? null : _savePdf,
                  icon: _isSaving 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.save),
                  label: Text(_isSaving ? "Saving..." : "Save PDF"),
                ),
              ),
            ),
        ],
      ),
    );
  }
}