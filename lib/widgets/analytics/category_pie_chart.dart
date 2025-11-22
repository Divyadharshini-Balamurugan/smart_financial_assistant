// lib/widgets/analytics/category_pie_chart.dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math' as math;
import 'package:intl/intl.dart';

/// Transparent widget that draws a solid pie (no hole) + vertical legend.
/// Important: this widget does NOT create any card or background so the Analytics page's outer frame remains the single container.
class CategoryPieCard extends StatelessWidget {
  final Map<String, double> categoryTotals;
  final String title;
  final bool showTitle;
  final double groupThresholdPercent;

  const CategoryPieCard({
    super.key,
    required this.categoryTotals,
    this.title = 'Category-wise Chart',
    this.showTitle = false,
    this.groupThresholdPercent = 3.0,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final maxWidth = constraints.maxWidth.isFinite ? constraints.maxWidth : MediaQuery.of(context).size.width;
      final maxHeight = constraints.maxHeight.isFinite ? constraints.maxHeight : MediaQuery.of(context).size.height * 0.45;
      final cardHeight = maxHeight.clamp(140.0, 520.0);

      final processed = _groupSmallSlices(Map<String, double>.from(categoryTotals), groupThresholdPercent);
      final entries = processed.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      final total = entries.fold<double>(0.0, (s, e) => s + e.value);

      final ValueNotifier<int?> touchedNotifier = ValueNotifier<int?>(null);

      return SizedBox(
        height: cardHeight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showTitle)
              Center(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
              ),
            if (showTitle) const SizedBox(height: 8),

            // Info pill moved above the pie
            ValueListenableBuilder<int?>(
              valueListenable: touchedNotifier,
              builder: (context, idx, _) {
                if (idx == null || idx < 0 || idx >= entries.length) return const SizedBox.shrink();
                final e = entries[idx];
                final pct = total == 0 ? 0.0 : (e.value / total) * 100;
                final pctText = pct >= 1 ? '${pct.toStringAsFixed(0)}%' : '${pct.toStringAsFixed(1)}%';
                final amountText = NumberFormat.currency(symbol: '₹', decimalDigits: 0).format(e.value);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Align(
                    alignment: Alignment.center,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.light
                            ? Colors.white
                            : Colors.grey[900],
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 12, offset: const Offset(0, 6)),
                        ],
                      ),
                      child: Text(
                        '${e.key} — $pctText — $amountText',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                );
              },
            ),

            Expanded(
              child: Row(
                children: [
                  Flexible(
                    flex: 6,
                    child: Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: total == 0
                          ? Center(
                              child: Text('No data available',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey[700])),
                            )
                          : _EnhancedPie(entries: entries, total: total, touchedNotifier: touchedNotifier),
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (total > 0)
                    Flexible(
                      flex: 4,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: math.min(300.0, maxWidth * 0.42)),
                        child: _LegendList(entries: entries, touchedNotifier: touchedNotifier),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }

  Map<String, double> _groupSmallSlices(Map<String, double> data, double thresholdPercent) {
    final total = data.values.fold<double>(0.0, (s, v) => s + v);
    if (total == 0) return data;
    final large = <String, double>{};
    double otherSum = 0.0;
    data.forEach((k, v) {
      final p = (v / total) * 100;
      if (p < thresholdPercent) {
        otherSum += v;
      } else {
        large[k] = v;
      }
    });
    if (otherSum > 0) large['Other'] = otherSum;
    return large;
  }
}

/// Enhanced pie with refined elevation, dual shadows, scale animation and optional radial glow
class _EnhancedPie extends StatefulWidget {
  final List<MapEntry<String, double>> entries;
  final double total;
  final ValueNotifier<int?> touchedNotifier;

  const _EnhancedPie({required this.entries, required this.total, required this.touchedNotifier});

  @override
  State<_EnhancedPie> createState() => _EnhancedPieState();
}

class _EnhancedPieState extends State<_EnhancedPie> {
  int? touchedIndex;

  final List<Color> _palette = const [
    Color(0xFF3DA35D),
    Color(0xFF4D9EF6),
    Color(0xFFFFB86B),
    Color(0xFFB76CF6),
    Color(0xFFFF6B6B),
    Color(0xFF4DD0E1),
    Color(0xFFFFC107),
    Color(0xFF90A4AE),
  ];

  final bool _enableRadialGlow = true;

  @override
  void initState() {
    super.initState();
    widget.touchedNotifier.addListener(_onNotifierChanged);
  }

  void _onNotifierChanged() {
    final idx = widget.touchedNotifier.value;
    if (idx != touchedIndex) setState(() => touchedIndex = idx);
  }

  @override
  void didUpdateWidget(covariant _EnhancedPie oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.touchedNotifier != widget.touchedNotifier) {
      oldWidget.touchedNotifier.removeListener(_onNotifierChanged);
      widget.touchedNotifier.addListener(_onNotifierChanged);
    }
  }

  @override
  void dispose() {
    widget.touchedNotifier.removeListener(_onNotifierChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entries = widget.entries;
    final total = widget.total;

    return LayoutBuilder(builder: (context, constraints) {
      final side = math.min(constraints.maxWidth, constraints.maxHeight);
      final radiusBase = math.max(40.0, side * 0.50);
      final hasSelection = touchedIndex != null;

      final sections = List.generate(entries.length, (i) {
        final e = entries[i];
        final isTouched = i == touchedIndex;
        final radius = isTouched ? radiusBase * 1.10 : radiusBase;
        final pct = total == 0 ? 0.0 : (e.value / total) * 100;
        final showTitle = pct >= 8.0;

        return PieChartSectionData(
          color: _palette[i % _palette.length],
          value: e.value,
          title: showTitle ? '${pct.toStringAsFixed(0)}%' : '',
          radius: radius,
          titleStyle: TextStyle(
            color: Colors.white,
            fontSize: isTouched ? 12 : 10,
            fontWeight: FontWeight.w700,
          ),
          titlePositionPercentageOffset: 0.6,
        );
      });

      return Center(
        child: AnimatedScale(
          duration: const Duration(milliseconds: 260),
          scale: hasSelection ? 1.02 : 1.0,
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            width: side,
            height: side,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: hasSelection
                  ? [
                      BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6, offset: const Offset(0, 2)),
                      BoxShadow(color: Colors.black.withOpacity(0.14), blurRadius: 18, offset: const Offset(0, 8)),
                    ]
                  : [
                      BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 1)),
                      BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
                    ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (_enableRadialGlow)
                  IgnorePointer(
                    child: Container(
                      width: side,
                      height: side,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Colors.white.withOpacity(hasSelection ? 0.06 : 0.02),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.9],
                          radius: 0.9,
                        ),
                      ),
                    ),
                  ),

                Positioned.fill(
                  child: IgnorePointer(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Container(
                        height: side * 0.22,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.white.withOpacity(0.06),
                              Colors.white.withOpacity(0.0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                AspectRatio(
                  aspectRatio: 1,
                  child: PieChart(
                    PieChartData(
                      centerSpaceRadius: 0,
                      startDegreeOffset: -90,
                      sections: sections,
                      sectionsSpace: 0,
                      pieTouchData: PieTouchData(touchCallback: (event, resp) {
                        if (resp == null || resp.touchedSection == null) {
                          widget.touchedNotifier.value = null;
                          return;
                        }
                        final idx = resp.touchedSection!.touchedSectionIndex;
                        widget.touchedNotifier.value = widget.touchedNotifier.value == idx ? null : idx;
                      }),
                    ),
                    swapAnimationDuration: const Duration(milliseconds: 300),
                    swapAnimationCurve: Curves.easeOutCubic,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}

class _LegendList extends StatelessWidget {
  final List<MapEntry<String, double>> entries;
  final ValueNotifier<int?> touchedNotifier;

  const _LegendList({required this.entries, required this.touchedNotifier});

  List<Color> get _palette => const [
        Color(0xFF3DA35D),
        Color(0xFF4D9EF6),
        Color(0xFFFFB86B),
        Color(0xFFB76CF6),
        Color(0xFFFF6B6B),
        Color(0xFF4DD0E1),
        Color(0xFFFFC107),
        Color(0xFF90A4AE),
      ];

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(entries.length, (i) {
            final e = entries[i];
            final color = _palette[i % _palette.length];
            final isSelected = touchedNotifier.value == i;

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () {
                  touchedNotifier.value = touchedNotifier.value == i ? null : i;
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: isSelected
                        ? [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 3))]
                        : null,
                    color: isSelected ? Theme.of(context).highlightColor.withOpacity(0.04) : Colors.transparent,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        width: isSelected ? 16 : 14,
                        height: isSelected ? 16 : 14,
                        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          e.key,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 14, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}