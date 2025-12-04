import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';


/// ------------------------------------------------
/// CONTRIBUTION MODEL
/// ------------------------------------------------
class Contribution {
  final String id;
  final double amount;
  final DateTime date;
  final String note;

  Contribution({
    required this.id,
    required this.amount,
    required this.date,
    required this.note,
  });

  factory Contribution.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Contribution(
      id: doc.id,
      amount: (data['amount'] ?? 0).toDouble(),
      date: (data['date'] as Timestamp).toDate(),
      note: data['note'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'amount': amount,
      'date': Timestamp.fromDate(date),
      'note': note,
    };
  }
}

/// ------------------------------------------------
/// GOAL MODEL
/// ------------------------------------------------
class GoalModel {
  final String id;
  final String goalName;
  final double targetAmount;
  final double initialAmount;
  final DateTime createdAt;
  final DateTime targetDate;
  final String frequency;
  final double requiredPerFrequency;

  /// Not stored inside goal document — loaded separately
  final List<Contribution> contributions;

  GoalModel({
    required this.id,
    required this.goalName,
    required this.targetAmount,
    required this.initialAmount,
    required this.createdAt,
    required this.targetDate,
    required this.frequency,
    required this.requiredPerFrequency,
    this.contributions = const [],
  });

  factory GoalModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return GoalModel(
      id: doc.id,
      goalName: data['goal'] ?? '',
      targetAmount: (data['targetAmount'] ?? 0).toDouble(),
      initialAmount: (data['initialAmount'] ?? 0).toDouble(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      targetDate: (data['targetDate'] is Timestamp)
          ? (data['targetDate'] as Timestamp).toDate()
          : DateTime.tryParse(data['targetDate'] ?? '') ?? DateTime.now(),
      frequency: data['frequency'] ?? '',
      requiredPerFrequency:
          (data['requiredPerFrequency'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'goal': goalName,
      'targetAmount': targetAmount,
      'initialAmount': initialAmount,
      'createdAt': Timestamp.fromDate(createdAt),
      'targetDate': Timestamp.fromDate(targetDate),
      'frequency': frequency,
      'requiredPerFrequency': requiredPerFrequency,
    };
  }
}

/// ------------------------------------------------
/// GOAL SAVINGS SERVICE
/// ------------------------------------------------
class GoalSavingsService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String get uid => FirebaseAuth.instance.currentUser!.uid;

  // ------------------------------
  // Collection Helpers
  // ------------------------------
  CollectionReference<Map<String, dynamic>> _goalCol(String uid) =>
      _db.collection('users').doc(uid).collection('goalSavings');

  CollectionReference<Map<String, dynamic>> _contribCol(
          String uid, String goalId) =>
      _goalCol(uid).doc(goalId).collection('contributions');

  // ------------------------------
  // CREATE GOAL
  // ------------------------------
  Future<String> createGoal(String uid, GoalModel goal) async {
    final ref = _goalCol(uid).doc();
    await ref.set(goal.toMap());
    return ref.id;
  }

  // ------------------------------
  // UPDATE GOAL
  // ------------------------------
  Future<void> updateGoal(
      String uid, String goalId, Map<String, dynamic> updates) async {
    await _goalCol(uid).doc(goalId).update(updates);
  }

  // ------------------------------
  // DELETE GOAL
  // ------------------------------
  Future<void> deleteGoal(String uid, String goalId) async {
    await _goalCol(uid).doc(goalId).delete();
  }

  // ------------------------------
  // GET ALL GOALS
  // ------------------------------
  Future<List<GoalModel>> getGoals(String uid) async {
    final snap =
        await _goalCol(uid).orderBy('createdAt', descending: true).get();

    return snap.docs.map((doc) => GoalModel.fromFirestore(doc)).toList();
  }

  Stream<List<GoalModel>> watchGoals(String uid) {
    return _goalCol(uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((doc) => GoalModel.fromFirestore(doc)).toList());
  }

  // ------------------------------
  // GET SINGLE GOAL + CONTRIBUTIONS
  // ------------------------------
  Future<GoalModel?> getGoal(String uid, String goalId) async {
    final doc = await _goalCol(uid).doc(goalId).get();
    if (!doc.exists) return null;

    // Get contributions subcollection
    final contribSnap =
        await _contribCol(uid, goalId).orderBy('date', descending: true).get();

    final contributions =
        contribSnap.docs.map((d) => Contribution.fromFirestore(d)).toList();

    return GoalModel.fromFirestore(doc)
        .copyWith(contributions: contributions);
  }

  // ------------------------------
  // SAVE CONTRIBUTION
  // ------------------------------
  Future<void> saveContribution(
      String uid, String goalId, Contribution c) async {
    // Add to subcollection
    await _contribCol(uid, goalId).add(c.toMap());

    // Increase initialAmount
    await _goalCol(uid).doc(goalId).update({
      'initialAmount': FieldValue.increment(c.amount),
    });
  }
}

/// ------------------------------------------------
/// EXTENSION: To add contributions into GoalModel
/// ------------------------------------------------
extension GoalCopy on GoalModel {
  GoalModel copyWith({List<Contribution>? contributions}) {
    return GoalModel(
      id: id,
      goalName: goalName,
      targetAmount: targetAmount,
      initialAmount: initialAmount,
      createdAt: createdAt,
      targetDate: targetDate,
      frequency: frequency,
      requiredPerFrequency: requiredPerFrequency,
      contributions: contributions ?? this.contributions,
    );
  }
}
