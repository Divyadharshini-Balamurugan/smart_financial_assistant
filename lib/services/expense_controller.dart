// lib/services/expense_controller.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:first_app/firestore_helpers.dart'; // adjust relative path if needed
import 'package:intl/intl.dart';

class ExpenseController {
  final String uid;

  ExpenseController({required this.uid});

  /// Validates & saves expense/income. Returns created DocumentReference on success.
  /// category can be either a String (name) or a Map {'id': '...', 'name': '...'}
  /// same for paymentMode.
  Future<DocumentReference> saveExpense({
    required String amountText,
    required String dateText, // yyyy-MM-dd
    required String timeText, // hh:mm a
    required bool isExpense,
    Object? category, // String or Map
    Object? subcategory, // String or Map (optional)
    Object? paymentMode, // String or Map
    String currency = 'INR',
    String? notes,
  }) async {
    // normalize amount
    final cleaned = amountText.replaceAll(',', '').trim();
    final amount = double.tryParse(cleaned);
    if (amount == null || amount <= 0) {
      throw ArgumentError('Enter a valid amount');
    }

    // parse date and time
    DateTime datePart;
    try {
      datePart = DateFormat('yyyy-MM-dd').parseStrict(dateText);
    } catch (e) {
      throw ArgumentError('Invalid date format');
    }

    DateTime timePart;
    try {
      timePart = DateFormat('hh:mm a').parseStrict(timeText);
    } catch (e) {
      throw ArgumentError('Invalid time format');
    }

    // combine into local DateTime
    final localDt = DateTime(
      datePart.year,
      datePart.month,
      datePart.day,
      timePart.hour,
      timePart.minute,
    );

    // derive categoryId/name safely
    String? categoryId;
    String? categoryName;
    if (category != null) {
      if (category is String) {
        categoryName = category;
      } else if (category is Map) {
        categoryId = category['id']?.toString();
        categoryName = category['name']?.toString();
      }
    }

    String? subcategoryId;
    String? subcategoryName;
    if (subcategory != null) {
      if (subcategory is String) {
        subcategoryName = subcategory;
      } else if (subcategory is Map) {
        subcategoryId = subcategory['id']?.toString();
        subcategoryName = subcategory['name']?.toString();
      }
    }

    String? paymentModeId;
    String? paymentModeName;
    if (paymentMode != null) {
      if (paymentMode is String) {
        paymentModeName = paymentMode;
      } else if (paymentMode is Map) {
        paymentModeId = paymentMode['id']?.toString();
        paymentModeName = paymentMode['name']?.toString();
      }
    }

    // Build the payload common to both expense & income
    final payload = {
      'amount': amount,
      'currency': currency,
      'categoryId': categoryId ?? '',
      'categoryName': categoryName ?? '',
      'subcategoryId': subcategoryId ?? '',
      'subcategoryName': subcategoryName ?? '',
      'paymentModeId': paymentModeId ?? '',
      'paymentModeName': paymentModeName ?? '',
      'notes': notes ?? '',
      'createdAt': DateTime.now().toUtc(),
      'localDateTime': localDt.toIso8601String(), // keep local iso for UI if needed
    };

    // Branch: expense vs income
    if (isExpense) {
      final docRef = await addExpense(
        uid: uid,
        amount: amount,
        categoryId: categoryId ?? '',
        categoryName: categoryName,
        subcategoryId: subcategoryId,
        paymentModeId: paymentModeId,
        date: localDt,
        currency: currency,
        notes: notes,
      );
      return docRef;
    } else {
      // Save to incomes subcollection
      final docRef = await addIncome(
        uid: uid,
        amount: amount,
        categoryId: categoryId ?? '',
        categoryName: categoryName,
        subcategoryId: subcategoryId,
        paymentModeId: paymentModeId,
        date: localDt,
        currency: currency,
        notes: notes,
      );
      return docRef;
    }
  }
}
