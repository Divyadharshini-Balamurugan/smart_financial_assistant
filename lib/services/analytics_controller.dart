import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class AnalyticsService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  /// Build Firestore date keys used for filtering
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

  /// Get ISO-like week number for a given date
  int _getWeekNumber(DateTime date) {
    final firstDayOfYear = DateTime(date.year, 1, 1);
    final daysOffset = firstDayOfYear.weekday - DateTime.monday;
    final firstMonday = firstDayOfYear.subtract(Duration(days: daysOffset));
    final diff = date.difference(firstMonday).inDays;
    return ((diff / 7).floor()) + 1;
  }

  /// Fetch total Expense and Income filtered by period (Day / Week / Month / Year)
  Future<Map<String, double>> fetchTotals({
    required String period,
    required DateTime date,
  }) async {
    if (_uid == null) throw Exception("User not logged in");

    final userRef = _db.collection('users').doc(_uid);
    final keys = _buildKeys(date);

    // Helper to run the query for a named subcollection and return the sum
    Future<double> _collectSum(String subcoll) async {
      Query<Map<String, dynamic>> q = userRef.collection(subcoll);

      if (period == 'Day') {
        q = q.where('dateKey', isEqualTo: keys['dateKey']);
      } else if (period == 'Week') {
        q = q.where('weekKey', isEqualTo: keys['weekKey']);
      } else if (period == 'Month') {
        q = q.where('monthKey', isEqualTo: keys['monthKey']);
      } else if (period == 'Year') {
        q = q.where('yearKey', isEqualTo: keys['yearKey']);
      }

      final snap = await q.get();
      double total = 0.0;
      for (final d in snap.docs) {
        final data = d.data();
        if (!data.containsKey('amount') || data['amount'] == null) continue;
        final double amt = (data['amount'] as num).toDouble();
        total += amt;
      }
      return total;
    }

    // Sum expense subcollection and income subcollection separately.
    // NOTE: uses 'expenses' and 'incomes' subcollection names — change if your
    // actual names differ.
    final expenseTotal = await _collectSum('expenses');
    final incomeTotal = await _collectSum('incomes');

    return {
      'expense': expenseTotal,
      'income': incomeTotal,
    };
  }

  // ------------------------------------------------------------
  // Fetch total expenses grouped by category (for Pie Chart)
  // ------------------------------------------------------------
  Future<Map<String, double>> fetchCategoryTotals({
    required String period,
    required DateTime date,
  }) async {
    if (_uid == null) throw Exception("User not logged in");

    final userRef = _db.collection('users').doc(_uid);
    final keys = _buildKeys(date);

    Query<Map<String, dynamic>> query = userRef.collection('expenses'); // expenses only

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
    final Map<String, double> categoryTotals = {};

    for (final doc in snapshot.docs) {
      final data = doc.data();
      if (!data.containsKey('amount') || data['amount'] == null) continue;
      final double amount = (data['amount'] as num).toDouble();
      final String category = (data['categoryName'] ?? 'Uncategorized').toString();
      categoryTotals[category] = (categoryTotals[category] ?? 0) + amount;
    }

    return categoryTotals;
  }

  // ------------------------------------------------------------
  // Fetch time-series totals (for bar chart) — returns two series maps
  // ------------------------------------------------------------
  Future<Map<String, Map<String, double>>> fetchExpenseIncomeSeriesDual({
    required String period,
    required DateTime date,
  }) async {
    if (_uid == null) throw Exception("User not logged in");

    final userRef = _db.collection('users').doc(_uid);
    final keys = _buildKeys(date);

    Future<Map<String, double>> _collect(String subcoll) async {
      Query<Map<String, dynamic>> q = userRef.collection(subcoll);

      if (period == 'Day') {
        q = q.where('dateKey', isEqualTo: keys['dateKey']);
      } else if (period == 'Week') {
        q = q.where('weekKey', isEqualTo: keys['weekKey']);
      } else if (period == 'Month') {
        q = q.where('monthKey', isEqualTo: keys['monthKey']);
      } else if (period == 'Year') {
        q = q.where('yearKey', isEqualTo: keys['yearKey']);
      }

      final snap = await q.get();
      final Map<String, double> totals = {};

      for (final doc in snap.docs) {
        final data = doc.data();
        if (!data.containsKey('amount') || data['amount'] == null) continue;
        final double amount = (data['amount'] as num).toDouble();

        // Use dateKey for grouping label (fall back to timestamp if needed)
        String? dk = data['dateKey'] as String?;
        DateTime? txnDate;
        if (dk != null) {
          try {
            txnDate = DateTime.parse(dk);
          } catch (_) {
            txnDate = null;
          }
        }
        if (txnDate == null) {
          final ts = data['createdAt'] ?? data['timestamp'];
          if (ts is Timestamp) txnDate = ts.toDate();
          else txnDate = DateTime.tryParse(ts?.toString() ?? '');
        }
        if (txnDate == null) continue;

        String label;
        if (period == 'Week') {
          label = DateFormat('EEE').format(txnDate); // Mon, Tue...
        } else if (period == 'Month') {
          final weekOfMonth = ((txnDate.day - 1) ~/ 7) + 1;
          label = 'Week $weekOfMonth';
        } else if (period == 'Year') {
          label = DateFormat('MMM').format(txnDate); // Jan, Feb...
        } else {
          label = DateFormat('d MMM').format(txnDate); // day label
        }

        totals[label] = (totals[label] ?? 0) + amount;
      }

      // Keep expected order for Week / Year / Month
      if (period == 'Week') {
        const orderedDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        final ordered = <String, double>{};
        for (final d in orderedDays) {
          ordered[d] = totals[d] ?? 0.0;
        }
        return ordered;
      }
      if (period == 'Year') {
        const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
        final ordered = <String, double>{};
        for (final m in months) ordered[m] = totals[m] ?? 0.0;
        return ordered;
      }
      if (period == 'Month') {
        final ordered = <String, double>{};
        for (int i = 1; i <= 5; i++) {
          final k = 'Week $i';
          ordered[k] = totals[k] ?? 0.0;
        }
        return ordered;
      }

      return totals;
    }

    // Query both subcollections (expenses + incomes). Note: 'incomes' plural.
    final expenseSeries = await _collect('expenses');
    final incomeSeries = await _collect('incomes');

    return {
      'expense': expenseSeries,
      'income': incomeSeries,
    };
  }

  // ------------------------------------------------------------
  // Fetch totals grouped by payment method
  // includeIncome = false (default) keeps previous behavior (expenses only)
  // ------------------------------------------------------------
  Future<Map<String, double>> fetchPaymentMethodTotals({
    required String period,
    required DateTime date,
    bool includeIncome = false,
  }) async {
    if (_uid == null) throw Exception("User not logged in");

    // Build mapping of paymentModeId -> name (probe common collections)
    final candidates = <String>[
      'paymentMethods',
      'payment_methods',
      'payment_modes',
      'paymentMode',
      'payment_method',
      'payment_methods_master',
      'paymentModeList'
    ];

    final Map<String, String> idToName = {};
    for (final colName in candidates) {
      try {
        final colSnap = await _db.collection(colName).get();
        if (colSnap.docs.isNotEmpty) {
          for (final d in colSnap.docs) {
            final data = d.data();
            final nameValue = (data['name'] ?? data['title'] ?? data['method'] ?? data['label'])?.toString();
            idToName[d.id] = (nameValue == null || nameValue.trim().isEmpty) ? d.id : nameValue;
          }
          break;
        }
      } catch (_) {
        // ignore and try next candidate
      }
    }

    final userRef = _db.collection('users').doc(_uid);
    final keys = _buildKeys(date);

    // Helper to query a specific subcollection and add its totals into map
    Future<void> _accumulateFrom(String subcoll, Map<String, double> out) async {
      Query<Map<String, dynamic>> q = userRef.collection(subcoll);

      if (period == 'Day') {
        q = q.where('dateKey', isEqualTo: keys['dateKey']);
      } else if (period == 'Week') {
        q = q.where('weekKey', isEqualTo: keys['weekKey']);
      } else if (period == 'Month') {
        q = q.where('monthKey', isEqualTo: keys['monthKey']);
      } else if (period == 'Year') {
        q = q.where('yearKey', isEqualTo: keys['yearKey']);
      }

      final snap = await q.get();
      for (final doc in snap.docs) {
        final data = doc.data();
        if (!data.containsKey('amount') || data['amount'] == null) continue;
        final double amount = (data['amount'] as num).toDouble();

        String? pmId = (data['paymentModeId'] ??
                data['payment_mode_id'] ??
                data['payment_mode'] ??
                data['paymentMode'] ??
                data['payment'] ??
                data['payment_method_id'])
            ?.toString();
        pmId = (pmId ?? '').trim();
        if (pmId.isEmpty) pmId = 'unknown';

        final label = idToName[pmId] ?? pmId;
        out[label] = (out[label] ?? 0.0) + amount;
      }
    }

    final Map<String, double> paymentTotals = {};
    // Always include expenses (previous default)
    await _accumulateFrom('expenses', paymentTotals);

    // Optionally include incomes too
    if (includeIncome) {
      await _accumulateFrom('incomes', paymentTotals);
    }

    return paymentTotals;
  }
}
