import 'package:flutter/material.dart';

class GoalManagerSection extends StatelessWidget {
  const GoalManagerSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 🔹 Header Row (Title only, no timer here)
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            "Goals",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        const SizedBox(height: 10),

        // 🔸 White Card Container (like Duolingo's “Daily Quests”)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF4C338E), // subtle purple border
                width: 0.6,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _goalItem("Save for Home", 20000, 8500),
                const SizedBox(height: 14),
                _goalItem("Buy a Car", 10000, 4000),
                const SizedBox(height: 14),
                _goalItem("Vacation Fund", 5000, 2500),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Single Goal Item (Styled like Duolingo’s Quest Row)
  static Widget _goalItem(String goal, double target, double saved) {
    double progress = saved / target;
    progress = progress.clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 🔸 Title Row with Timer on Right
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              goal,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            Row(
              children: const [
                Icon(Icons.timer_outlined, color: Colors.orange, size: 16),
                SizedBox(width: 4),
                Text(
                  "5 DAYS",
                  style: TextStyle(
                    color: Colors.orange,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ],
        ),

        const SizedBox(height: 12),

        // 🔹 Progress Bar + Treasure Fixed at Bar End
        LayoutBuilder(
          builder: (context, constraints) {
            final double fullWidth = constraints.maxWidth;
            final double barHeight = 20;
            final double barRadius = 12;

            return Stack(
              alignment: Alignment.centerLeft,
              children: [
                // Background bar
                Container(
                  height: barHeight,
                  width: fullWidth,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E5E5),
                    borderRadius: BorderRadius.circular(barRadius),
                  ),
                ),

                // Green filled progress
                Container(
                  height: barHeight,
                  width: fullWidth * progress,
                  decoration: BoxDecoration(
                    color: const Color(0xFF58CC02),
                    borderRadius: BorderRadius.circular(barRadius),
                  ),
                ),

                // Treasure icon FIXED at the end of the background bar
                Positioned(
                  right: -6, // slight overlap for realistic look
                  child: Image.asset(
                    "asset/images/treasure.png",
                    height: 42,
                    width: 42,
                    fit: BoxFit.contain,
                  ),
                ),
              ],
            );
          },
        ),

        const SizedBox(height: 8),

        // 🔹 Progress text below bar
        Text(
          "${saved.toInt()} / ${target.toInt()} saved",
          style: const TextStyle(
            fontSize: 13,
            color: Colors.black54,
          ),
        ),
      ],
    );
  }
}
