import 'package:flutter/material.dart';
import 'package:first_app/screens/home/home_page.dart';
import 'package:first_app/screens/analytics/analytics_page.dart';
import 'package:first_app/screens/goal/add_goal_page.dart';
import 'package:first_app/screens/settings/settings_page.dart';
import 'package:first_app/screens/expenses/add_expenses_page.dart';
import 'package:first_app/widgets/navigation/bottom_nav_bar.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _selectedIndex = 0;

  // 🧭 Page List in Order
  final List<Widget> _pages = [
    HomePage(),
    const AnalyticsPage(),
    const GoalPage(),
    const SettingsPage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: CustomBottomNav(
        selectedIndex: _selectedIndex,
        onItemTapped: _onItemTapped,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF1CB0F6),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddExpensePage()),
          );
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
