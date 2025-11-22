// lib/widgets/analytics/expense_income_bar.dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;

class ExpenseIncomeBar extends StatefulWidget {
  final Map<String, Map<String, double>> data;
  final double height;

  const ExpenseIncomeBar({
    super.key,
    required this.data,
    this.height = 320,
  });

  @override
  State<ExpenseIncomeBar> createState() => _ExpenseIncomeBarState();
}

class _ExpenseIncomeBarState extends State<ExpenseIncomeBar> {
  final NumberFormat _fmt = NumberFormat.currency(symbol: '₹', decimalDigits: 0);
  int? _touchedGroupIndex;

  static const _expenseColor = Color(0xFFFF6B6B);
  static const _incomeColor = Color(0xFF3DA35D);

  double _maxY(double suggested) {
    if (suggested == 0) return 100;
    return (suggested * 1.12).ceilToDouble();
  }

  @override
  Widget build(BuildContext context) {
    final labels = widget.data.keys.toList();
    final groupCount = labels.length;
    final maxVal = widget.data.values.fold<double>(0.0, (prev, m) {
      final e = m['expense'] ?? 0.0;
      final i = m['income'] ?? 0.0;
      return math.max(prev, math.max(e, i));
    });
    final maxY = _maxY(maxVal);

    // sizing constants
    const baseRodWidth = 14.0;
    const barsSpace = 6.0;
    const groupGap = 20.0;
    final estimatedGroupWidth = (baseRodWidth * 2) + barsSpace + groupGap;
    final chartContentWidth = math.max(estimatedGroupWidth * groupCount, MediaQuery.of(context).size.width * 0.9);

    return LayoutBuilder(builder: (context, constraints) {
      // constraints.maxHeight may be infinite if parent doesn't constrain vertically.
      final double availableHeight = constraints.maxHeight.isFinite ? constraints.maxHeight : double.infinity;

      const headerReserved = 72.0; // leave room for top card + spacing

      final rawChartHeight = widget.height;

      // compute an upper bound for the chart height.
      final double maxAllowedChartHeight = availableHeight == double.infinity
          ? rawChartHeight
          : math.max(0.0, availableHeight - headerReserved);

      // ensure clamp receives sensible bounds: lower bound 140, upper bound at least 140
      final double upperClamp = math.max(140.0, maxAllowedChartHeight);
      final double chartHeight = rawChartHeight.clamp(140.0, upperClamp).toDouble();

      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top info card. AnimatedSwitcher for smooth in/out.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
              child: _touchedGroupIndex == null
                  ? const SizedBox(
                      key: ValueKey('empty'),
                      height: 0,
                    )
                  : _infoCard(
                      labels[_touchedGroupIndex!],
                      widget.data[labels[_touchedGroupIndex!]] ?? {},
                      key: ValueKey(labels[_touchedGroupIndex!]),
                    ),
            ),
          ),

          const SizedBox(height: 8),

          // Chart area
          SizedBox(
            height: chartHeight,
            child: Center(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: SizedBox(
                  width: chartContentWidth,
                  height: chartHeight,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 6.0),
                    child: BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceBetween,
                        maxY: maxY,
                        minY: 0,
                        groupsSpace: groupGap,
                        barGroups: _buildGroups(labels, baseRodWidth, barsSpace),
                        // use touch to update top card; disable built-in tooltips to avoid clutter
                        barTouchData: BarTouchData(
                          handleBuiltInTouches: false,
                          touchCallback: (event, response) {
                            if (response == null || response.spot == null) {
                              setState(() => _touchedGroupIndex = null);
                              return;
                            }
                            // toggle selection on tap
                            final tapped = response.spot!.touchedBarGroupIndex;
                            setState(() => _touchedGroupIndex = (_touchedGroupIndex == tapped) ? null : tapped);
                          },
                        ),

                        titlesData: FlTitlesData(
                          show: true,
                          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 60,
                              interval: (maxY / 4).clamp(1, double.infinity).toDouble(),
                              getTitlesWidget: (value, meta) {
                                return Text(_fmt.format(value), style: const TextStyle(fontSize: 10));
                              },
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 56,
                              getTitlesWidget: (value, meta) {
                                final idx = value.toInt();
                                if (idx < 0 || idx >= labels.length) return const SizedBox.shrink();
                                final txt = labels[idx];
                                return SideTitleWidget(
                                  axisSide: meta.axisSide,
                                  child: Transform.translate(
                                    offset: const Offset(0, 8),
                                    child: Text(txt, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),

                        gridData: FlGridData(show: false),
                        borderData: FlBorderData(show: false),
                      ),
                      swapAnimationDuration: const Duration(milliseconds: 350),
                      swapAnimationCurve: Curves.easeOutCubic,
                    ),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Legend moved down (red=Expense, green=Income) as requested
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _legendDot(_expenseColor, 'Expense'),
                const SizedBox(width: 12),
                _legendDot(_incomeColor, 'Income'),
              ],
            ),
          ),
        ],
      );
    });
  }

  List<BarChartGroupData> _buildGroups(List<String> labels, double rodWidth, double barsSpace) {
    return List.generate(labels.length, (i) {
      final map = widget.data[labels[i]] ?? {};
      final expense = (map['expense'] ?? 0.0).abs();
      final income = (map['income'] ?? 0.0).abs();
      final isTouched = _touchedGroupIndex == i;

      // subtle visual highlight instead of width jump:
      final expenseColor = isTouched ? _darken(_expenseColor, 0.07) : _expenseColor;
      final incomeColor = isTouched ? _darken(_incomeColor, 0.07) : _incomeColor;
      final radius = isTouched ? BorderRadius.circular(8) : BorderRadius.circular(6);

      return BarChartGroupData(
        x: i,
        barsSpace: barsSpace,
        barRods: [
          BarChartRodData(
            toY: expense,
            width: rodWidth,
            borderRadius: radius,
            color: expenseColor,
          ),
          BarChartRodData(
            toY: income,
            width: rodWidth,
            borderRadius: radius,
            color: incomeColor,
          ),
        ],
        showingTooltipIndicators: [],
      );
    });
  }

  Widget _legendDot(Color c, String label) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

 // Top information card widget — robust compact layout with proper truncation
Widget _infoCard(String label, Map<String, double> map, {Key? key}) {
  final expense = (map['expense'] ?? 0.0).abs();
  final income = (map['income'] ?? 0.0).abs();
  final net = income - expense;
  final netLabel = net >= 0 ? 'Net +ve' : 'Net -ve';
  final netColor = net >= 0 ? _incomeColor : _expenseColor;

  Widget _dot(Color c) => Container(width: 8, height: 8, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2)));

  // small helper to render an item with label + value; fits a single line and ellipsizes
  Widget _valueCell({required Widget leading, required String text}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        leading,
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            style: const TextStyle(fontSize: 13),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  return Container(
    key: key,
    margin: const EdgeInsets.only(top: 8.0, bottom: 4.0),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 3)),
      ],
      border: Border.all(color: Colors.grey.withOpacity(0.08)),
    ),
    child: LayoutBuilder(builder: (context, bc) {
      final width = bc.maxWidth;
      const threshold = 380.0; // if narrower than this, use stacked layout

      if (width >= threshold) {
        // Single-line layout with fixed flexes to avoid overlap
        return Row(
          children: [
            // Week label (left) - smaller flex
            Flexible(
              flex: 18,
              child: Text(
                label,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            const SizedBox(width: 12),

            // Expense
            Flexible(
              flex: 26,
              child: _valueCell(
                leading: _dot(_expenseColor),
                text: 'Expense: ${_fmt.format(expense)}',
              ),
            ),

            const SizedBox(width: 12),

            // Income
            Flexible(
              flex: 26,
              child: _valueCell(
                leading: _dot(_incomeColor),
                text: 'Income: ${_fmt.format(income)}',
              ),
            ),

            const SizedBox(width: 12),

            // Net - show number and small label
            Flexible(
              flex: 20,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      _fmt.format(net.abs()),
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: netColor),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      netLabel,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      } else {
        // Narrow layout: Week centered on top, values row below (each value gets spaceEvenly)
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Week label centered
            Center(
              child: Text(
                label,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Expense
                Expanded(
                  child: _valueCell(
                    leading: _dot(_expenseColor),
                    text: 'Expense: ${_fmt.format(expense)}',
                  ),
                ),
                const SizedBox(width: 6),
                // Income
                Expanded(
                  child: _valueCell(
                    leading: _dot(_incomeColor),
                    text: 'Income: ${_fmt.format(income)}',
                  ),
                ),
                const SizedBox(width: 6),
                // Net
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        _fmt.format(net.abs()),
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: netColor),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(netLabel, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        );
      }
    }),
  );
}


  Widget _miniDot(Color c) => Container(width: 8, height: 8, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2)));

  // Simple color darkener for touch highlight
  Color _darken(Color c, double amount) {
    assert(amount >= 0 && amount <= 1);
    final f = 1 - amount;
    return Color.fromARGB(c.alpha, (c.red * f).round(), (c.green * f).round(), (c.blue * f).round());
  }
}
