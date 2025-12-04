// lib/set_goal_page.dart
// Updated: GoalSelectionPage now mirrors CategoryPage UI & behaviour

import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:first_app/services/goal_savings_service.dart';


/// SetGoalPage - styled to match add_expense_page.dart visuals
/// - Field fills: Color(0xFFF9F9F9)
/// - Rounded inputs and containers with 12px radius
/// - SAVE button matches the add_expense_page style
/// - Goal row opens GoalSelectionPage which now replicates CategoryPage

class SetGoalPage extends StatefulWidget {
  const SetGoalPage({Key? key}) : super(key: key);

  @override
  State<SetGoalPage> createState() => _SetGoalPageState();
}

class _SetGoalPageState extends State<SetGoalPage> {
  final TextEditingController _targetAmountController = TextEditingController();
  final TextEditingController _initialAmountController = TextEditingController(text: '0');
  final TextEditingController _plannedContributionController = TextEditingController();
  DateTime? _targetDate;

  String _selectedGoal = 'Select Goal';
  String _selectedFrequencyLabel = 'Weekly';
  Frequency _selectedFrequency = Frequency.weekly;

  double? _requiredContribution;
  int _periods = 0;

  bool _saving = false;

  @override
  void dispose() {
    _targetAmountController.dispose();
    _initialAmountController.dispose();
    _plannedContributionController.dispose();
    super.dispose();
  }

Future<void> _pickTargetDate() async {
  final now = DateTime.now();
  final tomorrow = DateTime(now.year, now.month, now.day + 1);

  final picked = await showDatePicker(
    context: context,
    initialDate: _targetDate ?? tomorrow,
    firstDate: tomorrow,
    lastDate: DateTime(now.year + 50),
  );

  if (picked != null) {
    setState(() => _targetDate = picked);
    _computeRequiredContribution();
  }
}


  void _openGoalSelection() async {
    final selected = await Navigator.push<String?>(
      context,
      MaterialPageRoute(builder: (_) => const GoalSelectionPage()),
    );
    if (selected != null) setState(() => _selectedGoal = selected);
  }

  void _selectFrequency(Frequency f) {
    setState(() {
      _selectedFrequency = f;
      _selectedFrequencyLabel = _freqLabel(f);
    });
    _computeRequiredContribution();
  }

  String _freqLabel(Frequency f) {
    switch (f) {
      case Frequency.daily:
        return 'Daily';
      case Frequency.weekly:
        return 'Weekly';
      case Frequency.monthly:
        return 'Monthly';
    }
  }

  void _computeRequiredContribution() {
    final target = double.tryParse(_targetAmountController.text.replaceAll(',', '')) ?? 0.0;
    final initial = double.tryParse(_initialAmountController.text.replaceAll(',', '')) ?? 0.0;

    if (target <= 0 || _targetDate == null) {
      setState(() {
        _requiredContribution = null;
        _periods = 0;
      });
      return;
    }

    final now = DateTime.now();
    final daysDiff = max(1, _targetDate!.difference(now).inDays);

    double periods;
    switch (_selectedFrequency) {
      case Frequency.daily:
        periods = daysDiff.toDouble();
        break;
      case Frequency.weekly:
        periods = max(1, daysDiff / 7.0);
        break;
      case Frequency.monthly:
        periods = max(1, daysDiff / 30.0);
        break;
    }

    final remaining = max(0.0, target - initial);
    final perPeriod = remaining / periods;

    setState(() {
      _requiredContribution = perPeriod;
      _periods = periods.ceil();
    });
  }

  String _formatAmount(double a) {
    if (a >= 10000000) return '${(a / 1000000).toStringAsFixed(1)}M';
    if (a >= 1000) return NumberFormat('#,###').format(a.round());
    return a.toStringAsFixed(a.truncateToDouble() == a ? 0 : 2);
  }

Future<void> _onSave() async {
  final target = double.tryParse(_targetAmountController.text.replaceAll(',', '')) ?? 0.0;
  final initial = double.tryParse(_initialAmountController.text.replaceAll(',', '')) ?? 0.0;

  // --- VALIDATION ---
  if (_selectedGoal == 'Select Goal') {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please choose a goal')),
    );
    return;
  }
  if (target <= 0) {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Enter a valid target amount')));
    return;
  }
  if (_targetDate == null ||
      !_targetDate!.isAfter(DateTime.now().add(const Duration(days: 1)))) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Target date must be at least tomorrow')),
    );
    return;
  }

  setState(() => _saving = true);

  final uid = FirebaseAuth.instance.currentUser!.uid;
  final service = GoalSavingsService();

  // Create model
  final model = GoalModel(
    id: '',
    goalName: _selectedGoal,
    targetAmount: target,
    initialAmount: initial,
    targetDate: _targetDate!,
    frequency: _selectedFrequencyLabel,
    requiredPerFrequency: _requiredContribution ?? 0.0,
    createdAt: DateTime.now(),
  );

  try {
    final goalId = await service.createGoal(uid, model);

    if (!mounted) return;

    setState(() => _saving = false);

    Navigator.pop(context, {
      'goalId': goalId,
      'goalName': _selectedGoal,
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Goal saved successfully!')),
    );
  } catch (e) {
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Failed to save goal: $e')),
    );
  }
}


  @override
  Widget build(BuildContext context) {
    const fieldColor = Color(0xFFF9F9F9);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black87), onPressed: () => Navigator.pop(context)),
        title: const Text('Set Goal', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        child: Column(
          children: [

            // Goal row (opens selection page)
            buildSelectableRow(
              label: 'Goal',
              value: _selectedGoal,
              onTap: _openGoalSelection,
            ),

            const SizedBox(height: 16),

            // Target Amount
            buildTextField(
              'Target Amount',
              _targetAmountController,
              keyboard: TextInputType.number,
              prefixIcon: const Icon(Icons.currency_rupee, color: Colors.grey, size: 20),
              hint: 'e.g. 20000',
            ),

            const SizedBox(height: 16),

            // Target Date
            buildSelectableRow(
              label: 'Target Date',
              value: _targetDate == null ? 'Choose date' : DateFormat('yyyy-MM-dd').format(_targetDate!),
              onTap: _pickTargetDate,
            ),

            const SizedBox(height: 16),

            // Initial Amount
            buildTextField(
              'Initial Amount',
              _initialAmountController,
              keyboard: TextInputType.number,
              prefixIcon: const Icon(Icons.savings, color: Colors.grey, size: 20),
              hint: 'Amount saved already',
            ),

            const SizedBox(height: 20),

            // Frequency pills (match page spacing)
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Contribution type', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: Colors.black87)),
            ),
            const SizedBox(height: 8),
            Row(
              children: Frequency.values.map((f) {
                final selected = f == _selectedFrequency;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6.0),
                    child: GestureDetector(
                      onTap: () => _selectFrequency(f),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: selected ? const Color.fromARGB(255, 229, 246, 254) : fieldColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: selected ? const Color(0xFF1CB0F6) : const Color(0xFFE0E0E0)),
                        ),
                        child: Column(
                          children: [
                            Text(_freqLabel(f), style: TextStyle(fontWeight: FontWeight.w700, color: selected ? const Color(0xFF1CB0F6) : Colors.black87)),
                            const SizedBox(height: 4),
                            const Text('Plan amount', style: TextStyle(fontSize: 11, color: Colors.black45)),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 16),

            // Planned contribution (optional)
            buildTextField(
              'Planned contribution per ${_selectedFrequencyLabel.toLowerCase()} (optional)',
              _plannedContributionController,
              keyboard: TextInputType.number,
              prefixIcon: const Icon(Icons.payments_outlined, color: Colors.grey, size: 20),
            ),

            const SizedBox(height: 18),

            // SAVE - matches add_expense style: green primary
            SizedBox(
              width:double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: () {
                  _computeRequiredContribution();
                  _onSave();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF58CC02),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: _saving
                    ? const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white))
                    : const Text('SAVE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
              ),
            ),

            const SizedBox(height: 36),
          ],
        ),
      ),
    );
  }

  Widget buildTextField(
    String label,
    TextEditingController controller, {
    TextInputType keyboard = TextInputType.text,
    Widget? prefixIcon,
    String? hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: Colors.black87)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboard,
          onChanged: (_) => _computeRequiredContribution(),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: prefixIcon,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            filled: true,
            fillColor: const Color(0xFFF9F9F9),

            // --- MATCH Select Goal style ---
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE0E0E0), width: 1.2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE0E0E0), width: 1.2),
            ),
          )

        ),
      ],
    );
  }

  Widget buildSelectableRow({required String label, required String value, required VoidCallback onTap}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: Colors.black87)),
        const SizedBox(height: 6),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF9F9F9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE0E0E0), width: 1.2),
            ),
            child: Row(
              children: [
                const SizedBox(width: 6),
                Expanded(child: Text(value, style: const TextStyle(fontSize: 15, color: Colors.black87))),
                const Icon(Icons.chevron_right, color: Colors.black45),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

enum Frequency { daily, weekly, monthly }

// --- GoalSelectionPage: now mirrors CategoryPage UI & behaviour ---

class GoalSelectionPage extends StatefulWidget {
  const GoalSelectionPage({Key? key}) : super(key: key);

  @override
  State<GoalSelectionPage> createState() => _GoalSelectionPageState();
}

class _GoalSelectionPageState extends State<GoalSelectionPage> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  List<Map<String, dynamic>> _goals = [];
  bool _isLoading = true;
  bool _showPopup = false;
  final TextEditingController _newGoalController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadGoals();
  }

  Future<void> _loadGoals() async {
    final user = _auth.currentUser;
    try {
      // global collection and user collection share same name here
      final globalSnap = await _firestore.collection('goalCategories').get();
      final globalGoals = globalSnap.docs
          .map((d) => {'id': d.id, 'name': d['name'] as String})
          .toList();

      List<Map<String, dynamic>> userGoals = [];
      if (user != null) {
        final userSnap = await _firestore.collection('users').doc(user.uid).collection('goalCategories').get();
        userGoals = userSnap.docs.map((d) => {'id': d.id, 'name': d['name'] as String}).toList();
      }

      // combine without duplicates by name
      final combinedNames = <String>{};
      final combined = <Map<String, dynamic>>[];
      for (final g in [...globalGoals, ...userGoals]) {
        if (!combinedNames.contains(g['name'])) {
          combinedNames.add(g['name']!);
          combined.add(g);
        }
      }

      setState(() {
        _goals = combined;
        _goals.add({'id': '+', 'name': '+'});
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading goals: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addUserGoal(String name) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final docRef = _firestore.collection('users').doc(user.uid).collection('goalCategories').doc();
      await docRef.set({
        'name': name,
        'createdAt': FieldValue.serverTimestamp(),
      });

      setState(() {
        _goals.insert(_goals.length - 1, {'id': docRef.id, 'name': name});
      });

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Goal "$name" added successfully!'), backgroundColor: Colors.green));
    } catch (e) {
      debugPrint('Error adding goal: $e');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to add goal'), backgroundColor: Colors.red));
    }
  }

  @override
  void dispose() {
    _newGoalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black), onPressed: () => Navigator.pop(context)),
        centerTitle: true,
        title: const Text('Choose Goal', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700, fontSize: 20)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 18,
                      mainAxisSpacing: 18,
                      childAspectRatio: 1.2,
                    ),
                    itemCount: _goals.length,
                    itemBuilder: (context, index) {
                      final goal = _goals[index];
                      return _buildGoalCard(context, goal);
                    },
                  ),
                ),

                if (_showPopup)
                  Container(
                    color: Colors.black.withOpacity(0.5),
                    child: Center(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
                        width: MediaQuery.of(context).size.width * 0.8,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Goal Name',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: _newGoalController,
                              decoration: InputDecoration(
                                hintText: 'Enter Name',
                                hintStyle: const TextStyle(color: Colors.black54, fontSize: 15),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                filled: true,
                                fillColor: Colors.grey.shade200,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      _showPopup = false;
                                      _newGoalController.clear();
                                    });
                                  },
                                  child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
                                ),
                                const SizedBox(width: 10),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF58CC02), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                                  onPressed: () async {
                                    final name = _newGoalController.text.trim();
                                    if (name.isNotEmpty) {
                                      await _addUserGoal(name);
                                      setState(() {
                                        _showPopup = false;
                                        _newGoalController.clear();
                                      });
                                    }
                                  },
                                  child: const Text('Add', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                                ),
                              ],
                            )
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildGoalCard(BuildContext context, Map<String, dynamic> goal) {
    final isAddButton = goal['name'] == '+';

    return GestureDetector(
      onTap: () {
        if (isAddButton) {
          setState(() => _showPopup = true);
        } else {
          Navigator.pop(context, goal['name'] as String);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: isAddButton ? const Color(0xFF58CC02) : const Color(0xFFF4F4F4),
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(color: Colors.grey.withOpacity(0.15), spreadRadius: 2, blurRadius: 8, offset: const Offset(0, 4)),
          ],
        ),
        child: Center(
          child: Text(
            goal['name'],
            textAlign: TextAlign.center,
            style: TextStyle(color: isAddButton ? Colors.white : Colors.black87, fontSize: 18, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}
