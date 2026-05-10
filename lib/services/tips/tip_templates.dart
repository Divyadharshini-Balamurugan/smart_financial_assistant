class TipTemplates {
  static const Map<String, List<String>> templates = {
    "BUDGET_GOAL": [
      "Your {{category}} spending exceeded the budget by ₹{{amount}}. Adjusting this helps your {{goal}} goal stay on track.",
      "You went slightly over budget in {{category}}. Keeping it controlled supports your {{goal}} plan.",
      "A small overspend in {{category}} may affect your {{goal}} goal. Consider reducing expenses next week."
    ],

    "GOAL_PROGRESS": [
      "You are ₹{{gap}} behind your {{goal}} goal this cycle. Saving a little more can bridge the gap.",
      "Your {{goal}} goal needs extra attention this month. Even small contributions help.",
      "Progress toward your {{goal}} goal is slower than planned. Try adjusting non-essential spending."
    ],

    "BEHAVIORAL": [
      "Frequent small expenses are adding up. Planning daily spending may help you save more.",
      "Most of your expenses are unplanned. Setting a weekly limit can improve control.",
      "Impulse spending detected. Reviewing expenses nightly may help reduce leaks."
    ],

    "SAFE_SCHEME": [
      "You consistently save ₹{{amount}} monthly. Starting a {{scheme}} could strengthen your {{goal}} fund safely.",
      "With steady surplus, a {{scheme}} can help grow your savings without risk.",
      "Your savings pattern suits a {{scheme}}. Even a small monthly start builds discipline."
    ],

    "POSITIVE": [
      "Great job! Your spending is well within budget this period.",
      "You’re managing your finances well. Keep it up!",
      "No issues detected this week — your plan is working."
    ]
  };
}
