import 'package:flutter/material.dart';
import 'package:first_app/screens/expenses/category_page.dart';
import 'package:first_app/services/budget_alert_service.dart';

class SetAlertsPage extends StatefulWidget {
  final bool isEditing;
  final String? alertId;
  final String? initialCategory;
  final double? initialAmount;
  final String? initialFrequency;
  final String? initialCategoryId;

  const SetAlertsPage({
    Key? key,
    this.isEditing = false,
    this.alertId,
    this.initialCategory,
    this.initialCategoryId,
    this.initialAmount,
    this.initialFrequency,
  }) : super(key: key);

  @override
  State<SetAlertsPage> createState() => _SetAlertsPageState();
}

class _SetAlertsPageState extends State<SetAlertsPage> {
  final TextEditingController _amountController = TextEditingController();

  String? _categoryId;
  String _selectedCategory = "Select Category";
  String _selectedFrequency = 'Monthly';

  final List<String> _frequencies = ['Daily', 'Weekly', 'Monthly', 'Yearly'];

  @override
  void initState() {
    super.initState();

    if (widget.isEditing) {
      _selectedCategory = widget.initialCategory ?? "Select Category";
      _categoryId = widget.initialCategoryId;
      _amountController.text = widget.initialAmount?.toString() ?? "";
      _selectedFrequency = widget.initialFrequency ?? "Monthly";
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _onSave() async {
    final amount = double.tryParse(_amountController.text);

    if (_selectedCategory == 'Select Category') {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Please choose a category')));
      return;
    }
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Enter a valid budget amount')));
      return;
    }

    if (widget.isEditing) {
      // ---------------- UPDATE ALERT ----------------
      await BudgetAlertService().updateBudgetAlert(
        alertId: widget.alertId!,
        amount: amount,
        frequency: _selectedFrequency,
      );
    } else {
      // ---------------- ADD NEW ALERT ----------------
      await BudgetAlertService().addBudgetAlert(
        amount: amount,
        frequency: _selectedFrequency,
        categoryId: _categoryId,
        categoryName: _selectedCategory,
      );
    }

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        centerTitle: true,
        leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black87),
            onPressed: () => Navigator.pop(context)),
        title: Text(
          widget.isEditing ? "Edit Budget Alert" : "Set Budget Alert",
          style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        child: Column(
          children: [
            // Category row (disabled while editing)
            buildSelectableRow(
              label: 'Category',
              value: _selectedCategory,
              onTap: widget.isEditing ? null : () => _openCategorySelector(),
            ),

            const SizedBox(height: 16),

            buildTextField(
              'Budget Amount',
              _amountController,
              keyboard: TextInputType.number,
              prefixIcon: const Icon(Icons.currency_rupee, color: Colors.grey),
              hint: 'e.g. 5000',
            ),

            const SizedBox(height: 20),

            Align(
              alignment: Alignment.centerLeft,
              child: const Text(
                'Budget For',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: Colors.black87),
              ),
            ),
            const SizedBox(height: 8),
GridView.count(
  crossAxisCount: 2,
  shrinkWrap: true,
  physics: const NeverScrollableScrollPhysics(),
  crossAxisSpacing: 18,
  mainAxisSpacing: 18,
  childAspectRatio: 1.2, // Same as category page
  children: _frequencies.map((f) {
    final selected = f == _selectedFrequency;

    return GestureDetector(
      onTap: () => setState(() => _selectedFrequency = f),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF1CB0F6)
              : const Color(0xFFF4F4F4),
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(selected ? 0.25 : 0.15),
              blurRadius: selected ? 10 : 8,
              spreadRadius: selected ? 3 : 2,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: selected 
                ? const Color(0xFF1CB0F6)
                : Colors.transparent,
            width: 2,
          ),
        ),
        child: Center(
          child: Text(
            f,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : Colors.black87,
            ),
          ),
        ),
      ),
    );
  }).toList(),
),

            const SizedBox(height: 60),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _onSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF58CC02),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: Text(
                  widget.isEditing ? 'UPDATE ALERT' : 'SAVE ALERT',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 30),
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
        Text(label,
            style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: Colors.black87)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboard,
          decoration: InputDecoration(
            prefixIcon: prefixIcon,
            hintText: hint,
            filled: true,
            fillColor: const Color(0xFFF9F9F9),
            contentPadding:
                const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: Color(0xFFE0E0E0), width: 1.2)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: Color(0xFFE0E0E0), width: 1.2)),
          ),
        ),
      ],
    );
  }

  Widget buildSelectableRow({
    required String label,
    required String value,
    required VoidCallback? onTap,
  }) {
    final disabled = onTap == null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: Colors.black87)),
        const SizedBox(height: 6),
        Opacity(
          opacity: disabled ? 0.55 : 1,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF9F9F9),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: const Color(0xFFE0E0E0), width: 1.2),
              ),
              child: Row(
                children: [
                  Expanded(
                      child: Text(value,
                          style: const TextStyle(
                              fontSize: 15, color: Colors.black87))),
                  if (!disabled)
                    const Icon(Icons.chevron_right, color: Colors.black45),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }


  void _openCategorySelector() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CategoryPage(forIncome: false),
      ),
    );

    if (result != null && result is Map) {
      setState(() {
        _categoryId = result['id'];
        _selectedCategory = result['name'];
      });
    }
  }
}
