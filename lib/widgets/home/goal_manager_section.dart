import 'package:flutter/material.dart';
import 'package:first_app/services/goal_savings_service.dart';


class GoalManagerSection extends StatelessWidget {
  final List<GoalModel>? goals;

  const GoalManagerSection({super.key, this.goals});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Color(0xFF4C338E),
                width: 0.6,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.08),
                  blurRadius: 8,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),

            child: (goals == null || goals!.isEmpty)
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text(
                      "No goals yet. Add your first goal!",
                      style: TextStyle(color: Colors.black54),
                    ),
                  )
                : Column(
                    children: goals!.map((g) {
                      // Calculate total saved including contributions
                      double saved = g.initialAmount +
                          g.contributions.fold(
                              0, (sum, c) => sum + c.amount);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _goalItem(
                          g.goalName,
                          g.targetAmount,
                          saved,
                          g.targetDate,
                        ),
                      );
                    }).toList(),
                  ),
          ),
        ),
      ],
    );
  }

  static Widget _goalItem(
      String goal, double target, double saved, DateTime targetDate) {
    double progress = saved / target;
    progress = progress.clamp(0.0, 1.0);

    int remainingDays = targetDate.difference(DateTime.now()).inDays;
    String dayLabel;

    if (saved >= target) {
      dayLabel = "COMPLETED";
    } else if (remainingDays > 1) {
      dayLabel = "$remainingDays DAYS LEFT";
    } else if (remainingDays == 1) {
      dayLabel = "1 DAY LEFT";
    } else if (remainingDays == 0) {
      dayLabel = "TODAY";
    } else {
      dayLabel = "EXPIRED";
    }

    final dayColor = (saved >= target)
        ? Colors.green
        : (remainingDays < 0)
            ? Colors.red
            : Colors.orange;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
              children: [
                Icon(Icons.timer_outlined, color: dayColor, size: 16),
                const SizedBox(width: 4),
                Text(
                  dayLabel,
                  style: TextStyle(
                    color: dayColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ],
        ),

        const SizedBox(height: 12),

        LayoutBuilder(
          builder: (context, constraints) {
            final double fullWidth = constraints.maxWidth;
            const double barHeight = 20;
            const double barRadius = 12;

            return Stack(
              alignment: Alignment.centerLeft,
              children: [
                Container(
                  height: barHeight,
                  width: fullWidth,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E5E5),
                    borderRadius: BorderRadius.circular(barRadius),
                  ),
                ),
                Container(
                  height: barHeight,
                  width: fullWidth * progress,
                  decoration: BoxDecoration(
                    color: const Color(0xFF58CC02),
                    borderRadius: BorderRadius.circular(barRadius),
                  ),
                ),
                Positioned(
                  right: -6,
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
