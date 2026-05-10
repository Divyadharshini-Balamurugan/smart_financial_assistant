import 'tip_variant_selector.dart';
import 'safe_scheme_mapper.dart';

class TipDecisionEngine {
  List<Map<String, dynamic>> decide(
    Map<String, dynamic> analysis,
    List<String> usedVariants,
  ) {
    List<Map<String, dynamic>> tips = [];

    final expenses = analysis['expenses'] as Map<String, double>;
    final budgets = analysis['budgets'];
    final goals = analysis['goals'];
    final income = analysis['totalIncome'];
    final spent = analysis['totalExpenses'];

    // 1️⃣ Budget breach + goal
    for (var b in budgets) {
      final cat = b['categoryName'];
      final limit = b['amount'];
      if ((expenses[cat] ?? 0) > limit) {
        final variant = TipVariantSelector.selectVariant(
          "BUDGET_GOAL",
          usedVariants,
        );

        tips.add({
          "category": "BUDGET_GOAL",
          "message": variant
              .replaceAll("{{category}}", cat)
              .replaceAll("{{amount}}",
                  ((expenses[cat]! - limit).round()).toString())
              .replaceAll("{{goal}}", goals.isNotEmpty ? goals.first['goal'] : "goal"),
        });
      }
    }

    // 2️⃣ Goal progress
    for (var g in goals) {
      final gap =
          (g['requiredPerFrequency'] ?? 0) - (g['initialAmount'] ?? 0);
      if (gap > 0) {
        final variant = TipVariantSelector.selectVariant(
          "GOAL_PROGRESS",
          usedVariants,
        );

        tips.add({
          "category": "GOAL_PROGRESS",
          "message": variant
              .replaceAll("{{gap}}", gap.round().toString())
              .replaceAll("{{goal}}", g['goal']),
        });
      }
    }

    // 3️⃣ Safe scheme
    final surplus = income - spent;
    if (surplus > 1000 && goals.isNotEmpty) {
      final scheme = SafeSchemeMapper.getScheme(
        stableIncome: true,
        goal: goals.first['goal'],
      );

      if (scheme != null) {
        final variant = TipVariantSelector.selectVariant(
          "SAFE_SCHEME",
          usedVariants,
        );

        tips.add({
          "category": "SAFE_SCHEME",
          "message": variant
              .replaceAll("{{scheme}}", scheme)
              .replaceAll("{{amount}}", surplus.round().toString())
              .replaceAll("{{goal}}", goals.first['goal']),
        });
      }
    }

    if (tips.isEmpty) {
      tips.add({
        "category": "POSITIVE",
        "message": TipVariantSelector.selectVariant(
          "POSITIVE",
          usedVariants,
        ),
      });
    }

    return tips;
  }
}
