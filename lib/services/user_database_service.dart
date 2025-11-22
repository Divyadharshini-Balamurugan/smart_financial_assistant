import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserDatabaseService {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  /// Initializes default user data structure on first signup
  Future<void> initializeUserData() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final userRef = _firestore.collection('users').doc(user.uid);
    final doc = await userRef.get();

    if (doc.exists) return; // Already initialized

    final now = FieldValue.serverTimestamp();

    await userRef.set({
      // Core authentication info
      'email': user.email,
      'displayName': user.displayName ?? '',
      'createdAt': now,
      'updatedAt': now,

      // All user-specific preferences and personalization
      'settings': {
        'currency': 'INR',
        'timezone': 'Asia/Kolkata',
        'firstWeekday': 'Monday',

        // Editable profile info
        'profile': {
          'firstName': null,
          'lastName': null,
          'username': null,
          'password': null,
        },

        // App behavior preferences (default: ON)
        'preferences': {
          'motivationalMessage': true,
          'streak': true,
        },

        // Notification toggles (default: ON)
        'notifications': {
          'notifications': true,
          'reminders': true,
          'goalAlerts': true,
          'suggestions': true,
        },

        // Privacy and personalization (default: ON)
        'privacy': {
          'trackingAndPersonalisation': true,
        },
      },
    });

    // Optional: create empty subcollections to avoid null checks
    await Future.wait([
      _initCollection(userRef, 'expenses'),
      _initCollection(userRef, 'goals'),
      _initCollection(userRef, 'reminders'),
      _initCollection(userRef, 'adviseDashboard'),
      _initCollection(userRef, 'categories'),
    ]);
  }

  /// Helper: Creates and immediately removes a placeholder doc
  Future<void> _initCollection(DocumentReference userRef, String name) async {
    final ref = userRef.collection(name).doc('_init');
    await ref.set({'placeholder': true});
    await ref.delete();
  }
}
