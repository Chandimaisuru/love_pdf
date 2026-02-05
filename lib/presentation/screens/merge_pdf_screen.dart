import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:path_provider/path_provider.dart';
import 'package:love_pdf/presentation/screens/pdf_preview_screen.dart'; 

class MergePdfScreen extends StatefulWidget {
  const MergePdfScreen({super.key});

  @override
  State<MergePdfScreen> createState() => _MergePdfScreenState();
}

class _MergePdfScreenState extends State<MergePdfScreen> {
  List<PlatformFile> _selectedFiles = []; 
  bool _isMerging = false;

  // 1. PDF ෆයිල්ස් තෝරාගැනීම 
  // (මෙතන addAll පාවිච්චි කරන නිසා තියෙන ලිස්ට් එකට අලුත් ඒවා එකතු වෙනවා)
  Future<void> _pickFiles() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: true, 
      );

      if (result != null) {
        setState(() {
          _selectedFiles.addAll(result.files);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking files: $e')),
      );
    }
  }

  // 2. Merge Logic (Template Fix සමඟ)
// 2. Merge Logic (Fixed: Margins Issue)
  Future<void> _mergePdfs() async {
    if (_selectedFiles.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least 2 PDF files')),
      );
      return;
    }

    setState(() {
      _isMerging = true;
    });

    try {
      final PdfDocument outputDocument = PdfDocument();

      // --- විශේෂ වෙනස්කම මෙතන ---
      // අලුත් PDF එකේ වටේ හිස් ඉඩ (Default Margins) සම්පූර්ණයෙන්ම අයින් කරනවා.
      // නැත්නම් පිටු එකතු කරද්දී ඒවා දකුණට පැනලා (Shift වෙලා) පේන්නේ මේ නිසයි.
      outputDocument.pageSettings.margins.all = 0;

      for (var file in _selectedFiles) {
        final File inputFile = File(file.path!);
        final List<int> inputBytes = await inputFile.readAsBytes();
        final PdfDocument inputDocument = PdfDocument(inputBytes: inputBytes);

        for (int i = 0; i < inputDocument.pages.count; i++) {
          // මුල් පිටුවේ ප්‍රමාණය ගන්නවා
          Size pageSize = inputDocument.pages[i].getClientSize();
          
          // Template එකක් හදාගන්නවා
          PdfTemplate template = inputDocument.pages[i].createTemplate();

          // අලුත් පිටුව හදන්න කලින්, මුල් පිටුවේ ප්‍රමාණයටම Settings හදාගන්නවා
          outputDocument.pageSettings.size = pageSize;
          outputDocument.pageSettings.orientation = 
              pageSize.width > pageSize.height ? PdfPageOrientation.landscape : PdfPageOrientation.portrait;
          
          // දැන් පිටුව add කරනවා (Margins 0 නිසා හරියටම මුල ඉඳන් පටන් ගනී)
          PdfPage newPage = outputDocument.pages.add();
          
          // හරියටම 0,0 තැනින් අඳිනවා
          newPage.graphics.drawPdfTemplate(template, const Offset(0, 0));
        }

        inputDocument.dispose();
      }

      final Directory directory = await getApplicationDocumentsDirectory();
      final String fileName = 'Merged_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final String path = '${directory.path}/$fileName';
      final File file = File(path);

      await file.writeAsBytes(await outputDocument.save());
      outputDocument.dispose();

      if (mounted) {
        setState(() {
          _isMerging = false;
          _selectedFiles.clear();
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
        _isMerging = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error merging files: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Merge PDFs"),
        actions: [
          // --- 1. Add Button (අලුතින් දැමූ කොටස) ---
          IconButton(
            tooltip: "Add more PDFs",
            icon: const Icon(Icons.add_circle_outline, size: 28, color: Colors.blue),
            onPressed: _pickFiles, // මෙය click කළාම තවත් ෆයිල් තෝරන්න පුළුවන්
          ),
          
          // --- 2. Delete All Button ---
          if (_selectedFiles.isNotEmpty)
            IconButton(
              tooltip: "Clear all",
              icon: const Icon(Icons.delete_sweep, color: Colors.redAccent),
              onPressed: () {
                setState(() {
                  _selectedFiles.clear();
                });
              },
            ),
          
          const SizedBox(width: 10), // පොඩි ඉඩක්
        ],
      ),
      body: Column(
        children: [
          // --- File List Area ---
          Expanded(
            child: _selectedFiles.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.merge_type, size: 80, color: Colors.grey[300]),
                        const SizedBox(height: 10),
                        const Text("Select 2 or more PDFs to merge"),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: _pickFiles,
                          icon: const Icon(Icons.add),
                          label: const Text("Add PDFs"),
                        )
                      ],
                    ),
                  )
                : ReorderableListView.builder(
                    padding: const EdgeInsets.all(10),
                    itemCount: _selectedFiles.length,
                    onReorder: (oldIndex, newIndex) {
                      setState(() {
                        if (newIndex > oldIndex) newIndex -= 1;
                        final item = _selectedFiles.removeAt(oldIndex);
                        _selectedFiles.insert(newIndex, item);
                      });
                    },
                    itemBuilder: (context, index) {
                      final file = _selectedFiles[index];
                      return Card(
                        key: ValueKey(file.path), 
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                          title: Text(file.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text("${(file.size / 1024).toStringAsFixed(1)} KB"),
                          trailing: IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              setState(() {
                                _selectedFiles.removeAt(index);
                              });
                            },
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // --- Bottom Action Button ---
          if (_selectedFiles.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(color: Colors.black12, blurRadius: 10, offset: const Offset(0, -5))
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: (_isMerging || _selectedFiles.length < 2) ? null : _mergePdfs,
                  icon: _isMerging 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.merge),
                  label: Text(_isMerging ? "Merging..." : "Merge Files"),
                ),
              ),
            ),
        ],
      ),
    );
  }
}