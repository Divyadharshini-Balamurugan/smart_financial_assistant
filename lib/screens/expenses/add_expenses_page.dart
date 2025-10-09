import 'package:first_app/screens/expenses/payment_mode_Page.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'category_page.dart';

class AddExpensePage extends StatefulWidget {
  const AddExpensePage({super.key});

  @override
  State<AddExpensePage> createState() => _AddExpensePageState();
}

class _AddExpensePageState extends State<AddExpensePage> {
  bool isExpense = true;

  final amountController = TextEditingController();
  final dateController = TextEditingController();
  final timeController = TextEditingController();

  String selectedCategory = "Select Category";
  String selectedSubcategory = "Select Subcategory";
  String selectedPaymentMode = "Select Payment Mode";

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    dateController.text = DateFormat('yyyy-MM-dd').format(now);
    timeController.text = DateFormat('hh:mm a').format(now);
  }

  Future<void> _selectDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        dateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<void> _selectTime() async {
    final now = TimeOfDay.now();
    final picked = await showTimePicker(
      context: context,
      initialTime: now,
    );
    if (picked != null) {
      final dt = DateTime(0, 0, 0, picked.hour, picked.minute);
      setState(() {
        timeController.text = DateFormat('hh:mm a').format(dt);
      });
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Add Expense',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(
          children: [
            const SizedBox(height: 20),

            // 🔹 Expense / Income Toggle
            Container(
              decoration: BoxDecoration(
                color: fieldColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE0E0E0)),
              ),
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => isExpense = true),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        height: 46,
                        decoration: BoxDecoration(
                          color: isExpense
                              ? const Color(0xFF1CB0F6)
                              : Colors.grey[300],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            'Expense',
                            style: TextStyle(
                              color: isExpense ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => isExpense = false),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        height: 46,
                        decoration: BoxDecoration(
                          color: !isExpense
                              ? const Color(0xFF1CB0F6)
                              : Colors.grey[300],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            'Income',
                            style: TextStyle(
                              color: !isExpense ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // 🔹 Date & Time
            Row(
              children: [
                Expanded(
                  child: buildTextField(
                    "Date",
                    dateController,
                    readOnly: true,
                    onTap: _selectDate,
                    prefixIcon: const Icon(Icons.calendar_today_outlined,
                        color: Colors.grey, size: 20),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: buildTextField(
                    "Time",
                    timeController,
                    readOnly: true,
                    onTap: _selectTime,
                    prefixIcon: const Icon(Icons.access_time_outlined,
                        color: Colors.grey, size: 20),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // 🔹 Amount
            buildTextField(
              "Amount",
              amountController,
              keyboard: TextInputType.number,
              prefixIcon: const Icon(
                Icons.currency_rupee,
                color: Colors.grey,
                size: 20,
              ),
            ),

            const SizedBox(height: 20),

            // 🔹 Category Selector Row
            buildSelectableRow(
              label: "Category",
              value: selectedCategory,
              onTap: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CategoryPage()),
              );

              if (result != null && result is String) {
                setState(() {
                  selectedCategory = result;
                });
              }
            },
            ),

            const SizedBox(height: 20),

            // 🔹 Subcategory Selector Row
            buildSelectableRow(
              label: "Subcategory (optional)",
              value: selectedSubcategory,
              onTap: () {
                // TODO: Navigate to subcategory page
              },
            ),

            const SizedBox(height: 20),

            // 🔹 Payment Mode Selector Row
            buildSelectableRow(
              label: "Payment Mode",
              value: selectedPaymentMode,
              onTap: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PaymentMethodPage()),
              );

              if (result != null && result is String) {
                setState(() {
                  selectedPaymentMode = result;
                });
              }
            },
            ),

            const SizedBox(height: 30),

            // 🔹 Continue Button
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF58CC02), // Duolingo green
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  "SAVE",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  /// 🔹 Duolingo-style TextField builder
  Widget buildTextField(
    String label,
    TextEditingController controller, {
    bool isPassword = false,
    bool readOnly = false,
    VoidCallback? onTap,
    TextInputType keyboard = TextInputType.text,
    Widget? prefixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: isPassword,
          readOnly: readOnly,
          keyboardType: keyboard,
          onTap: onTap,
          decoration: InputDecoration(
            prefixIcon: prefixIcon,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            filled: true,
            fillColor: const Color(0xFFF9F9F9),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: Color(0xFFE0E0E0), width: 1.2),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: Color(0xFFE0E0E0), width: 1.2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: Color(0xFFBDBDBD), width: 1.4),
            ),
          ),
          style: const TextStyle(
            fontSize: 15,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  /// 🔹 Custom Row for tappable fields (Category / Payment / Subcategory)
  Widget buildSelectableRow({
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 6),
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF9F9F9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE0E0E0), width: 1.2),
            ),
            child: Row(
              children: [
                // Icon(icon, color: Colors.grey, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    value,
                    style: const TextStyle(
                      fontSize: 15,
                      color: Colors.black87,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.black45),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
