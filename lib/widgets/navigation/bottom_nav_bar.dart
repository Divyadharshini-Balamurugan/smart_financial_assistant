import 'package:flutter/material.dart';

class CustomBottomNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemTapped;

  const CustomBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onItemTapped,
  });

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      color: Colors.white,
      elevation: 10,
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // 🏠 Home
            navItem(Icons.home, 0),
            // 📈 Analytics
            navItem(Icons.show_chart, 1),

            const SizedBox(width: 40), // space for FAB

            // 🎯 Goal
            navItem(Icons.track_changes_outlined, 2),
            // ⚙️ Settings
            navItem(Icons.settings, 3),
          ],
        ),
      ),
    );
  }

  // 🟣 Navigation Item Widget
  Widget navItem(IconData icon, int index) {
    bool selected = selectedIndex == index;
    return GestureDetector(
      onTap: () => onItemTapped(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: selected
              ? Border.all(
                  color: const Color(0xFF1CB0F6).withOpacity(0.4),
                  width: 2,
                )
              : null,
          color: selected
              ? const Color(0xFF1CB0F6).withOpacity(0.08)
              : Colors.transparent,
        ),
        child: Icon(
          icon,
          size: 28,
          color: selected
              ? const Color(0xFF1CB0F6)
              : const Color(0xFF4C338E),
        ),
      ),
    );
  }
}
