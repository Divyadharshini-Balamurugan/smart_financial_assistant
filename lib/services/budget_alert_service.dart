import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BudgetAlertService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

    String get uid => _auth.currentUser!.uid;

  int _daysInMonth(int year, int month) {
    final next = month == 12 ? DateTime(year + 1, 1) : DateTime(year, month + 1);
    final thisMonth = DateTime(year, month);
    return next.difference(thisMonth).inDays;
  }

  DateTime _addMonths(DateTime date, int months) {
    final totalMonths = date.year * 12 + date.month - 1 + months;
    final y = totalMonths ~/ 12;
    final m = totalMonths % 12 + 1;
    final d = math.min(date.day, _daysInMonth(y, m));
    return DateTime(y, m, d, date.hour, date.minute, date.second);
  }

  DateTime _addYears(DateTime d, int y) => _addMonths(d, y * 12);
  DateTime _startOfWeek(DateTime dt) => dt.subtract(Duration(days: dt.weekday - 1));
  DateTime _endOfWeek(DateTime dt) => _startOfWeek(dt).add(const Duration(days: 6));

  /// Creates a new budget alert document for current user.
  Future<DocumentReference?> addBudgetAlert({
    required String categoryName,
    required double amount,
    required String frequency,
    String? categoryId,
    DateTime? startDate,
    Map<String, dynamic>? extra,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final now = DateTime.now();
    final docRef = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('budget_alert')
        .doc();

    final data = <String, dynamic>{
      'categoryName': categoryName,
      'amount': amount,
      'frequency': frequency,
      'categoryId': categoryId ?? '',
      'startDate': startDate != null ? Timestamp.fromDate(startDate) : Timestamp.fromDate(now),
      'createdAt': Timestamp.fromDate(now),
    };

    if (extra != null) data.addAll(extra);

    await docRef.set(data);
    return docRef;
  }

  /// Update an existing alert. Only provided fields will be updated.
  Future<void> updateBudgetAlert({
    required String alertId,
    String? frequency,
    double? amount,
    String? categoryName,
    String? categoryId,
    DateTime? startDate,
    Map<String, dynamic>? extra,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final Map<String, dynamic> updateData = {};
    if (amount != null) updateData['amount'] = amount;
    if (frequency != null) updateData['frequency'] = frequency;
    if (categoryName != null) updateData['categoryName'] = categoryName;
    if (categoryId != null) updateData['categoryId'] = categoryId;
    if (startDate != null) updateData['startDate'] = Timestamp.fromDate(startDate);
    if (extra != null) updateData.addAll(extra);

    if (updateData.isEmpty) return;

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('budget_alert')
        .doc(alertId)
        .update(updateData);
  }

  /// Delete an alert
  Future<void> deleteBudgetAlert({required String alertId}) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('budget_alert')
        .doc(alertId)
        .delete();
  }

  /// Fetch alert document snapshot
  Future<DocumentSnapshot?> getAlertDoc({required String alertId}) async {
    final user = _auth.currentUser;
    if (user == null) return null;
    final doc = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('budget_alert')
        .doc(alertId)
        .get();
    return doc.exists ? doc : null;
  }

  /// Calculate spent amount and return transactions for the alert for a chosen period.
  /// period must be one of: 'Day', 'Week', 'Month', 'Year' (case-sensitive same as your UI)
  /// date will be used to pick the exact day/week/month/year. If null -> DateTime.now()
  /// Returns a map { 'total': double, 'transactions': List<Map<String,dynamic>>, 'from': DateTime, 'to': DateTime }
  Future<Map<String, dynamic>> calculateSpentForAlert({
    required String alertId,
    required String period,
    DateTime? date,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return {'total': 0.0, 'transactions': <Map<String, dynamic>>[], 'from': DateTime.now(), 'to': DateTime.now()};

    final doc = await getAlertDoc(alertId: alertId);
    if (doc == null) return {'total': 0.0, 'transactions': <Map<String, dynamic>>[], 'from': DateTime.now(), 'to': DateTime.now()};

    final data = doc.data() as Map<String, dynamic>;

    // resolve category matching - prefer categoryId if present, else categoryName
    final String? categoryName = (data['categoryName'] ?? data['name'])?.toString();
    final String? categoryId = (data['categoryId'] ?? data['catId'])?.toString();

    final selectedDate = date ?? DateTime.now();
    DateTime from;
    DateTime to;
    final now = DateTime.now();

    if (period == 'Day') {
      final d = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
      from = d;
      to = d.add(const Duration(days: 1));
    } else if (period == 'Week') {
      final s = _startOfWeek(selectedDate);
      from = s;
      to = _endOfWeek(selectedDate).add(const Duration(days: 1));
    } else if (period == 'Month') {
      from = DateTime(selectedDate.year, selectedDate.month);
      to = DateTime(selectedDate.year, selectedDate.month, _daysInMonth(selectedDate.year, selectedDate.month)).add(const Duration(days: 1));
    } else if (period == 'Year') {
      from = DateTime(selectedDate.year, 1, 1);
      to = DateTime(selectedDate.year, 12, 31).add(const Duration(days: 1));
    } else {
      // fallback to week
      final s = _startOfWeek(selectedDate);
      from = s;
      to = _endOfWeek(selectedDate).add(const Duration(days: 1));
    }

    // never query future beyond today
    final maxTo = DateTime(now.year, now.month, now.day + 1);
    if (to.isAfter(maxTo)) to = maxTo;

    // Build query - prefer matching by categoryId, fallback to categoryName
    Query q = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('expenses')
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
        .where('timestamp', isLessThan: Timestamp.fromDate(to));

    // Firestore requires equality filters to be on same field for indexes; attempt to use categoryId if available
    if (categoryId != null && categoryId.isNotEmpty) {
      q = q.where('categoryId', isEqualTo: categoryId);
    } else if (categoryName != null && categoryName.isNotEmpty) {
      q = q.where('categoryName', isEqualTo: categoryName);
    }

    // apply ordering
    q = q.orderBy('timestamp', descending: true);

    final snap = await q.get();

    double total = 0.0;
    final List<Map<String, dynamic>> tx = [];
for (final d in snap.docs) {
  final m = d.data() as Map<String, dynamic>?;   

  if (m == null) continue;                       

  double amt = 0.0;

  final rawAmount = m['amount'];

  if (rawAmount is num) {
    amt = rawAmount.toDouble();
  } else {
    amt = double.tryParse(rawAmount?.toString() ?? '0') ?? 0.0;
  }

  total += amt;

  // FIX #3 — When m is Map<String,dynamic>?, clone safely
  final item = Map<String, dynamic>.from(m);
  item['id'] = d.id;

  tx.add(item);
}

    return {
      'total': total,
      'transactions': tx,
      'from': from,
      'to': to,
      'limit': (data['amount'] is num) ? (data['amount'] as num).toDouble() : double.tryParse(data['amount']?.toString() ?? '0') ?? 0.0,
      'categoryName': categoryName,
      'categoryId': categoryId,
      'alertDoc': doc,
    };
  }
}
