import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AnalyticsService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  /// 🔹 Build Firestore date keys used for filtering
  Map<String, String> _buildKeys(DateTime date) {
    final yyyy = date.year.toString();
    final mm = date.month.toString().padLeft(2, '0');
    final dd = date.day.toString().padLeft(2, '0');
    final weekOfYear = _getWeekNumber(date);

    return {
      'dateKey': '$yyyy-$mm-$dd', // e.g., 2025-11-09
      'monthKey': '$yyyy-$mm',    // e.g., 2025-11
      'yearKey': yyyy,            // e.g., 2025
      'weekKey': '$yyyy-W$weekOfYear', // e.g., 2025-W45
    };
  }

  /// 🔸 Get ISO-like week number for a given date
  int _getWeekNumber(DateTime date) {
    final firstDayOfYear = DateTime(date.year, 1, 1);
    final daysOffset = firstDayOfYear.weekday - DateTime.monday;
    final firstMonday = firstDayOfYear.subtract(Duration(days: daysOffset));
    final diff = date.difference(firstMonday).inDays;
    return ((diff / 7).floor()) + 1;
  }

  /// 🔹 Fetch total Expense and Income filtered by period (Day / Week / Month / Year)
  Future<Map<String, double>> fetchTotals({
    required String period,
    required DateTime date,
  }) async {
    if (_uid == null) throw Exception("User not logged in");

    final userRef = _db.collection('users').doc(_uid);
    final keys = _buildKeys(date);

    Query<Map<String, dynamic>> query =
        userRef.collection('expenses'); // stores both expense & income docs

    // Apply date filters based on selected period
    if (period == 'Day') {
      query = query.where('dateKey', isEqualTo: keys['dateKey']);
    } else if (period == 'Week') {
      query = query.where('weekKey', isEqualTo: keys['weekKey']);
    } else if (period == 'Month') {
      query = query.where('monthKey', isEqualTo: keys['monthKey']);
    } else if (period == 'Year') {
      query = query.where('yearKey', isEqualTo: keys['yearKey']);
    }

    final snapshot = await query.get();

    double totalExpense = 0.0;
    double totalIncome = 0.0;

    for (final doc in snapshot.docs) {
      final data = doc.data();

      // Defensive checks
      if (!data.containsKey('amount') || data['amount'] == null) continue;

      final double amount = (data['amount'] as num).toDouble();

      // Decide based on a type field or categoryName
      final type = data['type']?.toString().toLowerCase();
      final category = data['categoryName']?.toString().toLowerCase();

      if (type == 'income' || category == 'income') {
        totalIncome += amount;
      } else {
        totalExpense += amount;
      }
    }

    return {
      'expense': totalExpense,
      'income': totalIncome,
    };
  }
}
