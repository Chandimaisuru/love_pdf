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

  // 2. Merge Logic
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
      outputDocument.pageSettings.margins.all = 0;

      for (var file in _selectedFiles) {
        final File inputFile = File(file.path!);
        final List<int> inputBytes = await inputFile.readAsBytes();
        final PdfDocument inputDocument = PdfDocument(inputBytes: inputBytes);

        for (int i = 0; i < inputDocument.pages.count; i++) {
          Size pageSize = inputDocument.pages[i].getClientSize();
          PdfTemplate template = inputDocument.pages[i].createTemplate();

          outputDocument.pageSettings.size = pageSize;
          outputDocument.pageSettings.orientation =
              pageSize.width > pageSize.height ? PdfPageOrientation.landscape : PdfPageOrientation.portrait;

          PdfPage newPage = outputDocument.pages.add();
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
              fileName: fileName,
            ),
          ),
        );
      }
    } catch (e) {
      setState(() => _isMerging = false);
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
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Merge PDFs", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        actions: [
          // Add Button (Header - Only show if files are selected)
          if (_selectedFiles.isNotEmpty) ...[
            IconButton(
              tooltip: "Add more PDFs",
              icon: const Icon(Icons.add_circle_outline, size: 28, color: Colors.blueAccent),
              onPressed: _pickFiles,
            ),
            IconButton(
              tooltip: "Clear all",
              icon: const Icon(Icons.delete_sweep_outlined, color: Colors.redAccent),
              onPressed: () {
                setState(() => _selectedFiles.clear());
              },
            ),
            const SizedBox(width: 10),
          ]
        ],
      ),
      body: Container(
        // Dark Gradient Background
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
                child: _selectedFiles.isEmpty
                    // Landing Page Design
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
                                    color: Colors.blueAccent.withOpacity(0.2),
                                    blurRadius: 20,
                                    spreadRadius: 5,
                                  )
                                ]
                              ),
                              child: const Icon(Icons.merge_type, size: 80, color: Colors.blueAccent),
                            ),
                            const SizedBox(height: 40),
                            const Text(
                              "Merge PDFs",
                              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            const SizedBox(height: 15),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 40),
                              child: Text(
                                "Combine multiple PDF files into a single document quickly and easily.",
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 16, color: Colors.white70, height: 1.5),
                              ),
                            ),
                            const SizedBox(height: 60),
                            SizedBox(
                              width: 250,
                              height: 55,
                              child: ElevatedButton.icon(
                                onPressed: _pickFiles,
                                icon: const Icon(Icons.add),
                                label: const Text("Select PDF Files"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blueAccent,
                                  foregroundColor: Colors.white,
                                  elevation: 8,
                                  textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                                ),
                              ),
                            )
                          ],
                        ),
                      )
                    // List View
                    : ReorderableListView.builder(
                        padding: const EdgeInsets.all(15),
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
                          return Container(
                            key: ValueKey(file.path),
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white.withOpacity(0.1)),
                            ),
                            child: ListTile(
                              leading: const Icon(Icons.picture_as_pdf, color: Colors.redAccent, size: 30),
                              title: Text(
                                file.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                              ),
                              subtitle: Text(
                                "${(file.size / 1024).toStringAsFixed(1)} KB",
                                style: TextStyle(color: Colors.white.withOpacity(0.6)),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.drag_handle, color: Colors.white.withOpacity(0.3)),
                                  const SizedBox(width: 10),
                                  IconButton(
                                    icon: const Icon(Icons.close, color: Colors.white70),
                                    onPressed: () {
                                      setState(() => _selectedFiles.removeAt(index));
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),

              // --- Bottom Action Button ---
              // Files එකක් හරි තිබ්බොත් මේක පෙන්වනවා
              if (_selectedFiles.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F2027).withOpacity(0.95),
                    border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, -5))
                    ],
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                        
                        // 👇 මෙන්න ඔයා ඉල්ලපු Fix එක (Disabled වුනාම පේන පාට) 👇
                        disabledBackgroundColor: Colors.white.withOpacity(0.12), 
                        disabledForegroundColor: Colors.white.withOpacity(0.3), 
                        
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        elevation: 5,
                      ),
                      // ෆයිල් 2කට වඩා අඩු නම් Button එක Click කරන්න බෑ (null)
                      onPressed: (_isMerging || _selectedFiles.length < 2) ? null : _mergePdfs,
                      
                      icon: _isMerging
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.merge),
                      
                      // Text එක වෙනස් වෙනවා ෆයිල් ගාණ අනුව
                      label: Text(
                        _isMerging 
                            ? "Merging..." 
                            : _selectedFiles.length < 2 
                                ? "Select at least 2 files" // 1ක් තිබ්බොත් මේක වැටෙන්නේ
                                : "Merge ${_selectedFiles.length} Files",
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