class SafeSchemeMapper {
  static String? getScheme({
    required bool stableIncome,
    required String goal,
  }) {
    if (!stableIncome) return null;

    if (goal.contains("Emergency")) return "Fixed Deposit";
    if (goal.contains("Vacation")) return "Recurring Deposit";
    if (goal.contains("Retirement")) return "Public Provident Fund";

    return "Recurring Deposit";
  }
}
