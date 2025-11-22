import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import 'package:first_app/services/analytics_controller.dart';
import 'package:first_app/widgets/analytics/category_pie_chart.dart';
import 'package:first_app/widgets/analytics/payment_method_pie_chart.dart';
import 'package:first_app/widgets/analytics/expense_income_bar.dart';

/// Analytics Page — displays income & expense summaries by day, week, month, or year.
class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  /// Currently selected period type
  String selectedPeriod = 'Week';

  Map<String, double> _categoryTotals = {};
  Map<String, double> _paymentMethodTotals = {};
  Map<String, double> _expenseSeries = {};
  Map<String, double> _incomeSeries = {};

  /// Tracks the reference date for each period
  DateTime selectedDate = DateTime.now();
  DateTime _dayDate = DateTime.now();
  DateTime _weekDate = DateTime.now();
  DateTime _monthDate = DateTime.now();
  DateTime _yearDate = DateTime.now();

  /// Page controller for charts
  final PageController _pageController = PageController(initialPage: 0);
  int _currentPage = 0;

  /// Analytics data service — ensure this matches your controller class name
  final AnalyticsService _analyticsService = AnalyticsService();

  /// Totals
  double _expenseTotal = 0;
  double _incomeTotal = 0;

  /// Loader flag
  bool _isLoading = true;

  // ----------------------------------------------------------
  // INITIALIZATION
  // ----------------------------------------------------------
  @override
  void initState() {
    super.initState();
    _loadTotals();
  }

  // ----------------------------------------------------------
  // FETCH TOTALS (null-safe)
  // ----------------------------------------------------------
  Future<void> _loadTotals() async {
    try {
      final totals = await _analyticsService.fetchTotals(
        period: selectedPeriod,
        date: selectedDate,
      );

      final categoryData = await _analyticsService.fetchCategoryTotals(
        period: selectedPeriod,
        date: selectedDate,
      );

      final paymentMethodData = await _analyticsService.fetchPaymentMethodTotals(
        period: selectedPeriod,
        date: selectedDate,
      );

      final seriesDual = await _analyticsService.fetchExpenseIncomeSeriesDual(
        period: selectedPeriod,
        date: selectedDate,
      );

      setState(() {
        _expenseTotal = (totals['expense'] ?? 0.0);
        _incomeTotal = (totals['income'] ?? 0.0);
        _categoryTotals = categoryData ?? {};
        _paymentMethodTotals = paymentMethodData ?? {};
        _expenseSeries = seriesDual['expense'] ?? {};
        _incomeSeries = seriesDual['income'] ?? {};
        _isLoading = false;
      });
    } catch (e, st) {
      debugPrint("Error loading totals: $e\n$st");
      setState(() => _isLoading = false);
    }
  }

  // ----------------------------------------------------------
  // DATE HELPERS
  // ----------------------------------------------------------

  /// Get number of days in a month
  int _daysInMonth(int year, int month) {
    final nextMonth = (month == 12)
        ? DateTime(year + 1, 1, 1)
        : DateTime(year, month + 1, 1);
    final thisMonth = DateTime(year, month, 1);
    return nextMonth.difference(thisMonth).inDays;
  }

  /// Add or subtract months safely (keeping date within valid range)
  DateTime _addMonths(DateTime date, int months) {
    final totalMonths = date.year * 12 + (date.month - 1) + months;
    final newYear = totalMonths ~/ 12;
    final newMonth = (totalMonths % 12) + 1;
    final newDay = math.min(date.day, _daysInMonth(newYear, newMonth));
    return DateTime(
      newYear,
      newMonth,
      newDay,
      date.hour,
      date.minute,
      date.second,
      date.millisecond,
      date.microsecond,
    );
  }

  /// Add or subtract years
  DateTime _addYears(DateTime date, int years) => _addMonths(date, years * 12);

  /// Display formatted date or range based on selected period
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

  // ----------------------------------------------------------
  // PERIOD SELECTION & NAVIGATION
  // ----------------------------------------------------------

  /// When user taps Day/Week/Month/Year tabs
  void _onPeriodChange(String newPeriod) {
    setState(() {
      selectedPeriod = newPeriod;
      _isLoading = true;

      // Restore the saved date for this period
      if (newPeriod == 'Day') selectedDate = _dayDate;
      if (newPeriod == 'Week') selectedDate = _weekDate;
      if (newPeriod == 'Month') selectedDate = _monthDate;
      if (newPeriod == 'Year') selectedDate = _yearDate;
    });

    _loadTotals();
  }

  void _changePeriod(bool isNext) {
    final now = DateTime.now();
    late DateTime newDate; //non-nullable

    if (selectedPeriod == 'Day') {
      final nextDay = isNext
          ? _dayDate.add(const Duration(days: 1))
          : _dayDate.subtract(const Duration(days: 1));

      final today = DateTime(now.year, now.month, now.day);
      final nextDayOnly = DateTime(nextDay.year, nextDay.month, nextDay.day);

      if (isNext && nextDayOnly.isAfter(today)) return;
      newDate = nextDay;
    } else if (selectedPeriod == 'Week') {
      final nextWeek = isNext
          ? _weekDate.add(const Duration(days: 7))
          : _weekDate.subtract(const Duration(days: 7));
      final currentWeekStart = now.subtract(Duration(days: now.weekday - 1));
      if (isNext &&
          nextWeek.isAfter(currentWeekStart.add(const Duration(days: 6)))) return;
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

    setState(() {
      _isLoading = true;
      if (selectedPeriod == 'Day') _dayDate = newDate;
      if (selectedPeriod == 'Week') _weekDate = newDate;
      if (selectedPeriod == 'Month') _monthDate = newDate;
      if (selectedPeriod == 'Year') _yearDate = newDate;
      selectedDate = newDate;
    });

    _loadTotals();
  }

  Map<String, Map<String, double>> _mergeExpenseIncomeSeries() {
  // Preserve order: expense keys first, then income-only keys
  final List<String> labels = [];

  for (final k in _expenseSeries.keys) {
    if (!labels.contains(k)) labels.add(k);
  }
  for (final k in _incomeSeries.keys) {
    if (!labels.contains(k)) labels.add(k);
  }

  final Map<String, Map<String, double>> merged = {};
  for (final label in labels) {
    merged[label] = {
      'expense': (_expenseSeries[label] ?? 0.0),
      'income': (_incomeSeries[label] ?? 0.0),
    };
  }
  return merged;
}

  // ----------------------------------------------------------
  // UI WIDGETS
  // ----------------------------------------------------------

  /// Expense/Income card widget
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
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                amount,
                style: TextStyle(
                  color: color,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Period selector (Day / Week / Month / Year)
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
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF1CB0F6) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF1CB0F6)
                      : Colors.grey.shade300,
                ),
              ),
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

Widget _buildExpenseIncomeChart() {
  // keep behavior: show loader when loading
  if (_isLoading) return const Center(child: CircularProgressIndicator());

  // For Day -> show simple summary by building a two-label data map
  if (selectedPeriod == 'Day') {
    final Map<String, Map<String, double>> dayMap = {
      'Expense': {'expense': _expenseTotal, 'income': 0.0},
      'Income': {'expense': 0.0, 'income': _incomeTotal},
    };

    return ExpenseIncomeBar(
      data: dayMap,
      height: math.min(420.0, MediaQuery.of(context).size.height * 0.45),
    );
  }

  // For Week/Month/Year: prefer merged dual-series when either series exists
  final hasExpenseSeries = _expenseSeries.isNotEmpty;
  final hasIncomeSeries = _incomeSeries.isNotEmpty;

  if (hasExpenseSeries || hasIncomeSeries) {
    final merged = _mergeExpenseIncomeSeries();
    if (merged.isNotEmpty) {
      return ExpenseIncomeBar(
        data: merged,
        height: math.min(420.0, MediaQuery.of(context).size.height * 0.45),
      );
    }
  }

  // Fallback to two-bar summary if no series available
  final Map<String, Map<String, double>> fallbackMap = {
    'Expense': {'expense': _expenseTotal, 'income': 0.0},
    'Income': {'expense': 0.0, 'income': _incomeTotal},
  };

  return ExpenseIncomeBar(
    data: fallbackMap,
    height: math.min(420.0, MediaQuery.of(context).size.height * 0.45),
  );
}


  /// Date navigator with arrows (← Date →)
  Widget _buildDateNavigator() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    bool canGoNext = false;
    bool canGoPrev = true;

    if (selectedPeriod == 'Day') {
      canGoNext = _dayDate.isBefore(today);
    } else if (selectedPeriod == 'Week') {
      final weekStart = _weekDate;
      final weekEnd = weekStart.add(const Duration(days: 6));
      canGoNext = weekEnd.isBefore(today);
    } else if (selectedPeriod == 'Month') {
      final thisMonthStart = DateTime(now.year, now.month);
      canGoNext = _monthDate.isBefore(thisMonthStart);
    } else if (selectedPeriod == 'Year') {
      canGoNext = _yearDate.year < now.year;
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

  // ----------------------------------------------------------
  // DISPOSE
  // ----------------------------------------------------------
  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // ----------------------------------------------------------
  // BUILD
  // ----------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    // Compute a responsive chart height (keeps layout flexible)
    final screenHeight = MediaQuery.of(context).size.height;
    final chartHeight = math.min(420.0, screenHeight * 0.45);

    return Scaffold(
      resizeToAvoidBottomInset: false,
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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              _buildPeriodSelector(),
              const SizedBox(height: 12),
              _buildDateNavigator(),
              const SizedBox(height: 24),

              // Expense & Income summary
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

              // Chart section: Expanded single child scroll, but PageView has bounded height
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    children: [
                      // PageView with a fixed responsive height (no Expanded inside scroll)
                      SizedBox(
                        height: chartHeight,
                        child: PageView(
                          controller: _pageController,
                          onPageChanged: (index) =>
                              setState(() => _currentPage = index),
                          children: [
                            _chartPlaceholder(
                              text: 'Category-wise Chart',
                              color: Colors.deepOrange,
                              bgColor: Colors.orange.shade50,
                              child: CategoryPieCard(
                                categoryTotals: _categoryTotals,
                              ),
                            ),
                            _chartPlaceholder(
                              text: 'Expense vs Income',
                              color: Colors.blueGrey,
                              bgColor: Colors.blue.shade50,
                              child: _buildExpenseIncomeChart(),
                            ),
                            _chartPlaceholder(
                              text: 'Payment Method Chart',
                              color: Colors.green,
                              bgColor: Colors.green.shade50,
                              child: PaymentMethodPieCard(
                                paymentTotals: _paymentMethodTotals,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 10),

                      // Page indicator dots
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
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Placeholder widget for charts (bounded height, responsive, overflow-safe)
  Widget _chartPlaceholder({
    required String text,
    required Color color,
    required Color bgColor,
    Widget? child,
    double? height, // optional explicit height
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenHeight = MediaQuery.of(context).size.height;
        final parentHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : screenHeight * 0.5;

        // Reserve space for header + padding; cap chart height
        const reservedForHeader = 72.0;
        const maxChartHeight = 420.0;
        final defaultChartHeight =
            math.min(maxChartHeight, parentHeight - reservedForHeader);

        final chartHeight =
            (height ?? defaultChartHeight).clamp(140.0, maxChartHeight);

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 20), // 👈 extra bottom padding
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Text(
                    text,
                    style: TextStyle(
                      color: color,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: chartHeight,
                  width: double.infinity,
                  child: child ??
                      const Center(
                        child: Text(
                          'No data available',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
