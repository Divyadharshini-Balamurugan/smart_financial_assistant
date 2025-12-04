// lib/firestore_helpers.dart
import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';

final FirebaseFirestore _db = FirebaseFirestore.instance;

/// Build UTC-based date keys: dateKey yyyy-MM-dd, monthKey yyyy-MM, weekKey yyyy-Www (ISO week)
Map<String, String> buildKeysUtc(DateTime date) {
  final d = date.toUtc();
  final yyyy = d.year.toString().padLeft(4, '0');
  final mm = (d.month).toString().padLeft(2, '0');
  final dd = d.day.toString().padLeft(2, '0');
  final dateKey = '$yyyy-$mm-$dd';
  final monthKey = '$yyyy-$mm';

  // ISO week calc
  // Algorithm: get Thursday of current week and compute week number relative to Jan 1st's Thursday.
  DateTime tmp = DateTime.utc(d.year, d.month, d.day);
  int dayOfWeek = tmp.weekday; // 1 = Mon ... 7 = Sun
  // move to Thursday (4)
  DateTime thursday = tmp.add(Duration(days: (4 - dayOfWeek)));
  // week1 is the week with Jan 4th
  DateTime firstJan = DateTime.utc(thursday.year, 1, 1);
  int days = thursday.difference(firstJan).inDays;
  int weekNo = (days / 7).floor() + 1;
  final weekKey = '${thursday.year}-W${weekNo.toString().padLeft(2, '0')}';

  return {
    'dateKey': dateKey,
    'monthKey': monthKey,
    'weekKey': weekKey,
    'yearKey': yyyy,
  };
}

/// Setup a new user's profile doc and default categories (call after sign-up)
Future<void> setupUserDatabase({
  required String uid,
  String? email,
  String? displayName,
}) async {
  final userRef = _db.collection('users').doc(uid);
  await userRef.set({
    'email': email ?? '',
    'displayName': displayName ?? null,
    'fullName': null,
    'settings': {
      'currency': 'INR',
      'timezone': 'Asia/Kolkata',
      'firstWeekday': 'MON',
    },
    'createdAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
  });

  final categories = ['Food', 'Transport', 'Entertainment', 'Bills', 'Shopping'];
  final batch = _db.batch();
  for (var c in categories) {
    final ref = userRef.collection('categories').doc(); // auto id
    batch.set(ref, {
      'name': c,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
  await batch.commit();
}

/// Add Expense
Future<DocumentReference> addExpense({
  required String uid,
  required double amount,
  required String categoryId,
  String? categoryName,
  String? subcategoryId,
  String? paymentModeId,
  DateTime? date, // local date expected; will convert to UTC keys
  String currency = 'INR',
  String? notes,
}) async {
  final d = date?.toUtc() ?? DateTime.now().toUtc();
  final keys = buildKeysUtc(d);
  final docRef = await _db.collection('users').doc(uid).collection('expenses').add({
    'amount': amount,
    'currency': currency,
    'categoryId': categoryId,
    'categoryName': categoryName,
    'subcategoryId': subcategoryId,
    'paymentModeId': paymentModeId,
    'timestamp': FieldValue.serverTimestamp(),
    'dateKey': keys['dateKey'],
    'monthKey': keys['monthKey'],
    'weekKey': keys['weekKey'],
    'yearKey': keys['yearKey'],
    'notes': notes ?? '',
    'createdAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
  });
  return docRef;
}

/// Update Expense
Future<void> updateExpense({
  required String uid,
  required String expenseId,
  double? amount,
  String? categoryId,
  String? categoryName,
  DateTime? date, // used to recompute keys if provided
  String? notes,
}) async {
  final Map<String, dynamic> data = {
    'updatedAt': FieldValue.serverTimestamp(),
  };
  if (amount != null) data['amount'] = amount;
  if (categoryId != null) data['categoryId'] = categoryId;
  if (categoryName != null) data['categoryName'] = categoryName;
  if (notes != null) data['notes'] = notes;
  if (date != null) {
    final keys = buildKeysUtc(date.toUtc());
    data['dateKey'] = keys['dateKey'];
    data['monthKey'] = keys['monthKey'];
    data['weekKey'] = keys['weekKey'];
    // keep timestamp server controlled for ordering
    data['timestamp'] = FieldValue.serverTimestamp();
  } else {
    // optionally update timestamp if amount changed, else keep
  }

  await _db.collection('users').doc(uid).collection('expenses').doc(expenseId).update(data);
}

/// Delete Expense
Future<void> deleteExpense({
  required String uid,
  required String expenseId,
}) async {
  await _db.collection('users').doc(uid).collection('expenses').doc(expenseId).delete();
}

/// Example: addExpense already exists in your codebase.
/// Below is addIncome — mirror of addExpense but stores in incomes subcollection.
/// Adjust field names to match your existing schema.
Future<DocumentReference> addIncome({
  required String uid,
  required double amount,
  required String categoryId,
  String? categoryName,
  String? subcategoryId,
  String? paymentModeId,
  required DateTime date,
  String currency = 'INR',
  String? notes,
}) async {
  // Use the provided date (local) converted to UTC for key generation
  final d = date.toUtc();
  final keys = buildKeysUtc(d);

  final payload = {
    'amount': amount,
    'currency': currency,
    'categoryId': categoryId,
    'categoryName': categoryName ?? '',
    'subcategoryId': subcategoryId ?? '',
    'paymentModeId': paymentModeId ?? '',
    'notes': notes ?? '',
    // Keep timestamp / createdAt consistent with addExpense:
    'timestamp': FieldValue.serverTimestamp(),
    'dateKey': keys['dateKey'],
    'monthKey': keys['monthKey'],
    'weekKey': keys['weekKey'],
    'yearKey': keys['yearKey'],
    'createdAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
  };

  final ref = await _db.collection('users').doc(uid).collection('incomes').add(payload);
  return ref;
}

