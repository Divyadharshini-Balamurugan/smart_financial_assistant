import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:first_app/widgets/home/header_section.dart';
import 'package:first_app/widgets/home/suggestions_section.dart';
import 'package:first_app/widgets/home/goal_manager_section.dart';
import 'package:first_app/widgets/home/reminders_section.dart';
import 'package:first_app/widgets/home/export_data_section.dart';
import '/services/goal_savings_service.dart';

class HomePage extends StatelessWidget {
  HomePage({super.key});

  final GoalSavingsService _goalService = GoalSavingsService();

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 80),
          child: Column(
            children: [
              const HeaderSection(),
              const SizedBox(height: 20),
              const SuggestionsSection(),
              const SizedBox(height: 20),

              // ⭐ Fetch REAL user goals here
              if (user != null)
                StreamBuilder<List<GoalModel>>(
                stream: _goalService.watchGoals(user.uid),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(),
                    );
                  }

                  final goals = snapshot.data ?? [];

                  return GoalManagerSection(goals: goals);
                },
              )

              else
                const GoalManagerSection(),

              const SizedBox(height: 20),
              const RemindersSection(),
              const SizedBox(height: 20),
              const ExportDataSection(),
            ],
          ),
        ),
      ),
    );
  }
}
