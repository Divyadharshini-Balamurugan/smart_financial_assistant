import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SurveyQuestion {
  final String id;
  final String question;
  final List<String> options;
  final int order;
  final String? tag;

  SurveyQuestion({
    required this.id,
    required this.question,
    required this.options,
    required this.order,
    this.tag,
  });

  factory SurveyQuestion.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SurveyQuestion(
      id: doc.id,
      question: data['question'] ?? '',
      options: List<String>.from(data['options'] ?? []),
      order: (data['order'] ?? 0) is int
          ? data['order'] as int
          : (data['order'] as num).toInt(),
      tag: data['tag'] as String?,
    );
  }
}

class SurveyService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Fetch survey questions ordered by Firestore "order"
  Future<List<SurveyQuestion>> fetchQuestions() async {
    final snap = await _db.collection('survey').orderBy('order').get();
    return snap.docs.map((d) => SurveyQuestion.fromDoc(d)).toList();
  }

  // ---------------------------------------------------------------------------
  // STEP 2: Prevent duplicate saving by using:
  // users/{uid}/surveyResponses/{questionId}
  //
  // So every question always saves to the same document.
  // ---------------------------------------------------------------------------
Future<void> saveAnswer({
  required String questionId,
  required String question,
  int? selectedIndex,
  String? selectedValue,
  List<String>? selectedValues, // <-- For multi-select (Q3)
}) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  final ref = _db
      .collection('users')
      .doc(user.uid)
      .collection('surveyResponses')
      .doc(questionId);

  final Map<String, dynamic> data = {
    'questionId': questionId,
    'question': question,
    'timestamp': FieldValue.serverTimestamp(),
  };

  if (selectedValues != null && selectedValues.isNotEmpty) {
    // Multi-select format (Monthly Obligations)
    data['selectedValues'] = selectedValues;
  } else {
    // Normal single-select format
    data['selectedIndex'] = selectedIndex;
    data['selectedValue'] = selectedValue;
  }

  await ref.set(data, SetOptions(merge: true)); // Prevent overwrite
}


  // ---------------------------------------------------------------------------
  // STEP 3: Mark survey completed in user root doc
  // users/{uid}/surveyCompleted = true
  // ---------------------------------------------------------------------------
  Future<void> markSurveyCompleted() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final ref = _db.collection('users').doc(user.uid);

    await ref.set({
      'surveyCompleted': true,
      'surveyCompletedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}