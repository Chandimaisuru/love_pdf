import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart'; 
import 'package:image_picker/image_picker.dart';
import 'package:pdfx/pdfx.dart' as pdfx; 
import 'package:syncfusion_flutter_pdf/pdf.dart' as syncfusion; 
import 'package:path_provider/path_provider.dart';
import 'package:love_pdf/presentation/screens/pdf_preview_screen.dart';
import 'package:flutter/services.dart'; 

// පිටුවේ වර්ගය
enum PageType { pdfPage, image }

// පිටුවක විස්තර තියාගන්න පන්තිය
class PdfPageItem {
  final PageType type;
  final String? pdfPath; 
  final int? pdfPageIndex; 
  final File? imageFile; 
  final Uint8List thumbnailBytes; 
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
  final List<PdfPageItem> _pages = [];
  bool _isLoading = false;
  bool _isSaving = false;
  final ImagePicker _imagePicker = ImagePicker();

  // 1. අලුතින් PDF එකක් එකතු කිරීම
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
              pdfPath: filePath,
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

  // 2. අලුතින් Image එකක් එකතු කිරීම
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
            thumbnailBytes: bytes,
            imageFile: imgFile,
          ));
        });
      }
      setState(() => _isLoading = false);
    }
  }

  // 3. Page Content Edit කිරීම
  Future<void> _editPageContent(int index) async {
    final item = _pages[index];
    
    if (item.type != PageType.pdfPage || item.pdfPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Cannot edit text in an image file.")));
      return;
    }

    String extractedText = "";
    try {
      final File file = File(item.pdfPath!);
      final List<int> bytes = await file.readAsBytes();
      final syncfusion.PdfDocument doc = syncfusion.PdfDocument(inputBytes: bytes);
      
      extractedText = syncfusion.PdfTextExtractor(doc).extractText(
        startPageIndex: item.pdfPageIndex!, 
        endPageIndex: item.pdfPageIndex!
      );
      doc.dispose();
    } catch (e) {
      extractedText = "";
    }

    if (extractedText.trim().isEmpty) {
      extractedText = "[No selectable text found on this page]";
    }

    final String? newPdfPath = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _PageTextEditorDialog(
        initialText: extractedText,
      ),
    );

    if (newPdfPath != null && mounted) {
      setState(() => _isLoading = true);
      
      final document = await pdfx.PdfDocument.openFile(newPdfPath);
      final page = await document.getPage(1);
      final pageImage = await page.render(
        width: 200, height: 300,
        format: pdfx.PdfPageImageFormat.png,
      );
      await page.close();

      if (pageImage != null) {
        setState(() {
          _pages[index] = PdfPageItem(
            type: PageType.pdfPage,
            thumbnailBytes: pageImage.bytes,
            pdfPath: newPdfPath, 
            pdfPageIndex: 0, 
            rotationAngle: 0, 
          );
        });
      }
      setState(() => _isLoading = false);
    }
  }

  // 4. Save Logic
  Future<void> _savePdf() async {
    if (_pages.isEmpty) return;
    setState(() => _isSaving = true);

    try {
      final syncfusion.PdfDocument outputDocument = syncfusion.PdfDocument();
      outputDocument.pageSettings.margins.all = 0;

      for (var pageItem in _pages) {
        syncfusion.PdfPage? newPage;
        
        if (pageItem.type == PageType.pdfPage && pageItem.pdfPath != null) {
          final File inputFile = File(pageItem.pdfPath!);
          final syncfusion.PdfDocument inputDoc = syncfusion.PdfDocument(inputBytes: await inputFile.readAsBytes());
          
          int idx = pageItem.pdfPageIndex!;
          syncfusion.PdfTemplate template = inputDoc.pages[idx].createTemplate();
          Size pageSize = inputDoc.pages[idx].getClientSize();

          bool isSideways = pageItem.rotationAngle == 90 || pageItem.rotationAngle == 270;
          outputDocument.pageSettings.size = isSideways ? Size(pageSize.height, pageSize.width) : pageSize;
          outputDocument.pageSettings.orientation = syncfusion.PdfPageOrientation.portrait;

          newPage = outputDocument.pages.add();
          _applyRotation(newPage, pageItem.rotationAngle);
          newPage.graphics.drawPdfTemplate(template, const Offset(0, 0));
          inputDoc.dispose();
        } 
        else if (pageItem.type == PageType.image && pageItem.imageFile != null) {
          final Uint8List imgBytes = await pageItem.imageFile!.readAsBytes();
          final syncfusion.PdfBitmap bitmap = syncfusion.PdfBitmap(imgBytes);

          Size pageSize = Size(bitmap.width.toDouble(), bitmap.height.toDouble());
          bool isSideways = pageItem.rotationAngle == 90 || pageItem.rotationAngle == 270;
          outputDocument.pageSettings.size = isSideways ? Size(pageSize.height, pageSize.width) : pageSize;
          outputDocument.pageSettings.orientation = syncfusion.PdfPageOrientation.portrait;

          newPage = outputDocument.pages.add();
          _applyRotation(newPage, pageItem.rotationAngle);
          newPage.graphics.drawImage(bitmap, Rect.fromLTWH(0, 0, newPage.getClientSize().width, newPage.getClientSize().height));
        }
      }

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

  void _showAddOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent, // Transparent to show rounded corners
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1E2F38), // Dark Sheet Color
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
               Center(
                child: Container(
                  width: 50, height: 5,
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 20),
              const Text("Add Pages", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 20),
              
              // Add PDF Button
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.2), shape: BoxShape.circle),
                  child: const Icon(Icons.picture_as_pdf, color: Colors.redAccent),
                ),
                title: const Text("Add from PDF", style: TextStyle(color: Colors.white)),
                onTap: () { Navigator.pop(context); _pickAndAddPdf(); },
              ),
              
              const SizedBox(height: 10),

              // Add Image Button
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.2), shape: BoxShape.circle),
                  child: const Icon(Icons.image, color: Colors.blueAccent),
                ),
                title: const Text("Add Images", style: TextStyle(color: Colors.white)),
                onTap: () { Navigator.pop(context); _pickAndAddImage(); },
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Edit PDF", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        actions: [
          if (_pages.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.add_circle_outline, size: 28, color: Colors.greenAccent), // Green for Edit
              onPressed: _showAddOptions,
            ),
          const SizedBox(width: 10),
        ],
      ),
      body: Container(
        // Dark Theme Gradient (Same as others)
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
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: Colors.white))
                    : _pages.isEmpty
                        // 👇👇👇 NEW LANDING PAGE (Consistent Style) 👇👇👇
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
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.greenAccent.withOpacity(0.2), // Green Glow
                                        blurRadius: 20,
                                        spreadRadius: 5,
                                      )
                                    ]
                                  ),
                                  child: const Icon(Icons.edit_note, size: 80, color: Colors.greenAccent),
                                ),
                                const SizedBox(height: 40),
                                const Text(
                                  "Edit PDF",
                                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                                const SizedBox(height: 15),
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 40),
                                  child: Text(
                                    "Select a PDF to extract pages, reorder, rotate, or edit text.",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 16, color: Colors.white70, height: 1.5),
                                  ),
                                ),
                                const SizedBox(height: 60),
                                SizedBox(
                                  width: 250,
                                  height: 55,
                                  child: ElevatedButton.icon(
                                    onPressed: _pickAndAddPdf,
                                    icon: const Icon(Icons.upload_file),
                                    label: const Text("Select PDF File"),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color.fromARGB(100, 5, 205, 108), // Green Button
                                      foregroundColor: const Color.fromARGB(255, 239, 230, 230), // Black text on Green looks cool
                                      elevation: 8,
                                      textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                                    ),
                                  ),
                                )
                              ],
                            ),
                          )
                        // 👇👇👇 NEW LIST VIEW (Glass Effect) 👇👇👇
                        : ReorderableListView.builder(
                            padding: const EdgeInsets.all(15),
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
                              return Container(
                                key: ValueKey(item.hashCode),
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(8.0),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.08), // Glass Effect
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                                ),
                                child: Row(
                                  children: [
                                    // Thumbnail Container
                                    Container(
                                      width: 60, height: 80,
                                      decoration: BoxDecoration(
                                        border: Border.all(color: Colors.white24),
                                        borderRadius: BorderRadius.circular(6),
                                        color: Colors.black12
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(5),
                                        child: RotatedBox(
                                          quarterTurns: item.rotationAngle ~/ 90,
                                          child: Image.memory(item.thumbnailBytes, fit: BoxFit.contain),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 15),
                                    
                                    // Details & Actions
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text("Page ${index + 1}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                                          Text(item.type == PageType.pdfPage ? "Source: PDF" : "Source: Image", style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.5))),
                                          const SizedBox(height: 10),
                                          
                                          // Action Buttons Row
                                          Row(
                                            children: [
                                              // EDIT TEXT


                                              // if (item.type == PageType.pdfPage)
                                              //   _buildMiniButton(
                                              //     icon: Icons.edit_note, 
                                              //     color: Colors.orangeAccent, 
                                              //     onTap: () => _editPageContent(index)
                                              //   ),
                                              // if (item.type == PageType.pdfPage) const SizedBox(width: 10),

                                              // ROTATE
                                              _buildMiniButton(
                                                icon: Icons.rotate_right, 
                                                color: Colors.blueAccent, 
                                                onTap: () => setState(() => item.rotationAngle = (item.rotationAngle + 90) % 360)
                                              ),
                                              const SizedBox(width: 10),

                                              // DELETE
                                              _buildMiniButton(
                                                icon: Icons.delete_outline, 
                                                color: Colors.redAccent, 
                                                onTap: () => setState(() => _pages.removeAt(index))
                                              ),
                                            ],
                                          )
                                        ],
                                      ),
                                    ),
                                    Icon(Icons.drag_handle, color: Colors.white.withOpacity(0.3)),
                                  ],
                                ),
                              );
                            },
                          ),
              ),

              // 👇👇👇 BOTTOM SAVE BUTTON 👇👇👇
              if (_pages.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F2027).withOpacity(0.95),
                    border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.greenAccent, // Green for Save
                        foregroundColor: Colors.black, // Black text
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        elevation: 5,
                      ),
                      onPressed: _isSaving ? null : _savePdf,
                      icon: _isSaving 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                        : const Icon(Icons.save),
                      label: Text(
                        _isSaving ? "Saving..." : "Save PDF",
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

  // Helper for mini buttons
  Widget _buildMiniButton({required IconData icon, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(5),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: color.withOpacity(0.2), 
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: color.withOpacity(0.5), width: 0.5)
        ),
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }
}

// --- INTERNAL EDITOR DIALOG (Standard style kept for readability) ---
class _PageTextEditorDialog extends StatefulWidget {
  final String initialText;

  const _PageTextEditorDialog({required this.initialText});

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
    _titleController = TextEditingController(text: ""); 
    _bodyController = TextEditingController(text: widget.initialText);
  }

  Future<void> _saveTempPage() async {
    setState(() => _isSaving = true);
    try {
      final syncfusion.PdfDocument document = syncfusion.PdfDocument();
      final syncfusion.PdfPage page = document.pages.add();

      final syncfusion.PdfFont titleFont = syncfusion.PdfStandardFont(
        syncfusion.PdfFontFamily.helvetica, 24, style: syncfusion.PdfFontStyle.bold
      );
      final syncfusion.PdfFont bodyFont = syncfusion.PdfStandardFont(
        syncfusion.PdfFontFamily.helvetica, 12
      );
      final syncfusion.PdfBrush brush = syncfusion.PdfSolidBrush(syncfusion.PdfColor(0, 0, 0));
      double yPos = 0;

      if (_titleController.text.trim().isNotEmpty) {
        page.graphics.drawString(
          _titleController.text, titleFont, brush: brush,
          bounds: Rect.fromLTWH(0, yPos, page.getClientSize().width, 60),
          format: syncfusion.PdfStringFormat(alignment: syncfusion.PdfTextAlignment.center),
        );
        yPos += 50;
        page.graphics.drawLine(
          syncfusion.PdfPen(syncfusion.PdfColor(200, 200, 200)),
          Offset(20, yPos), Offset(page.getClientSize().width - 20, yPos)
        );
        yPos += 20;
      }

      syncfusion.PdfTextElement(text: _bodyController.text, font: bodyFont, brush: brush).draw(
        page: page,
        bounds: Rect.fromLTWH(0, yPos, page.getClientSize().width, page.getClientSize().height - yPos),
      );

      final dir = await getApplicationDocumentsDirectory();
      final fileName = "Temp_Edited_Page_${DateTime.now().millisecondsSinceEpoch}.pdf";
      final path = '${dir.path}/$fileName';

      await File(path).writeAsBytes(await document.save());
      document.dispose();

      if (mounted) {
        Navigator.pop(context, path); // Return the PATH of the new file
      }
    } catch (e) {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(15),
      child: Container(
        padding: const EdgeInsets.all(15),
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Edit Content", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const Divider(),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: "Heading (Optional)", hintText: "Type heading here to make it BOLD",
                border: OutlineInputBorder(), prefixIcon: Icon(Icons.title),
              ),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(5)),
                child: TextField(
                  controller: _bodyController, maxLines: null, expands: true,
                  decoration: const InputDecoration(border: InputBorder.none, hintText: "Content..."),
                ),
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
              onPressed: _isSaving ? null : _saveTempPage,
              icon: const Icon(Icons.check_circle),
              label: const Text("Apply Changes"),
            ),
          ],
        ),
      ),
    );
  }
}