import 'dart:io';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:permission_handler/permission_handler.dart';

class PdfPreviewScreen extends StatelessWidget {
  final String filePath;
  final String fileName;

  const PdfPreviewScreen({super.key, required this.filePath, required this.fileName});

  // --- වෙනස් කළ කොටස 1 (Rename Dialog) ---
  // මෙතනට එන 'parentContext' එක තමයි අපේ Screen එකේ තියෙන පණ තියෙන context එක
  void _showRenameDialog(BuildContext parentContext) {
    final TextEditingController nameController = TextEditingController(
      text: fileName.replaceAll('.pdf', '')
    );

    showDialog(
      context: parentContext,
      builder: (dialogContext) { // මෙතන නම වෙනස් කළා 'dialogContext' කියලා
        return AlertDialog(
          title: const Text("Save PDF"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Enter a name for your file:"),
              const SizedBox(height: 10),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: "Enter file name",
                  suffixText: ".pdf"
                ),
                autofocus: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext), // Dialog එක වහනවා
              child: const Text("Cancel", style: TextStyle(color: Colors.red)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext); // 1. Dialog එක වහනවා
                
                String newName = nameController.text.trim();
                if (newName.isEmpty) newName = "Untitled";
                if (!newName.endsWith('.pdf')) newName += '.pdf';
                
                // 2. මෙතන තමයි කලින් වැරදුනේ!
                // අපි දැන් යවන්නේ 'parentContext' (Screen එකේ context) එක.
                _saveFileToDownloads(parentContext, newName); 
              },
              child: const Text("Save"),
            ),
          ],
        );
      },
    );
  }

  // --- වෙනස් කළ කොටස 2 (Save Function) ---
  Future<void> _saveFileToDownloads(BuildContext context, String newFileName) async {
    try {
      // Permission ඉල්ලීම
      if (Platform.isAndroid) {
        // Android 11+ (Manage Storage) සඳහා වෙනම check එකක් (සරලව තියමු)
        var status = await Permission.storage.request();
        if (!status.isGranted && await Permission.storage.isPermanentlyDenied) {
           openAppSettings(); // Permission නැත්නම් Settings වලට යවනවා
           return;
        }
      }
      
      final String newPath = '/storage/emulated/0/Download/$newFileName';
      final File sourceFile = File(filePath);
        
      if (File(newPath).existsSync()) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('File with this name already exists!'), backgroundColor: Colors.orange),
          );
          return;
      }

      await sourceFile.copy(newPath);

      // SnackBar පෙන්වීම (දැන් මේක වැඩ කරයි)
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: Colors.white, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        "Download Complete!", 
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Saved to: Downloads/$newFileName", 
                        style: const TextStyle(fontSize: 12, color: Colors.white70),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF2E7D32),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 4),
          ),
        );
      }

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(fileName, style: const TextStyle(fontSize: 14)),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'download') {
                // මෙතනින් යවන්නේ Screen එකේ Context එක (parentContext)
                _showRenameDialog(context); 
              }
            },
            itemBuilder: (BuildContext context) {
              return [
                const PopupMenuItem(
                  value: 'download',
                  child: Row(
                    children: [
                      Icon(Icons.download_rounded, color: Colors.blueGrey),
                      SizedBox(width: 10),
                      Text('Download & Save'),
                    ],
                  ),
                ),
              ];
            },
          ),
        ],
      ),
      body: SfPdfViewer.file(File(filePath)),
    );
  }
}