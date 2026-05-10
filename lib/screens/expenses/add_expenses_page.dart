// add_expense_page.dart
import 'package:first_app/screens/expenses/payment_method_page.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'category_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:first_app/services/expense_controller.dart';
import 'subcategory_page.dart';
import 'package:first_app/services/BudgetAlertCheckerService.dart';
import 'package:first_app/services/distribution_budget_checker_service.dart';
import 'package:first_app/services/suggestion_service.dart';
import 'package:first_app/services/tips/tips_trigger_service.dart';
import 'package:record/record.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

class AddExpensePage extends StatefulWidget {
  const AddExpensePage({super.key});
  

  @override
  State<AddExpensePage> createState() => _AddExpensePageState();
}

class _AddExpensePageState extends State<AddExpensePage> {
  bool isExpense = true;
  bool isRecording = false;
  bool isProcessingVoice = false;

  

  final amountController = TextEditingController();
  final dateController = TextEditingController();
  final timeController = TextEditingController();
  final recorder = AudioRecorder();

  String? selectedCategoryId;
  String selectedCategoryName = "Select Category";

  String? selectedSubcategoryId;
  String selectedSubcategoryName = "Select Subcategory";

  String? selectedPaymentModeId;
  String selectedPaymentModeName = "Select Payment Mode";

  late ExpenseController _controller;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    dateController.text = DateFormat('yyyy-MM-dd').format(now);
    timeController.text = DateFormat('hh:mm a').format(now);
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    _controller = ExpenseController(uid: uid);
  }

Future<void> startRecording() async {
  if (await recorder.hasPermission()) {

    final dir = await getTemporaryDirectory();

    final path =
        '${dir.path}/expense_recording.m4a';

    await recorder.start(
      const RecordConfig(),
      path: path,
    );
  }
}

  Future<String?> stopRecording() async {
    return await recorder.stop();
  }

  Future<void> uploadAudio(String path) async {
  try {

    setState(() {
      isProcessingVoice = true;
    });

    const baseUrl = "http://192.168.0.101:5000";

    Dio dio = Dio();

    FormData formData = FormData.fromMap({
      "audio": await MultipartFile.fromFile(path),
    });

    Response response = await dio.post(
      "$baseUrl/transcribe",
      data: formData,
    );

    final data = response.data;

    print(data);

    amountController.text =
        data["amount"].toString();

    setState(() {
      selectedCategoryId =
          data["category_id"];

      selectedCategoryName =
        data["category_name"] ??
        "Select Category";

      selectedSubcategoryId =
          data["subcategory_id"];

      selectedSubcategoryName =
        data["subcategory_name"] ??
        "Select Subcategory";

      selectedPaymentModeId =
          data["payment_mode_id"];

      selectedPaymentModeName =
      data["payment_mode_name"] ??
      "Select Payment Mode";
    });

  } catch (e) {

    print(e);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          "Voice processing failed",
        ),
      ),
    );

  } finally {

    setState(() {
      isProcessingVoice = false;
    });

  }
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

  Future<void> _onSave() async {
    if (FirebaseAuth.instance.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User not signed in')));
      return;
    }

    setState(() => _saving = true);

    try {
      final categoryId = selectedCategoryId;  
      final subcategoryId = selectedSubcategoryId;
      final paymentModeId = selectedPaymentModeId;
      final docRef = await _controller.saveExpense(
        amountText: amountController.text,
        dateText: dateController.text,
        timeText: timeController.text,
        isExpense: isExpense, // IMPORTANT: controller branches on this flag
        category: selectedCategoryId,
        subcategory: selectedSubcategoryId,
        paymentMode: selectedPaymentModeId,

        notes: null,
      );
if (isExpense && selectedCategoryId != null) {
  await BudgetAlertCheckerService().checkBudgetAfterExpense(
    categoryId: selectedCategoryId!,
    categoryName: selectedCategoryName,
  );

  // await DistributionBudgetCheckerService().checkAfterNewExpense(
  //   category: selectedCategoryName,
  //   expenseAmount: double.tryParse(amountController.text) ?? 0,
  // );

  // 🔔 Trigger tips after successful expense save
  await TipsTriggerService().onExpenseLogged(
    FirebaseAuth.instance.currentUser!.uid,
  );
}

// 🔁 Refresh suggestions ONCE
await SuggestionService.instance.refreshAndPush();

      

      // success message depends on type
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isExpense ? 'Expense saved' : 'Income saved')));

      Navigator.of(context).pop(docRef.id);
    } on ArgumentError catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const fieldColor = Color(0xFFF9F9F9);
    // accent color changes slightly for income vs expense if you want visual cue
    final accentColor = isExpense ? const Color(0xFF1CB0F6) : const Color(0xFF58CC02);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          isExpense ? 'Add Expense' : 'Add Income',
          style: const TextStyle(
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

            // Expense / Income Toggle
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
                          color: isExpense ? accentColor : Colors.grey[300],
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
                          color: !isExpense ? accentColor : Colors.grey[300],
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

            // Date & Time
            Row(
              children: [
                Expanded(
                  child: buildTextField(
                    "Date",
                    dateController,
                    readOnly: true,
                    onTap: _selectDate,
                    prefixIcon: const Icon(Icons.calendar_today_outlined, color: Colors.grey, size: 20),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: buildTextField(
                    "Time",
                    timeController,
                    readOnly: true,
                    onTap: _selectTime,
                    prefixIcon: const Icon(Icons.access_time_outlined, color: Colors.grey, size: 20),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Amount
            buildTextField(
              "Amount",
              amountController,
              keyboard: TextInputType.number,
              prefixIcon: const Icon(Icons.currency_rupee, color: Colors.grey, size: 20),
            ),

            const SizedBox(height: 20),

            // Category Selector
            buildSelectableRow(
              label: "Category",
              value: selectedCategoryName,
              onTap: () async {
                // pass forIncome flag so CategoryPage loads income_categories when needed
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => CategoryPage(forIncome: !isExpense)),
                );

                if (result != null && result is Map) {
                  setState(() {
                    selectedCategoryId = result['id'];
                    selectedCategoryName = result['name'];
                    selectedSubcategoryId = null;
                    selectedSubcategoryName = "Select Subcategory";
                  });
                }
              },
            ),

            const SizedBox(height: 20),

            // Subcategory Selector — always allowed
            buildSelectableRow(
              label: "Subcategory (optional)",
              value: selectedSubcategoryName,
              onTap: () async {
                if (selectedCategoryId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Please select a category first.")),
                  );
                  return;
                }

                final subcategoryResult = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SubcategoryPage(
                      categoryId: selectedCategoryId!,
                      categoryName: selectedCategoryName,
                      forIncome: !isExpense, // pass the flag so SubcategoryPage uses income_categories when needed
                    ),
                  ),
                );

                if (subcategoryResult != null && subcategoryResult is Map) {
                  setState(() {
                    selectedSubcategoryId = subcategoryResult['id'];
                    selectedSubcategoryName = subcategoryResult['name'];
                  });
                }
              },
            ),

            const SizedBox(height: 20),

            // Payment Mode Selector
            buildSelectableRow(
              label: "Payment Mode",
              value: selectedPaymentModeName,
              onTap: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const PaymentMethodPage()),
                );

                if (result != null && result is Map<String, String>) {
                  setState(() {
                    selectedPaymentModeId = result['id'];
                    selectedPaymentModeName = result['name']!;
                  });
                }
              },
            ),

            const SizedBox(height: 30),

// Save + Mic Row
Row(
  children: [

    // SAVE BUTTON
    Expanded(
      child: SizedBox(
        height: 58,
        child: ElevatedButton(
          onPressed: _onSave,
          style: ElevatedButton.styleFrom(
            backgroundColor:
                isExpense ? const Color(0xFF58CC02) : const Color(0xFF1CB0F6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            elevation: 0,
          ),
          child: _saving
              ? const CircularProgressIndicator(
                  valueColor:
                      AlwaysStoppedAnimation<Color>(Colors.white),
                )
              : const Text(
                  "SAVE",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    letterSpacing: 0.5,
                  ),
                ),
        ),
      ),
    ),

    const SizedBox(width: 14),

    // MIC BUTTON
    GestureDetector(
      onTap: () async {
  if (!isRecording) {
    await startRecording();

    setState(() {
      isRecording = true;
    });
  } else {
    String? path = await stopRecording();

    setState(() {
      isRecording = false;
    });

    print(path);

    if (path != null) {
      uploadAudio(path);
    }
  }
},
      child: Container(
        height: 58,
        width: 58,
        decoration: BoxDecoration(
          color: const Color(0xFF1CB0F6),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
child: isProcessingVoice
    ? const SizedBox(
        height: 24,
        width: 24,
        child: CircularProgressIndicator(
          color: Colors.white,
          strokeWidth: 2.5,
        ),
      )
    : Icon(
        isRecording
            ? Icons.stop_rounded
            : Icons.mic_rounded,
        color: Colors.white,
        size: 30,
      ),
      ),
    ),
  ],
),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

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
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: Colors.black87)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: isPassword,
          readOnly: readOnly,
          keyboardType: keyboard,
          onTap: onTap,
          decoration: InputDecoration(
            prefixIcon: prefixIcon,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            filled: true,
            fillColor: const Color(0xFFF9F9F9),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE0E0E0), width: 1.2),
            ),
          ),
        ),
      ],
    );
  }

  Widget buildSelectableRow({
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: Colors.black87)),
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
                const SizedBox(width: 12),
                Expanded(
                  child: Text(value, style: const TextStyle(fontSize: 15, color: Colors.black87)),
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
