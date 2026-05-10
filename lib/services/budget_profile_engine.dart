import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BudgetProfileEngine {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String get uid => FirebaseAuth.instance.currentUser!.uid;

  /// MAIN ENTRY POINT (Safe)
  Future<void> generateAndSaveProfile(Map<String, dynamic>? survey) async {
    // If survey is null or empty → use generic defaults
    if (survey == null || survey.isEmpty) {
      await _saveGenericProfile();
      return;
    }

    // Safe extraction with fallbacks
    final String role = survey["role"] ?? "Unknown";
    final String incomeSource = survey["income source"] ?? "Unknown";
    final List<dynamic> obligations =
        survey["monthly obligation"] ?? <dynamic>[];
    final List<dynamic> goals = survey["goal"] ?? <dynamic>[];
    final String spendingStyle =
        survey["spending style"] ?? "Balanced / mixed";
    final String incomeFrequency = survey["income frequency"] ?? "Monthly";

    final bool isSurveyIncomplete = !_isCompleteSurvey(survey);

    // If survey incomplete → generic profile
    if (isSurveyIncomplete) {
      await _saveGenericProfile(
        role: role,
        incomeSource: incomeSource,
        incomeFrequency: incomeFrequency,
      );
      return;
    }

    // STEP 1 — Time window
    final String timeWindow = _calculateTimeWindow(incomeFrequency);

    // STEP 2 — Start with default generic limits
    Map<String, double> limits = _genericRecommendedLimits();

    // STEP 3 — Apply smart adjustments
    _applyRoleAdjustments(limits, role);
    _applyGoalAdjustments(limits, goals);

    // STEP 4 — Flexibility factor
    double flexibilityFactor = _flexibilityFactor(spendingStyle);

    // STEP 5 — Apply flexibility
    Map<String, double> finalLimits =
        _applyFlexibility(limits, flexibilityFactor);

    // STEP 6 — Effective income logic
    String effectiveFormula = _buildEffectiveIncomeFormula(obligations);

    // STEP 7 — Save profile
    await _saveProfileToFirestore(
      timeWindow: timeWindow,
      effectiveFormula: effectiveFormula,
      limits: finalLimits,
      flexibilityFactor: flexibilityFactor,
      goals: goals,
      role: role,
      incomeSource: incomeSource,
      incomeFrequency: incomeFrequency,
      profileStatus: "personalized",
    );
  }

  // ============================================================
  // GENERIC FALLBACK PROFILE
  // ============================================================

  Future<void> _saveGenericProfile({
    String role = "Unknown",
    String incomeSource = "Unknown",
    String incomeFrequency = "Monthly",
  }) async {
    await _saveProfileToFirestore(
      timeWindow: "monthly",
      effectiveFormula: "effective_income = income",
      limits: _genericRecommendedLimits(),
      flexibilityFactor: 1.0,
      goals: [],
      role: role,
      incomeSource: incomeSource,
      incomeFrequency: incomeFrequency,
      profileStatus: "generic_default",
    );
  }

  Future<void> _saveProfileToFirestore({
    required String timeWindow,
    required String effectiveFormula,
    required Map<String, double> limits,
    required double flexibilityFactor,
    required List<dynamic> goals,
    required String role,
    required String incomeSource,
    required String incomeFrequency,
    required String profileStatus,
  }) async {
    await _db
        .collection("users")
        .doc(uid)
        .collection("budget_profile")
        .doc("personal_limits")
        .set({
      "time_window": timeWindow,
      "effective_income_formula": effectiveFormula,
      "category_limits": limits,
      "flexibility_factor": flexibilityFactor,
      "goal_priorities": goals,
      "role": role,
      "income_source": incomeSource,
      "income_frequency": incomeFrequency,
      "profile_status": profileStatus,
      "created_at": DateTime.now().toIso8601String(),
    });
  }

  // ============================================================
  // VALIDATION
  // ============================================================

  bool _isCompleteSurvey(Map<String, dynamic> survey) {
    return survey["role"] != null &&
        survey["income source"] != null &&
        survey["spending style"] != null &&
        survey["income frequency"] != null;
  }

  // ============================================================
  // GENERIC DEFAULT CATEGORY LIMITS (your values)
  // ============================================================

  Map<String, double> _genericRecommendedLimits() {
    return {
      "Rent": 0.30,
      "Food": 0.20,
      "Bills & Utilities": 0.10,
      "Investment": 0.20,
      "Shopping": 0.10,
      "Travelling": 0.10,
      "Entertainment": 0.10,
      "Medical": 0.10,
      "Personal Care": 0.05,
      "Education": 0.05,
      "Taxes": 0.10,
      "Gifts & Donations": 0.05,
      "Other": 0.05,
    };
  }

  // ============================================================
  // BUSINESS LOGIC
  // ============================================================

  String _calculateTimeWindow(String frequency) {
    switch (frequency) {
      case "Daily":
        return "daily";
      case "Weekly":
        return "weekly";
      case "Bi-weekly":
        return "biweekly";
      case "Irregular / Seasonal":
        return "rolling_30_days";
      default:
        return "monthly";
    }
  }

  void _applyRoleAdjustments(Map<String, double> limits, String role) {
    switch (role) {
      case "Student":
        limits["Education"] = (limits["Education"] ?? 0.05) + 0.05;
        limits["Shopping"] = (limits["Shopping"] ?? 0.10) * 0.8;
        break;

      case "Retired person":
        limits["Medical"] = (limits["Medical"] ?? 0.10) + 0.05;
        break;

      case "Freelancer":
      case "Self-employed":
        limits["Investment"] = (limits["Investment"] ?? 0.20) + 0.05;
        break;

      case "Homemaker":
        limits["Food"] = (limits["Food"] ?? 0.20) + 0.05;
        break;
    }
  }

  void _applyGoalAdjustments(Map<String, double> limits, List goals) {
    for (String goal in goals) {
      switch (goal) {
        case "Reducing debt":
          limits["Entertainment"] =
              (limits["Entertainment"] ?? 0.10) * 0.7;
          limits["Shopping"] = (limits["Shopping"] ?? 0.10) * 0.6;
          break;

        case "Emergency fund":
        case "Growing investments":
          limits["Investment"] =
              (limits["Investment"] ?? 0.20) + 0.05;
          break;
      }
    }
  }

  double _flexibilityFactor(String style) {
    switch (style) {
      case "Strict budgeter":
        return 0.9;
      case "Occasional splurges":
        return 1.1;
      case "Unplanned / impulsive":
        return 1.3;
      default:
        return 1.0;
    }
  }

  Map<String, double> _applyFlexibility(
      Map<String, double> limits, double factor) {
    return limits.map(
      (key, value) => MapEntry(key, value * factor),
    );
  }

  String _buildEffectiveIncomeFormula(List<dynamic> obligations) {
    if (obligations.isEmpty) {
      return "effective_income = income";
    }
    return "effective_income = income - sum(obligations)";
  }
}
