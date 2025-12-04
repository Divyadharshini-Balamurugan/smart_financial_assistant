// budget_alert_detail_page.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:first_app/widgets/alerts/budget_gauge.dart';
import 'set_alerts.dart';

class BudgetAlertDetailPage extends StatefulWidget {
  final String alertId;
  const BudgetAlertDetailPage({super.key, required this.alertId});

  @override
  State<BudgetAlertDetailPage> createState() => _BudgetAlertDetailPageState();
}

class _BudgetAlertDetailPageState extends State<BudgetAlertDetailPage> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  DocumentSnapshot? _alertDoc;
  bool _loading = true;
  double _spent = 0;
  List<Map<String, dynamic>> _transactions = [];

  // unified period handling (mirrors AnalyticsPage approach)
  String selectedPeriod = 'Week';
  DateTime selectedDate = DateTime.now();
  DateTime _dayDate = DateTime.now();
  DateTime _weekDate = DateTime.now();
  DateTime _monthDate = DateTime.now();
  DateTime _yearDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _load();
  }

  // ---------------------- date helpers ----------------------
  int _daysInMonth(int year, int month) {
    final next = month == 12 ? DateTime(year + 1, 1) : DateTime(year, month + 1);
    final thisMonth = DateTime(year, month);
    return next.difference(thisMonth).inDays;
  }

  DateTime _addMonths(DateTime date, int months) {
    final totalMonths = date.year * 12 + date.month - 1 + months;
    final y = totalMonths ~/ 12;
    final m = totalMonths % 12 + 1;
    final d = math.min(date.day, _daysInMonth(y, m));
    return DateTime(y, m, d, date.hour, date.minute, date.second);
  }

  DateTime _addYears(DateTime d, int y) => _addMonths(d, y * 12);
  DateTime _startOfWeek(DateTime dt) => dt.subtract(Duration(days: dt.weekday - 1));
  DateTime _endOfWeek(DateTime dt) => _startOfWeek(dt).add(const Duration(days: 6));

  String _formatLockedRange() {
    if (selectedPeriod == 'Day') {
      return DateFormat('d MMM yyyy').format(selectedDate);
    } else if (selectedPeriod == 'Week') {
      final s = _startOfWeek(selectedDate);
      final e = _endOfWeek(selectedDate);
      return "${DateFormat('d MMM').format(s)} - ${DateFormat('d MMM yyyy').format(e)}";
    } else if (selectedPeriod == 'Month') {
      return DateFormat('MMMM yyyy').format(selectedDate);
    }
    return DateFormat('yyyy').format(selectedDate);
  }

  // ---------------------- load alert & interpret frequency ----------------------
  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);

    try {
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint("[_load] no auth user");
        return;
      }

      final doc = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('budget_alert')
          .doc(widget.alertId)
          .get();

      if (!doc.exists) {
        if (mounted) setState(() => _alertDoc = null);
        debugPrint("[_load] doc not found: ${widget.alertId}");
        return;
      }

      final raw = doc.data();
      debugPrint("[_load] Loaded doc id=${doc.id} raw=$raw");

      // Canonicalize frequency text from multiple possible fields
      String freqText = '';
      if (raw is Map<String, dynamic>) {
        final candidates = [
          raw['frequency'],
          raw['freq'],
          raw['repeat'],
          raw['recurrence'],
          raw['period']
        ];
        for (var c in candidates) {
          if (c == null) continue;
          if (c is String && c.trim().isNotEmpty) {
            freqText = c;
            break;
          } else if (c is Map && c['type'] is String) {
            freqText = c['type'];
            break;
          } else if (c is bool) {
            freqText = c ? 'true' : 'false';
            break;
          }
        }
      }

      final freq = freqText.toLowerCase().trim();
      debugPrint("[_load] interpreted frequency='$freq'");

      // Map to Day/Week/Month/Year (fallback Week)
      String newPeriod = 'Week';
      if (freq.contains('day') || freq.contains('daily') || freq.contains('every day') || freq == 'daily') {
        newPeriod = 'Day';
      } else if (freq.contains('week') || freq.contains('weekly')) {
        newPeriod = 'Week';
      } else if (freq.contains('month') || freq.contains('monthly')) {
        newPeriod = 'Month';
      } else if (freq.contains('year') || freq.contains('annual') || freq.contains('yearly')) {
        newPeriod = 'Year';
      } else {
        // attempt to infer from structured fields if present
        if (raw is Map<String, dynamic> && raw['interval'] != null) {
          final iv = raw['interval'];
          final unit = (raw['intervalUnit'] ?? '').toString().toLowerCase();
          final n = int.tryParse(iv.toString()) ?? 0;
          if (n == 1 && (unit == 'day' || unit == 'days')) newPeriod = 'Day';
          if (n == 1 && (unit == 'week' || unit == 'weeks')) newPeriod = 'Week';
          if (n == 1 && (unit == 'month' || unit == 'months')) newPeriod = 'Month';
        }
      }

      // parse startDate if present
      DateTime? sd;
      if (raw is Map<String, dynamic>) {
        final s = raw['startDate'] ?? raw['start'];
        if (s is Timestamp) sd = s.toDate();
        else if (s is DateTime) sd = s;
        else if (s is String) {
          try {
            sd = DateTime.parse(s);
          } catch (_) {}
        }
      }

      // Update state in one setState to guarantee rebuild
      if (mounted) {
        setState(() {
          _alertDoc = doc;
          selectedPeriod = newPeriod;
          // restore saved date for the selected period if provided, otherwise keep defaults
          if (sd != null) {
            if (selectedPeriod == 'Day') _dayDate = sd;
            if (selectedPeriod == 'Week') _weekDate = sd;
            if (selectedPeriod == 'Month') _monthDate = sd;
            if (selectedPeriod == 'Year') _yearDate = sd;
          }
          // set selectedDate based on chosen period
          if (selectedPeriod == 'Day') selectedDate = _dayDate;
          if (selectedPeriod == 'Week') selectedDate = _weekDate;
          if (selectedPeriod == 'Month') selectedDate = _monthDate;
          if (selectedPeriod == 'Year') selectedDate = _yearDate;
        });
      }

      debugPrint("[_load] set selectedPeriod=$selectedPeriod selectedDate=$selectedDate");

      // After state is set, fetch spend using the correct period/date
      await _fetchSpend();
    } catch (e, st) {
      debugPrint("[_load] error: $e\n$st");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ---------------------- fetch spend ----------------------
  Future<void> _fetchSpend() async {
    try {
      final user = _auth.currentUser;
      if (user == null || _alertDoc == null) return;

      final data = _alertDoc!.data() as Map<String, dynamic>;
      final category = data['categoryName'] ?? data['name'] ?? 'Unknown';
      DateTime from, to;

      final now = DateTime.now();

      if (selectedPeriod == 'Day') {
        final d = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
        from = d;
        to = d.add(const Duration(days: 1));
      } else if (selectedPeriod == 'Week') {
        final s = _startOfWeek(selectedDate);
        from = s;
        to = _endOfWeek(selectedDate).add(const Duration(days: 1));
      } else if (selectedPeriod == 'Month') {
        from = DateTime(selectedDate.year, selectedDate.month);
        to = DateTime(selectedDate.year, selectedDate.month, _daysInMonth(selectedDate.year, selectedDate.month))
            .add(const Duration(days: 1));
      } else {
        from = DateTime(selectedDate.year, 1, 1);
        to = DateTime(selectedDate.year, 12, 31).add(const Duration(days: 1));
      }

      // Do not go beyond today
      final maxTo = DateTime(now.year, now.month, now.day + 1);
      if (to.isAfter(maxTo)) to = maxTo;

      debugPrint("[_fetchSpend] Querying for category='$category' from=$from to=$to");

      final q = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('expenses')
          .where('categoryName', isEqualTo: category)
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
          .where('timestamp', isLessThan: Timestamp.fromDate(to))
          .orderBy('timestamp', descending: true)
          .get();

      double total = 0;
      List<Map<String, dynamic>> tx = [];

      for (var d in q.docs) {
        final m = d.data();
        final amt = (m['amount'] is num)
            ? (m['amount'] as num).toDouble()
            : double.tryParse(m['amount'].toString()) ?? 0;

        total += amt;

        final c = Map<String, dynamic>.from(m);
        c['id'] = d.id;
        tx.add(c);
      }

      if (mounted) {
        setState(() {
          _spent = total;
          _transactions = tx;
        });
      }
    } catch (e, st) {
      debugPrint("[_fetchSpend] error: $e\n$st");
    }
  }

  // ---------------------- change period navigation (arrows) ----------------------
  void _changePeriodDate(bool next) {
    final now = DateTime.now();
    DateTime newDate = selectedDate;

    if (selectedPeriod == 'Day') {
      final nd = next ? _dayDate.add(const Duration(days: 1)) : _dayDate.subtract(const Duration(days: 1));
      final today = DateTime(now.year, now.month, now.day);
      if (next && DateTime(nd.year, nd.month, nd.day).isAfter(today)) return;
      _dayDate = nd;
      newDate = _dayDate;
    } else if (selectedPeriod == 'Week') {
      final nw = next ? _weekDate.add(const Duration(days: 7)) : _weekDate.subtract(const Duration(days: 7));
      final currentWeekStart = _startOfWeek(now);
      if (next && nw.isAfter(currentWeekStart.add(const Duration(days: 6)))) return;
      _weekDate = nw;
      newDate = _weekDate;
    } else if (selectedPeriod == 'Month') {
      final nm = _addMonths(_monthDate, next ? 1 : -1);
      final thisMonthStart = DateTime(now.year, now.month);
      if (next && (nm.year > now.year || (nm.year == now.year && nm.month > now.month))) return;
      _monthDate = nm;
      newDate = _monthDate;
    } else {
      final ny = _addYears(_yearDate, next ? 1 : -1);
      if (next && ny.year > now.year) return;
      _yearDate = ny;
      newDate = _yearDate;
    }

    if (mounted) {
      setState(() {
        selectedDate = newDate;
        _loading = true;
      });
    }

    _fetchSpend().whenComplete(() {
      if (mounted) setState(() => _loading = false);
    });
  }

  // ---------------------- UI helpers ----------------------
  Widget _buildLockedPeriodChip() {
    const double chipWidth = 100;
    const double chipHeight = 36;

    return Center(
      child: Container(
        width: chipWidth,
        height: chipHeight,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFF1CB0F6),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 6)],
        ),
        child: Text(
          selectedPeriod,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildDateNavigator() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    bool canGoNext = false;
    bool canGoPrev = true;

    if (selectedPeriod == 'Day') {
      canGoNext = _dayDate.isBefore(today);
    } else if (selectedPeriod == 'Week') {
      final ws = _startOfWeek(_weekDate);
      canGoNext = ws.add(const Duration(days: 6)).isBefore(today);
    } else if (selectedPeriod == 'Month') {
      canGoNext = _monthDate.isBefore(DateTime(now.year, now.month));
    } else {
      canGoNext = _yearDate.year < now.year;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: Icon(Icons.arrow_left, size: 28, color: Colors.black87),
          onPressed: () => _changePeriodDate(false),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF58CC02),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            _formatLockedRange(),
            style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w600),
          ),
        ),
        IconButton(
          icon: Icon(Icons.arrow_right, size: 28, color: canGoNext ? Colors.black87 : Colors.grey),
          onPressed: canGoNext ? () => _changePeriodDate(true) : null,
        ),
      ],
    );
  }

  void _editAlert() {
    if (_alertDoc == null) return;

    final data = _alertDoc!.data() as Map<String, dynamic>;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SetAlertsPage(
          isEditing: true,
          alertId: widget.alertId,
          initialCategory: data['categoryName'] ?? data['name'],
          initialCategoryId: data['categoryId'] ?? null,
          initialAmount: data['amount'] is num ? (data['amount'] as num).toDouble() : double.tryParse(data['amount'].toString()),
          initialFrequency: data['frequency'] ?? 'Monthly',
        ),
      ),
    ).then((_) {
      // Refresh alert data after editing
      _load();
    });
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (_) {
        return Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
            width: MediaQuery.of(context).size.width * 0.8,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Material(
              color: Colors.transparent,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Delete Alert",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "Are you sure you want to delete this alert?\nThis action cannot be undone.",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text(
                          "Cancel",
                          style: TextStyle(
                            color: Colors.grey,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text(
                          "Delete",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),
        );
      },
    );

    if (ok == true && _auth.currentUser != null) {
      await _firestore
          .collection('users')
          .doc(_auth.currentUser!.uid)
          .collection('budget_alert')
          .doc(widget.alertId)
          .delete();

      if (mounted) Navigator.pop(context);
    }
  }

  // ---------------------- build ----------------------
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_alertDoc == null || !_alertDoc!.exists) {
      return const Scaffold(
        body: Center(child: Text("Alert not found")),
      );
    }

    final data = _alertDoc!.data() as Map<String, dynamic>;
    final name = data['categoryName'] ?? data['name'] ?? 'Alert';
    final limit = (data['amount'] is num)
        ? (data['amount'] as num).toDouble()
        : double.tryParse(data['amount'].toString()) ?? 0;

    final progress = limit == 0 ? 0.0 : (_spent / limit).clamp(0.0, 1.0);
    final remaining = math.max(0, limit - _spent);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FB),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black87,
        centerTitle: true,
        title: Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: _confirmDelete,
          )
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildLockedPeriodChip(),
              const SizedBox(height: 12),
              _buildDateNavigator(),
              const SizedBox(height: 18),

              Center(
                child: Column(
                  children: [
                    BudgetGauge(
                        limit: limit,
                        spent: _spent,
                        size: 260,
                      ),


                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(15),
                            height: 120,
                            margin: const EdgeInsets.only(right: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFECEC),
                              borderRadius: BorderRadius.circular(22),
                              boxShadow: const [
                                BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4)),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text("Total Spent",
                                    style: TextStyle(
                                        fontSize: 15, fontWeight: FontWeight.w600, color: Colors.red.shade700)),
                                FittedBox(
                                  child: Text("₹${_spent.toStringAsFixed(0)}",
                                      style: TextStyle(
                                          fontSize: 26, fontWeight: FontWeight.w800, color: Colors.red.shade800)),
                                )
                              ],
                            ),
                          ),
                        ),

                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(15),
                            height: 120,
                            margin: const EdgeInsets.only(left: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF4DF),
                              borderRadius: BorderRadius.circular(22),
                              boxShadow: const [
                                BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4)),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text("Available Budget",
                                    style: TextStyle(
                                        fontSize: 15, fontWeight: FontWeight.w600, color: Colors.orange.shade700)),
                                FittedBox(
                                  child: Text("₹${remaining.toStringAsFixed(0)}",
                                      style: TextStyle(
                                          fontSize: 26, fontWeight: FontWeight.w800, color: Colors.orange.shade800)),
                                )
                              ],
                            ),
                          ),
                        )
                      ],
                    ),

                    const SizedBox(height: 14),

                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F3FF),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 6,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  "Set Limit",
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF1CB0F6),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "₹${limit.toStringAsFixed(0)}",
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF1CB0F6),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: _editAlert,
                          )
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "History",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_transactions.isEmpty)
                      Center(
                        child: Text(
                          "No transactions yet",
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      )
                    else
                      ..._transactions.map((t) {
                        final ts = t['timestamp'] is Timestamp ? (t['timestamp'] as Timestamp).toDate() : null;
                        final note = t['note'] ?? '';
                        final amt = t['amount'] ?? 0;

                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: Colors.grey.shade100,
                            child: const Text("₹", style: TextStyle(fontSize: 12)),
                          ),
                          title: Text(
                            "₹${amt.toString()}",
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            "${ts != null ? DateFormat('dd MMM yyyy').format(ts) : ''} • ${note.isEmpty ? "No note" : note}",
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ],
          ),
          ),
        ),
      ),
    );
  }
}

