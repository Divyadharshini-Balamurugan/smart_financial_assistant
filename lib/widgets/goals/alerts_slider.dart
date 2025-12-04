import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'pastel_icon_box.dart';
import 'package:first_app/screens/alerts/budget_alert_detail_page.dart';

/// ALERT SLIDER
/// Fetches alerts from Firestore:
/// users/{uid}/alerts/{alertId}
///
/// UI rules:
/// - If alerts exist → show pastel slider
/// - If none exist → return SizedBox.shrink() (show nothing)
class AlertSlider extends StatelessWidget {
  const AlertSlider({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    final collection = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('budget_alert');

    return StreamBuilder<QuerySnapshot>(
      stream: collection.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(
            height: 110,
            child: Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }

        final docs = snapshot.data!.docs;

        // No alerts → hide entire widget
        if (docs.isEmpty) {
          return const SizedBox.shrink(); // nothing displayed
        }

        return SizedBox(
          height: 120,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final String name = data['categoryName'] ?? 'Alert';

              // Soft pastel orange tones
              final List<Color> palette = [
                const Color(0xFFFFE9D5),
                const Color(0xFFFFF1E6),
                const Color(0xFFFFE4C7),
                const Color(0xFFFFDCC2),
              ];

              final color = palette[index % palette.length];

              return PastelIconBox(
                label: name,
                color: color,
                onTap: () {
                  final alertId = docs[index].id;

                  Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => BudgetAlertDetailPage(alertId: alertId),
                  ),
                );

                },
              );
            },
          ),
        );
      },
    );
  }
}
