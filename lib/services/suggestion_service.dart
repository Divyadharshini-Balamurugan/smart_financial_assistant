import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SuggestionService {
  // ✅ singleton (your widget already expects this)
  SuggestionService._internal();
  static final SuggestionService instance = SuggestionService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final StreamController<List<String>> _controller =
      StreamController<List<String>>.broadcast();

  Stream<List<String>> get suggestionsStream => _controller.stream;

  StreamSubscription? _tipsSub;

  /// ------------------------------------------------------------
  /// INITIAL FETCH (called from initState)
  /// ------------------------------------------------------------
  Future<List<String>> fetchOrGenerate() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return _fallbackTips();

    // 1️⃣ try firebase tips
    final tips = await _fetchFirebaseTips(uid);

    if (tips.isNotEmpty) {
      _startListening(uid);
      return tips;
    }

    // 2️⃣ no tips yet → check if user has any data at all
    final hasData = await _hasAnyUserData(uid);

    if (!hasData) {
      return _onboardingTips();
    }

    // 3️⃣ has some data but no insights yet
    return _waitingTips();
  }

    /// ------------------------------------------------------------
  /// 🔁 MANUAL REFRESH (used after expense logging)
  /// ------------------------------------------------------------
  Future<void> refreshAndPush() async {
    final uid = _auth.currentUser?.uid;

    if (uid == null) {
      _controller.add(_fallbackTips());
      return;
    }

    try {
      final tips = await _fetchFirebaseTips(uid);

      if (tips.isNotEmpty) {
        _controller.add(tips);
      } else {
        final hasData = await _hasAnyUserData(uid);
        _controller.add(
          hasData ? _waitingTips() : _onboardingTips(),
        );
      }
    } catch (e) {
      print('⚠️ refreshAndPush failed: $e');
      _controller.add(_waitingTips());
    }
  }

  /// ------------------------------------------------------------
  /// LIVE LISTENER (auto-updates UI)
  /// ------------------------------------------------------------
  void _startListening(String uid) {
    _tipsSub?.cancel();

    _tipsSub = _db
        .collection('users/$uid/personalizedTips')
        .orderBy('createdAt', descending: true)
        .limit(5)
        .snapshots()
        .listen((snap) {
      final tips = snap.docs
          .map((d) => d['message'] as String?)
          .whereType<String>()
          .toList();

      if (tips.isNotEmpty) {
        _controller.add(tips);
      }
    }, onError: (e) {
      print('⚠️ Tips listener error: $e');
    });
  }

  /// ------------------------------------------------------------
  /// FIREBASE FETCH
  /// ------------------------------------------------------------
  Future<List<String>> _fetchFirebaseTips(String uid) async {
    final snap = await _db
        .collection('users/$uid/personalizedTips')
        .orderBy('createdAt', descending: true)
        .limit(5)
        .get();

    return snap.docs
        .map((d) => d['message'] as String?)
        .whereType<String>()
        .toList();
  }

  /// ------------------------------------------------------------
  /// CHECK IF USER HAS ANY DATA
  /// ------------------------------------------------------------
  Future<bool> _hasAnyUserData(String uid) async {
    final checks = await Future.wait([
      _db.collection('users/$uid/expenses').limit(1).get(),
      _db.collection('users/$uid/incomes').limit(1).get(),
      _db.collection('users/$uid/surveyResponses').limit(1).get(),
      _db.collection('users/$uid/goalSavings').limit(1).get(),
      _db.collection('users/$uid/budget_alert').limit(1).get(),
    ]);

    return checks.any((snap) => snap.docs.isNotEmpty);
  }

  /// ------------------------------------------------------------
  /// FALLBACK STATES
  /// ------------------------------------------------------------

  List<String> _fallbackTips() {
    return [
      "Sign in to start receiving personalised financial tips.",
    ];
  }

  List<String> _onboardingTips() {
    return [
      "Start by logging your expenses to understand where your money goes.",
      "Create a budget to keep monthly spending under control.",
      "Set a savings goal to track progress visually.",
    ];
  }

  List<String> _waitingTips() {
    return [
      "Keep logging expenses — insights will appear soon.",
      "We’re analysing your spending patterns.",
      "Your personalised tips will be ready shortly.",
    ];
  }

  /// ------------------------------------------------------------
  /// CLEANUP (optional)
  /// ------------------------------------------------------------
  void dispose() {
    _tipsSub?.cancel();
    _controller.close();
  }
}

