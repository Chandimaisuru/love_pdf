import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart'; 
import 'package:image_picker/image_picker.dart';
import 'package:pdfx/pdfx.dart' as pdfx; 
import 'package:syncfusion_flutter_pdf/pdf.dart' as syncfusion; 
import 'package:path_provider/path_provider.dart';
import 'package:love_pdf/presentation/screens/pdf_preview_screen.dart';
import 'package:flutter/services.dart'; // For Clipboard

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

  // 3. Page Content Edit කිරීම (NEW FEATURE)
  Future<void> _editPageContent(int index) async {
    final item = _pages[index];
    
    // Image එකක් නම් Edit කරන්න බෑ (Text නෑනේ)
    if (item.type != PageType.pdfPage || item.pdfPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Cannot edit text in an image file.")));
      return;
    }

    // Text Extract කිරීම
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

    // Editor Dialog එක පෙන්වීම
    final String? newPdfPath = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _PageTextEditorDialog(
        initialText: extractedText,
      ),
    );

    // වෙනස් කරලා Save කළා නම්
    if (newPdfPath != null && mounted) {
      setState(() => _isLoading = true);
      
      // අලුත් පිටුවේ Thumbnail එක හදනවා
      final document = await pdfx.PdfDocument.openFile(newPdfPath);
      final page = await document.getPage(1);
      final pageImage = await page.render(
        width: 200, height: 300,
        format: pdfx.PdfPageImageFormat.png,
      );
      await page.close();

      if (pageImage != null) {
        setState(() {
          // පරණ පිටුව අයින් කරලා අලුත් එක දානවා
          _pages[index] = PdfPageItem(
            type: PageType.pdfPage,
            thumbnailBytes: pageImage.bytes,
            pdfPath: newPdfPath, // අලුත් තාවකාලික ෆයිල් එක
            pdfPageIndex: 0, // අලුත් ෆයිල් එකේ තියෙන්නේ පිටු 1යි
            rotationAngle: 0, // Edit කළාම Rotate එක Reset වෙනවා (Clean start)
          );
        });
      }
      setState(() => _isLoading = false);
    }
  }

  // 4. Save Logic (Mix of PDF Pages & Images)
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
      builder: (context) {
        return SafeArea(
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Add Pages", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 15),
                ListTile(
                  leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                  title: const Text("Add from PDF"),
                  onTap: () { Navigator.pop(context); _pickAndAddPdf(); },
                ),
                ListTile(
                  leading: const Icon(Icons.image, color: Colors.blue),
                  title: const Text("Add Images"),
                  onTap: () { Navigator.pop(context); _pickAndAddImage(); },
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
          if (_pages.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.add_circle_outline, size: 28, color: Colors.blue),
              onPressed: _showAddOptions,
            ),
          const SizedBox(width: 10),
        ],
      ),
      body: Column(
        children: [
          if (_pages.isEmpty && !_isLoading)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.edit_document, size: 80, color: Colors.grey[300]),
                    const SizedBox(height: 20),
                    const Text("Select a PDF to Organize & Edit"),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: _pickAndAddPdf, 
                      icon: const Icon(Icons.upload_file), 
                      label: const Text("Select PDF File"),
                    ),
                  ],
                ),
              ),
            )
          else if (_isLoading)
             const Expanded(child: Center(child: CircularProgressIndicator()))
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
                                    // --- EDIT TEXT BUTTON (NEW) ---
                                    if (item.type == PageType.pdfPage)
                                      InkWell(
                                        onTap: () => _editPageContent(index),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          margin: const EdgeInsets.only(right: 10),
                                          decoration: BoxDecoration(color: Colors.orange[50], borderRadius: BorderRadius.circular(4)),
                                          child: const Icon(Icons.edit_note, size: 20, color: Colors.orange),
                                        ),
                                      ),

                                    InkWell(
                                      onTap: () => setState(() => item.rotationAngle = (item.rotationAngle + 90) % 360),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(4)),
                                        child: const Icon(Icons.rotate_right, size: 20, color: Colors.blue),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
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

// --- INTERNAL EDITOR DIALOG (REUSED) ---
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