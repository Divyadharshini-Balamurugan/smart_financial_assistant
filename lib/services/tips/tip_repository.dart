import 'package:cloud_firestore/cloud_firestore.dart';

class TipRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> saveTips(String uid, List<Map<String, dynamic>> tips) async {
    final ref = _db.collection('users/$uid/personalizedTips');

    for (var tip in tips.take(2)) {
      await ref.add({
        ...tip,
        "createdAt": FieldValue.serverTimestamp(),
        "shown": false,
      });
    }
  }
}
