import 'dart:math';
import 'tip_templates.dart';

class TipVariantSelector {
  static String selectVariant(
    String category,
    List<String> usedVariants,
  ) {
    final variants = TipTemplates.templates[category] ?? [];

    final available = variants
        .where((v) => !usedVariants.contains(v))
        .toList();

    if (available.isNotEmpty) {
      return available[Random().nextInt(available.length)];
    }

    // fallback → rotate
    return variants[Random().nextInt(variants.length)];
  }
}
