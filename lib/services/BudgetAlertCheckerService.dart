import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'budget_alert_service.dart';

class BudgetAlertCheckerService {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _alertService = BudgetAlertService();

  String get uid => _auth.currentUser!.uid;

  Future<void> checkBudgetAfterExpense({
    required String categoryId,
    required String categoryName,
  }) async {
    // fetch all alerts of that user matching that category
    final alertsSnap = await _firestore
        .collection('users')
        .doc(uid)
        .collection('budget_alert')
        .where('categoryId', isEqualTo: categoryId)
        .get();

    if (alertsSnap.docs.isEmpty) return;

    for (final alertDoc in alertsSnap.docs) {
      final alert = alertDoc.data();
      final frequency = alert['frequency'] ?? 'Daily';

      final result = await _alertService.calculateSpentForAlert(
        alertId: alertDoc.id,
        period: frequency,       
      );

      final double limit = result['limit'] ?? 0;
      final double spent = result['total'] ?? 0;
      final double percent = (spent / limit) * 100;

      String? message;

      if (percent >= 100) {
        message =
            "⚠️ You have exhausted your $frequency budget for $categoryName. (₹$spent / ₹$limit)";
      } else if (percent >= 80) {
        message =
            "⚠️ You have crossed 80% of your $frequency budget for $categoryName. (₹$spent / ₹$limit)";
      } else if (percent >= 50) {
        message =
            "⌛ You reached 50% of your $frequency budget for $categoryName. (₹$spent / ₹$limit)";
      }

      if (message != null) {
        await _storeSuggestion(message);
      }
    }
  }

  Future<void> _storeSuggestion(String msg) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('alert_messages')
        .add({
      "message": msg,
      "createdAt": Timestamp.now(),
    });

    // also update last suggestion timestamp on users collection
    await _firestore.collection('users').doc(uid).update({
      "lastalertUpdate": DateTime.now().millisecondsSinceEpoch
    });
  }
}
