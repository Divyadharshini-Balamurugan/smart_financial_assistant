// lib/pages/goal_detail_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:first_app/services/goal_savings_service.dart';
import 'dart:math';

class GoalDetailPage extends StatefulWidget {
  final String goalId;
  const GoalDetailPage({Key? key, required this.goalId}) : super(key: key);

  @override
  State<GoalDetailPage> createState() => _GoalDetailPageState();
}

class AnimatedCounter extends StatelessWidget {
  final double value;
  final String prefix;
  final TextStyle? style;
  final Duration duration;
  const AnimatedCounter({
    Key? key,
    required this.value,
    this.prefix = '',
    this.style,
    this.duration = const Duration(milliseconds: 900),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: value),
      duration: duration,
      builder: (context, v, child) {
        return Text('$prefix${v.toStringAsFixed(0)}', style: style);
      },
    );
  }
}

class GoalProgressPainter extends CustomPainter {
  final double progress;
  const GoalProgressPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.12;
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = (size.width - stroke) / 2;

    final basePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = Colors.grey.shade200;

    // Clamp & sanitize
    final p = progress.isNaN ? 0.0 : progress.clamp(0.0, 1.0);

    final sweepAngle = max(0.001, 2 * pi * p);

    final progPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: -pi / 2,
        endAngle: -pi / 2 + sweepAngle,
        colors: const [
          Color(0xFF8E5CE0),
          Color(0xFF58CC02),
        ],
        stops: const [0, 1],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    // Draw base circle
    canvas.drawCircle(center, radius, basePaint);

    // Draw progress arc
    canvas.drawArc(rect, -pi / 2, sweepAngle, false, progPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}


class _LegendDot extends StatelessWidget {
  final Color color;
  const _LegendDot({required this.color, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
  }
}

class _GoalDetailPageState extends State<GoalDetailPage> with SingleTickerProviderStateMixin {
  final _service = GoalSavingsService();
  GoalModel? goal;
  bool loading = true;
  final _amountController = TextEditingController();
  DateTime selectedDate = DateTime.now();
  List<Contribution> transactions = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final g = await _service.getGoal(uid, widget.goalId);
      if (mounted) {
        setState(() {
          goal = g;
          transactions = g?.contributions.reversed.toList() ?? [];
          loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> _saveContribution() async {
    if (_amountController.text.trim().isEmpty) return;
    final amt = double.tryParse(_amountController.text.replaceAll(',', '')) ?? 0;
    if (amt <= 0 || goal == null) return;
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final c = Contribution(id: '', amount: amt, date: selectedDate, note: 'Manual');
    setState(() => loading = true);
    try {
      await _service.saveContribution(uid, widget.goalId, c);
      final updatedList = [c, ...transactions];
      final updatedGoal = goal!.copyWith(contributions: updatedList)
        ..let((g) {
          // increase initialAmount locally for UI (service already increments in backend)
          return GoalModel(
            id: g.id,
            goalName: g.goalName,
            targetAmount: g.targetAmount,
            initialAmount: g.initialAmount + amt,
            createdAt: g.createdAt,
            targetDate: g.targetDate,
            frequency: g.frequency,
            requiredPerFrequency: g.requiredPerFrequency,
            contributions: updatedList,
          );
        });
      // Because GoalModel is immutable in your service, create a new instance:
      final newGoal = GoalModel(
        id: goal!.id,
        goalName: goal!.goalName,
        targetAmount: goal!.targetAmount,
        initialAmount: goal!.initialAmount + amt,
        createdAt: goal!.createdAt,
        targetDate: goal!.targetDate,
        frequency: goal!.frequency,
        requiredPerFrequency: goal!.requiredPerFrequency,
        contributions: updatedList,
      );
      if (mounted) {
        setState(() {
          transactions = updatedList;
          goal = newGoal;
          _amountController.clear();
          loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (loading && goal == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (goal == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Goal')),
        body: const Center(child: Text('Goal not found')),
      );
    }

    final g = goal!;
    final saved = g.initialAmount;
    final remaining = (g.targetAmount - saved).clamp(0, double.infinity);
    final progress = g.targetAmount <= 0 ? 0.0 : (saved / g.targetAmount).clamp(0.0, 1.0).toDouble();


    final createdAt = g.createdAt;
    final totalDays = g.targetDate.difference(createdAt).inDays;
    final passedDays = DateTime.now().difference(createdAt).inDays;
    final plannedProgress = totalDays <= 0 ? 1.0 : (passedDays / totalDays).clamp(0.0, 1.0).toDouble();
    final behindAmount = (plannedProgress - progress) * g.targetAmount;

    final daysRemaining = g.targetDate.difference(DateTime.now()).inDays;
    final requiredDaily = daysRemaining > 0 ? (remaining / daysRemaining) : remaining;
    final requiredMonthly = (requiredDaily * 30).ceilToDouble();

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FB),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black87,
        centerTitle: true,
        title: Text(g.goalName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 12, offset: const Offset(0, 6))],
            ),
            child: Row(children: [
              SizedBox(
                width: 110,
                height: 110,
                child: Stack(alignment: Alignment.center, children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: progress),
                    duration: const Duration(milliseconds: 900),
                    builder: (context, value, child) {
                      return CustomPaint(size: const Size(110, 110), painter: GoalProgressPainter(value));
                    },
                  ),
                  Column(mainAxisSize: MainAxisSize.min, children: [
                    Text('${(progress * 100).toStringAsFixed(0)}%', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text('Saved', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                  ]),
                ]),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Goal Amount', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  const SizedBox(height: 6),
                  Text('₹${g.targetAmount.toStringAsFixed(0)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF4C338E))),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Saved', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                        const SizedBox(height: 6),
                        AnimatedCounter(value: saved, prefix: '₹', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      ]),
                    ),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Remaining', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                        const SizedBox(height: 6),
                        AnimatedCounter(value: remaining.toDouble(), prefix: '₹', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      ]),
                    ),
                  ]),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 6))]),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Actual vs Planned', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              LayoutBuilder(builder: (context, constraints) {
                final width = constraints.maxWidth;

                // compute raw values
                final actualRaw = (width * progress).clamp(0.0, width).toDouble();
                final plannedPx = (width * plannedProgress).clamp(0.0, width).toDouble();

                // Only apply 1px min when progress > 0
                final actualPx = progress == 0 ? 0.0 : max(1.0, actualRaw).toDouble();

                return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    height: 18,
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: Colors.grey.shade200),
                    child: Row(children: [
                      Container(width: actualPx, decoration: const BoxDecoration(color: Color(0xFF1CB0F6), borderRadius: BorderRadius.only(topLeft: Radius.circular(12), bottomLeft: Radius.circular(12)))),
                      if (plannedPx > actualPx) Container(width: plannedPx - actualPx, color: const Color(0xFFB0B0B0)),
                      if (width > plannedPx)
                        Expanded(
                          child: Container(decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: const BorderRadius.only(topRight: Radius.circular(12), bottomRight: Radius.circular(12)))),
                        ),
                    ]),
                  ),
                  const SizedBox(height: 10),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Row(children: [const _LegendDot(color: Color(0xFF1CB0F6)), const SizedBox(width: 6), Text("Actual", style: TextStyle(fontSize: 12, color: Colors.grey.shade800))]),
                    Row(children: [const _LegendDot(color: Color(0xFFB0B0B0)), const SizedBox(width: 6), Text("Planned", style: TextStyle(fontSize: 12, color: Colors.grey.shade800))]),
                    Row(children: [ _LegendDot(color: Colors.grey.shade300), const SizedBox(width: 6), const Text("Remaining", style: TextStyle(fontSize: 12))]),
                  ]),
                ]);
              }),
            ]),
          ),
          const SizedBox(height: 18),
          Row(children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: behindAmount >= 0 ? const [Color(0xFFFFE5E5), Color(0xFFFFF2F2)] : const [Color.fromARGB(255, 216, 237, 207), Color.fromARGB(255, 190, 243, 153)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 4))],
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(behindAmount >= 0 ? 'Behind' : 'Ahead', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: behindAmount >= 0 ? const Color.fromARGB(255, 248, 55, 55) : const Color.fromARGB(255, 66, 147, 5))),
                  const SizedBox(height: 8),
                  AnimatedCounter(value: behindAmount.abs(), prefix: '₹', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: behindAmount >= 0 ? const Color.fromARGB(255, 248, 55, 55) : const Color.fromARGB(255, 66, 147, 5))),
                  const SizedBox(height: 6),
                  Text(behindAmount >= 0 ? 'You are behind your plan' : 'You are ahead of your plan', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                ]),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color.fromARGB(255, 206, 226, 251), Color.fromARGB(255, 130, 197, 245)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 4))],
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Insights', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  Text('Days left: $daysRemaining', style: const TextStyle(fontSize: 13, color: Color.fromARGB(255, 7, 7, 7))),
                  const SizedBox(height: 8),
                  Text('Save ₹${requiredDaily.toStringAsFixed(0)}/day', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color.fromARGB(255, 0, 78, 127))),
                  const SizedBox(height: 8),
                  Text('Or ₹${requiredMonthly.toStringAsFixed(0)}/month', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color.fromARGB(255, 0, 78, 127))),
                ]),
              ),
            ),
          ]),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: Offset(0, 4))]),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Text('Add Contribution', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(prefixText: '₹', hintText: 'Amount', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), fillColor: Colors.grey.shade100, filled: true),
                  ),
                ),
                const SizedBox(width: 12),
                InkWell(
                  onTap: () async {
                    final dt = await showDatePicker(context: context, initialDate: selectedDate, firstDate: DateTime.now().subtract(const Duration(days: 365)), lastDate: DateTime.now());
                    if (dt != null) setState(() => selectedDate = dt);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
                    child: Column(children: [Text('Date', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)), const SizedBox(height: 4), Text(DateFormat('dd MMM').format(selectedDate), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700))]),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              SizedBox(
                height: 48,
                child: ElevatedButton(onPressed: _saveContribution, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF58CC02), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text('Save Contribution', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white))),
              ),
            ]),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: Offset(0, 4))]),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('History', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              if (transactions.isEmpty)
                Center(child: Text('No contributions yet', style: TextStyle(color: Colors.grey.shade600)))
              else
                ...transactions.map((t) {
                  final displayDate = t.date.isAfter(DateTime.now()) ? DateTime.now() : t.date;
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(child: const Text('₹', style: TextStyle(fontSize: 12)), backgroundColor: Colors.grey.shade100),
                    title: Text('₹${t.amount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text('${DateFormat('dd MMM yyyy').format(displayDate)} • ${t.note}'),
                  );
                }),
            ]),
          ),
          const SizedBox(height: 28),
        ]),
      ),
    );
  }
}

// A small extension helper to allow inline transformations (optional).
extension Let<T> on T {
  R let<R>(R Function(T it) transform) => transform(this);
}
