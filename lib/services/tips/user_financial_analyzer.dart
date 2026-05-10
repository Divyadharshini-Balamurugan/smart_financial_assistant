import 'package:cloud_firestore/cloud_firestore.dart';

class UserFinancialAnalyzer {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<Map<String, dynamic>> analyze(String uid) async {
    final survey = await _db.collection('users/$uid/surveyResponses').get();
    final expenses = await _db.collection('users/$uid/expenses').get();
    final incomes = await _db.collection('users/$uid/incomes').get();
    final budgets = await _db.collection('users/$uid/budget_alert').get();
    final goals = await _db.collection('users/$uid/goalSavings').get();

    double totalExpenses = 0;
    Map<String, double> categorySpend = {};

    for (var doc in expenses.docs) {
      final amt = (doc['amount'] ?? 0).toDouble();
      final cat = doc['categoryName'] ?? 'Other';
      totalExpenses += amt;
      categorySpend[cat] = (categorySpend[cat] ?? 0) + amt;
    }

    double totalIncome = incomes.docs.fold(
      0,
      (sum, d) => sum + (d['amount'] ?? 0),
    );

    return {
      "survey": survey.docs,
      "expenses": categorySpend,
      "totalExpenses": totalExpenses,
      "totalIncome": totalIncome,
      "budgets": budgets.docs,
      "goals": goals.docs,
    };
  }
}
