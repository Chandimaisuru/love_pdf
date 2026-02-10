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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: const BoxDecoration(
        color: Color(0xFF1E2F38), // ඔයාගේ ඇප් එකේ පසුබිමට වඩා පොඩ්ඩක් ලා පාටයි
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. පොඩි Drag Handle එකක් (උඩින්ම තියෙන පොඩි ඉර)
          Center(
            child: Container(
              width: 50,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 25),

          // 2. Title එක
          const Text(
            "Split Options",
            style: TextStyle(
              fontSize: 22, 
              fontWeight: FontWeight.bold,
              color: Colors.white, // සුදු අකුරු
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Choose how you want to split this PDF:",
            style: TextStyle(
              color: Colors.white.withOpacity(0.6), // අළු පාට
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 25),

          // Option 1: Extract (Keep)
          _buildOption(
            context,
            icon: Icons.check_circle_outline,
            color: Colors.greenAccent, // Neon Green වගේ පාටක්
            title: "Extract Pages",
            subtitle: "Select pages you want to keep.",
            onTap: onExtract,
          ),
          
          const SizedBox(height: 15), // බටන් අතර පරතරය

          // Option 2: Delete (Remove)
          _buildOption(
            context,
            icon: Icons.delete_outline_rounded,
            color: Colors.redAccent,
            title: "Delete Pages",
            subtitle: "Select pages you want to remove.",
            onTap: onDelete,
          ),

          const SizedBox(height: 30), // යටින් පොඩි ඉඩක්
        ],
      ),
    );
  }

  // Button Design එක (Professional Card Look)
  Widget _buildOption(BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05), // ලා පසුබිමක්
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)), // තුනී බෝඩර් එකක්
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 15),
            child: Row(
              children: [
                // Icon Box
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 28),
                ),
                const SizedBox(width: 15),
                
                // Texts
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16, 
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12, 
                          color: Colors.white.withOpacity(0.5),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Arrow Icon
                Icon(Icons.arrow_forward_ios_rounded, 
                  size: 16, 
                  color: Colors.white.withOpacity(0.3)
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}