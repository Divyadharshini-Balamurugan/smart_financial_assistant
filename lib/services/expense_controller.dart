// lib/services/expense_controller.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:first_app/firestore_helpers.dart'; // adjust relative path if needed
import 'package:intl/intl.dart';

class ExpenseController {
  final String uid;

  ExpenseController({required this.uid});

  /// Validates & saves expense. Returns created DocumentReference on success.
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
    if (subcategory != null) {
      if (subcategory is String) {
        // we only got name — store it as name in notes or keep as null id
      } else if (subcategory is Map) {
        subcategoryId = subcategory['id']?.toString();
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

    // call your Firestore helper (it converts to UTC keys internally)
    final docRef = await addExpense(
      uid: uid,
      amount: amount,
      categoryId: categoryId ?? '',
      categoryName: categoryName,
      subcategoryId: subcategoryId,
      paymentModeId: paymentModeId,
      date: localDt, // local DateTime; your helper converts to UTC keys
      currency: currency,
      notes: notes,
    );

    return docRef;
  }
}
