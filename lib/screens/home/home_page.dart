import 'package:flutter/material.dart';
import 'package:first_app/widgets/home/header_section.dart';
import 'package:first_app/widgets/home/suggestions_section.dart';
import 'package:first_app/widgets/home/goal_manager_section.dart';
import 'package:first_app/widgets/home/reminders_section.dart';
import 'package:first_app/widgets/home/export_data_section.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 80),
          child: Column(
            children: const [
              HeaderSection(),
              SizedBox(height: 20),
              SuggestionsSection(),
              SizedBox(height: 20),
              GoalManagerSection(),
              SizedBox(height: 20),
              RemindersSection(),
              SizedBox(height: 20),
              ExportDataSection(),
            ],
          ),
        ),
      ),
    );
  }
}
