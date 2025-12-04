import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'pastel_icon_box.dart';
import 'package:first_app/screens/goal/goal_details.dart';

/// GOAL SLIDER
/// Firestore location:
/// users/{uid}/goals/{goalId}
///
/// UI rules:
/// - If goals exist → show pastel horizontal slider
/// - If none → return SizedBox.shrink()
class GoalSlider extends StatelessWidget {
  const GoalSlider({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    final collection = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('goalSavings');

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

        // No goals → hide entire widget
        if (docs.isEmpty) {
          return const SizedBox.shrink();
        }

        return SizedBox(
          height: 120,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;

              final String name = data['goal'] ?? 'Goal';
              final String shortName = data['shortName'] ?? name;

              // Duolingo-style pastels (soft purple, blue, yellow)
              const List<Color> palette = [
                Color(0xFFE8E7FF), // soft lavender
                Color(0xFFDFF3FF), // soft baby blue
                Color(0xFFFFF4C7), // soft pastel yellow
                Color(0xFFE9F7FF), // frosty pale blue
                Color(0xFFF3E8FF), // pink-lavender
              ];

              final color = palette[index % palette.length];

              return PastelIconBox(
                label: shortName,
                color: color,
               onTap: () {
                final goalId = docs[index].id;

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => GoalDetailPage(goalId: goalId),
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
