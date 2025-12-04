import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:first_app/services/budget_alert_service.dart';

class RemindersSection extends StatefulWidget {
  const RemindersSection({super.key});

  @override
  State<RemindersSection> createState() => _RemindersSectionState();
}

class _RemindersSectionState extends State<RemindersSection> {
  final List<Map<String, String>> _staticReminders = [
    {
      "title": "Pay Credit Card Bill",
      "desc": "Your payment is due in 2 days. Avoid late fees!"
    },
    {
      "title": "Review Monthly Budget",
      "desc": "It’s time to check your October spending summary."
    },
    {
      "title": "Set Saving Goal",
      "desc": "Define your weekly saving target to stay consistent!"
    },
  ];

  final BudgetAlertService _budgetService = BudgetAlertService();
  List<Map<String, String>> _reminders = [];
  int _currentIndex = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _reminders = [..._staticReminders]; // start with static ones
    _loadBudgetAlerts();

    // Auto-slide every 120 seconds
    _timer = Timer.periodic(const Duration(seconds: 120), (timer) {
      setState(() {
        _currentIndex = (_currentIndex + 1) % _reminders.length;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _nextReminder() {
    setState(() {
      _currentIndex = (_currentIndex + 1) % _reminders.length;
    });
  }

  void _prevReminder() {
    setState(() {
      _currentIndex =
          (_currentIndex - 1 + _reminders.length) % _reminders.length;
    });
  }

  // 🔹 Fetch budget alerts and append those that exceed thresholds
  Future<void> _loadBudgetAlerts() async {
  final userAlerts = await FirebaseFirestore.instance
      .collection('users')
      .doc(_budgetService.uid!)
      .collection('budget_alert')
      .get();


    final List<Map<String, String>> alertsToShow = [];

    for (final doc in userAlerts.docs) {
      final alertData = doc.data();
      final spentResult = await _budgetService.calculateSpentForAlert(
        alertId: doc.id,
        period: alertData['frequency'] ?? 'Month',
      );

      final double totalSpent = spentResult['total'] ?? 0.0;
      final double limit = spentResult['limit'] ?? 0.0;

      // Add to reminders if spent >= 70% of limit
      if (totalSpent >= 0.7 * limit) {
        final status = totalSpent >= limit ? "❗ Over Budget!" : "⚠️ Approaching Limit";
        alertsToShow.add({
          "title": "${alertData['categoryName']} $status",
          "desc": "Spent \$${totalSpent.toStringAsFixed(2)} of \$${limit.toStringAsFixed(2)}"
        });
      }
    }

    if (alertsToShow.isNotEmpty) {
      setState(() {
        _reminders = [..._staticReminders, ...alertsToShow];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_reminders.isEmpty) return const SizedBox();

    final reminder = _reminders[_currentIndex];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              "Reminders",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Colors.black87,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: const Color(0xFF4C338E),
                width: 0.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.grey),
                  onPressed: _prevReminder,
                ),
                Flexible(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        reminder["title"]!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        reminder["desc"]!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 15,
                          color: Colors.black54,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        alignment: WrapAlignment.center,
                        children: [
                          _actionChip("Snooze", Colors.orangeAccent),
                          _actionChip("Done", Colors.green),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_forward_ios_rounded,
                      color: Colors.grey),
                  onPressed: _nextReminder,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionChip(String label, Color color) {
    return InkWell(
      onTap: () {},
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.6), width: 0.8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
      ),
    );
  }
}
