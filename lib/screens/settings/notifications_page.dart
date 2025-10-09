import 'package:flutter/material.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  bool notifications = true;
  bool reminders = true;
  bool goalAlerts = false;
  bool suggestions = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.grey),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Notifications",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                children: [
                  _buildToggleTile(
                    title: "Notifications",
                    value: notifications,
                    onChanged: (val) {
                      setState(() {
                        notifications = val;
                      });
                    },
                  ),
                  const Divider(height: 1),
                  _buildToggleTile(
                    title: "Reminders",
                    value: reminders,
                    onChanged: (val) {
                      setState(() {
                        reminders = val;
                      });
                    },
                  ),
                  const Divider(height: 1),
                  _buildToggleTile(
                    title: "Goal Alerts",
                    value: goalAlerts,
                    onChanged: (val) {
                      setState(() {
                        goalAlerts = val;
                      });
                    },
                  ),
                  const Divider(height: 1),
                  _buildToggleTile(
                    title: "Suggestions",
                    value: suggestions,
                    onChanged: (val) {
                      setState(() {
                        suggestions = val;
                      });
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleTile({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: const Color(0xFF1E90FF),
            inactiveTrackColor: Colors.grey.shade300,
          ),
        ],
      ),
    );
  }
}
