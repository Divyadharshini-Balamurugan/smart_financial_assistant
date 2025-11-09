import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:first_app/services/analytics_controller.dart';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  String selectedPeriod = 'Week';
  DateTime selectedDate = DateTime.now();
  DateTime _dayDate = DateTime.now();
  DateTime _weekDate = DateTime.now();
  DateTime _monthDate = DateTime.now();
  DateTime _yearDate = DateTime.now();

  final PageController _pageController = PageController(initialPage: 0);
  int _currentPage = 0;

  final AnalyticsService _analyticsService = AnalyticsService();

  double _expenseTotal = 0;
  double _incomeTotal = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTotals();
  }

  Future<void> _loadTotals() async {
    try {
      final totals = await _analyticsService.fetchTotals(
        period: selectedPeriod,
        date: selectedDate,
      );
      setState(() {
        _expenseTotal = totals['expense']!;
        _incomeTotal = totals['income']!;
        _isLoading = false;
      });
    } catch (e) {
      print("Error loading totals: $e");
      setState(() => _isLoading = false);
    }
  }

  int _daysInMonth(int year, int month) {
    final nextMonth = (month == 12)
        ? DateTime(year + 1, 1, 1)
        : DateTime(year, month + 1, 1);
    final thisMonth = DateTime(year, month, 1);
    return nextMonth.difference(thisMonth).inDays;
  }

  DateTime _addMonths(DateTime date, int months) {
    final totalMonths = date.year * 12 + (date.month - 1) + months;
    final newYear = totalMonths ~/ 12;
    final newMonth = (totalMonths % 12) + 1;
    final newDay = min(date.day, _daysInMonth(newYear, newMonth));
    return DateTime(newYear, newMonth, newDay, date.hour, date.minute,
        date.second, date.millisecond, date.microsecond);
  }

  DateTime _addYears(DateTime date, int years) => _addMonths(date, years * 12);

  String getFormattedRange() {
    if (selectedPeriod == 'Day') {
      return DateFormat('d MMM yyyy').format(selectedDate);
    } else if (selectedPeriod == 'Week') {
      final startOfWeek =
          selectedDate.subtract(Duration(days: selectedDate.weekday - 1));
      final endOfWeek = startOfWeek.add(const Duration(days: 6));
      return '${DateFormat('d MMM').format(startOfWeek)} - ${DateFormat('d MMM yyyy').format(endOfWeek)}';
    } else if (selectedPeriod == 'Month') {
      return DateFormat('MMMM yyyy').format(selectedDate);
    } else if (selectedPeriod == 'Year') {
      return DateFormat('yyyy').format(selectedDate);
    }
    return '';
  }

  void _onPeriodChange(String newPeriod) {
    setState(() {
      selectedPeriod = newPeriod;
      _isLoading = true;

      if (selectedPeriod == 'Day') {
        selectedDate = _dayDate;
      } else if (selectedPeriod == 'Week') {
        selectedDate = _weekDate;
      } else if (selectedPeriod == 'Month') {
        selectedDate = _monthDate;
      } else if (selectedPeriod == 'Year') {
        selectedDate = _yearDate;
      }
    });

    _loadTotals();
  }

  void _changePeriod(bool isNext) {
  final now = DateTime.now();

  DateTime? newDate;

  if (selectedPeriod == 'Day') {
    final nextDay = isNext
        ? _dayDate.add(const Duration(days: 1))
        : _dayDate.subtract(const Duration(days: 1));
    final today = DateTime(now.year, now.month, now.day);

    DateTime todayDateOnly = DateTime(now.year, now.month, now.day);
    DateTime nextDayDateOnly = DateTime(nextDay.year, nextDay.month, nextDay.day);

if (isNext && nextDayDateOnly.isAfter(todayDateOnly)) return;; // block future days
    newDate = nextDay;
  } else if (selectedPeriod == 'Week') {
    final nextWeek = isNext
        ? _weekDate.add(const Duration(days: 7))
        : _weekDate.subtract(const Duration(days: 7));
    final currentWeekStart = now.subtract(Duration(days: now.weekday - 1));
    if (isNext && nextWeek.isAfter(currentWeekStart.add(const Duration(days: 6)))) return;
    newDate = nextWeek;
  } else if (selectedPeriod == 'Month') {
    final nextMonth = _addMonths(_monthDate, isNext ? 1 : -1);
    if (isNext &&
        (nextMonth.year > now.year ||
            (nextMonth.year == now.year && nextMonth.month > now.month))) return;
    newDate = nextMonth;
  } else if (selectedPeriod == 'Year') {
    final nextYear = _addYears(_yearDate, isNext ? 1 : -1);
    if (isNext && nextYear.year > now.year) return;
    newDate = nextYear;
  }

  if (newDate != null) {
    setState(() {
      _isLoading = true;
      if (selectedPeriod == 'Day') _dayDate = newDate!;
      else if (selectedPeriod == 'Week') _weekDate = newDate!;
      else if (selectedPeriod == 'Month') _monthDate = newDate!;
      else if (selectedPeriod == 'Year') _yearDate = newDate!;
      selectedDate = newDate!;
    });
    _loadTotals();
  }
}



  Widget _buildExpenseIncomeCard({
    required String title,
    required String amount,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        margin: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            Text(
              title,
              style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              amount,
              style: TextStyle(
                color: color,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodSelector() {
    final periods = ['Day', 'Week', 'Month', 'Year'];
    return Row(
      children: periods.map((period) {
        final isSelected = selectedPeriod == period;
        return Expanded(
          child: GestureDetector(
            onTap: () => _onPeriodChange(period),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF1CB0F6) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF1CB0F6)
                      : Colors.grey.shade300,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                period,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

Widget _buildDateNavigator() {
 DateTime now = DateTime.now();
DateTime today = DateTime(now.year, now.month, now.day);

bool canGoNext = false;
bool canGoPrev = true;

if (selectedPeriod == 'Day') {
  canGoNext = _dayDate.isBefore(today);
  canGoPrev = true;
} else if (selectedPeriod == 'Week') {
  final weekStart = _weekDate;
  final weekEnd = weekStart.add(const Duration(days: 6));
  // Can go next only if current week ends before today’s week
  canGoNext = weekEnd.isBefore(today);
  canGoPrev = true;
} else if (selectedPeriod == 'Month') {
  final thisMonthStart = DateTime(now.year, now.month);
  canGoNext = _monthDate.isBefore(thisMonthStart);
  canGoPrev = true;
} else if (selectedPeriod == 'Year') {
  canGoNext = _yearDate.year < now.year;
  canGoPrev = true;
}

  return Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      IconButton(
        icon: Icon(
          Icons.arrow_left,
          size: 28,
          color: canGoPrev ? Colors.black87 : Colors.grey.shade400,
        ),
        onPressed: canGoPrev ? () => _changePeriod(false) : null,
      ),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF58CC02),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          getFormattedRange(),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      IconButton(
        icon: Icon(
          Icons.arrow_right,
          size: 28,
          color: canGoNext ? Colors.black87 : Colors.grey.shade400,
        ),
        onPressed: canGoNext ? () => _changePeriod(true) : null,
      ),
    ],
  );
}


  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Analytics',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildPeriodSelector(),
            const SizedBox(height: 12),
            _buildDateNavigator(),
            const SizedBox(height: 24),
            _isLoading
                ? const CircularProgressIndicator()
                : Row(
                    children: [
                      _buildExpenseIncomeCard(
                        title: 'Expense',
                        amount: '₹${_expenseTotal.toStringAsFixed(2)}',
                        color: Colors.redAccent,
                      ),
                      _buildExpenseIncomeCard(
                        title: 'Income',
                        amount: '₹${_incomeTotal.toStringAsFixed(2)}',
                        color: Colors.green,
                      ),
                    ],
                  ),
            const SizedBox(height: 24),
            Expanded(
              child: Column(
                children: [
                  Expanded(
                    child: PageView(
                      controller: _pageController,
                      onPageChanged: (index) =>
                          setState(() => _currentPage = index),
                      children: [
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Center(
                            child: Text(
                              'Category-wise Chart Here',
                              style: TextStyle(
                                color: Colors.deepOrange,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Center(
                            child: Text(
                              'Expense vs Income Chart Here',
                              style: TextStyle(
                                color: Colors.blueGrey,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Center(
                            child: Text(
                              'Payment Mode Chart Here',
                              style: TextStyle(
                                color: Colors.green,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(3, (index) {
                      final isActive = index == _currentPage;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        height: 8,
                        width: isActive ? 20 : 8,
                        decoration: BoxDecoration(
                          color: isActive
                              ? const Color(0xFF1CB0F6)
                              : Colors.grey.shade400,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
