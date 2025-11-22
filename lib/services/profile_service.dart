// lib/services/profile_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class ProfileService {
  final FirebaseFirestore _firestore;
  final String usersCollection;

  ProfileService({FirebaseFirestore? firestore, this.usersCollection = 'users'})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Stream of the user document snapshot for real-time updates.
  Stream<DocumentSnapshot<Map<String, dynamic>>> userDocStream(String uid) {
    return _firestore
        .collection(usersCollection)
        .doc(uid)
        .snapshots();
  }

  /// Update one or more fields on the user doc (supports nested fields).
  /// Example keys: 'profile.firstName', 'email', 'updatedAt'
  Future<void> updateFields(String uid, Map<String, dynamic> data) {
    // Add updatedAt server timestamp if not provided
    final mutated = Map<String, dynamic>.from(data);
    if (!mutated.containsKey('updatedAt')) {
      mutated['updatedAt'] = FieldValue.serverTimestamp();
    }
    return _firestore.collection(usersCollection).doc(uid).update(mutated);
  }

  /// Set the whole profile map (replace or create)
  Future<void> setProfileMap(String uid, Map<String, dynamic> profileMap) {
    return _firestore.collection(usersCollection).doc(uid).set({
      'profile': profileMap,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
