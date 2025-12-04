import 'package:flutter/material.dart';
import 'set_goal_page.dart';
import '../alerts/set_alerts.dart';
import 'package:first_app/widgets/goals/goal_slider.dart';
import 'package:first_app/widgets/goals/alerts_slider.dart';

class GoalPage extends StatelessWidget {
  const GoalPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 255, 255, 255),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black87,
        title: const Text(
          'Budget & Goal',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),

      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [

                      // -------------------- ALERT ACTION CARD --------------------
                      _BigActionCard(
                        title: 'Set Alerts',
                        subtitle: 'Get notified when you approach your budget',
                        leading: _CircleIcon(
                          child: const Icon(Icons.notifications_none, size: 26),
                          color: Colors.indigo.shade50,
                        ),
                        
                        onTap: () {
                           Navigator.push(context,
                            MaterialPageRoute(builder: (_) => const SetAlertsPage())
                          );
                        },
                        
                      ),

                  

                      const SizedBox(height: 18),

                      // -------------------- GOAL ACTION CARD --------------------
                      _BigActionCard(
                        title: 'Set Goal',
                        subtitle: 'Create a saving or spending goal',
                        leading: _CircleIcon(
                          child: const Icon(Icons.flag_outlined, size: 26),
                          color: Colors.amber.shade50,
                        ),
                        onTap: () {
                          Navigator.push(context,
                            MaterialPageRoute(builder: (_) => const SetGoalPage())
                          );
                        },
                      ),

                      const SizedBox(height: 24),

                      // -------------------- ALERT SLIDER --------------------
                      const Text(
                      "Alerts",
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: 12),
                    const AlertSlider(),   // hides automatically if empty

                    SizedBox(height: 26),

                    // ---- GOALS ----
                    const Text(
                      "Goals",
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: 12),
                    const GoalSlider(),  
                    ],
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


/// Big action card (Set Alerts / Set Goal)
class _BigActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget leading;
  final VoidCallback onTap;

  const _BigActionCard({
    required this.title,
    required this.subtitle,
    required this.leading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF4C338E), width: 0.8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        child: Row(
          children: [
            leading,
            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),

            const Icon(Icons.chevron_right, color: Colors.black38),
          ],
        ),
      ),
    );
  }
}


/// Small circular icon container
class _CircleIcon extends StatelessWidget {
  final Widget child;
  final Color color;

  const _CircleIcon({required this.child, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Center(child: child),
    );
  }
}
