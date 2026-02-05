import 'package:flutter/material.dart';

class SplitOptionsSheet extends StatelessWidget {
  final VoidCallback onExtract;
  final VoidCallback onDelete;
  final VoidCallback onRange;

  const SplitOptionsSheet({
    super.key,
    required this.onExtract,
    required this.onDelete,
    required this.onRange,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Split Options",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          const Text(
            "Choose how you want to split this PDF:",
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 20),

          // Option 1: Extract (Keep)
          _buildOption(
            context,
            icon: Icons.check_box_outlined,
            color: Colors.green,
            title: "Extract Pages",
            subtitle: "Select pages you want to KEEP.",
            onTap: onExtract,
          ),

          // Option 2: Delete (Remove)
          _buildOption(
            context,
            icon: Icons.delete_outline,
            color: Colors.redAccent,
            title: "Delete Pages",
            subtitle: "Select pages you want to REMOVE.",
            onTap: onDelete,
          ),

          // Option 3: Range (Numbers)
          // _buildOption(
          //   context,
          //   icon: Icons.onetwothree, // Numbers icon
          //   color: Colors.blue,
          //   title: "Split by Range",
          //   subtitle: "Enter page numbers (e.g., 1-5, 8).",
          //   onTap: onRange,
          // ),
        ],
      ),
    );
  }

  Widget _buildOption(BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 28),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
    );
  }
}