import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ExportDataSection extends StatefulWidget {
  const ExportDataSection({super.key});

  @override
  State<ExportDataSection> createState() => _ExportDataSectionState();
}

class _ExportDataSectionState extends State<ExportDataSection> {
  final TextEditingController _fromDateController = TextEditingController();
  final TextEditingController _toDateController = TextEditingController();

  DateTime? _fromDate;
  DateTime? _toDate;

  Future<void> _selectDate(BuildContext context, bool isFrom) async {
    final DateTime now = DateTime.now();
    final DateTime initialDate =
        isFrom ? (_fromDate ?? now.subtract(const Duration(days: 7))) : (_toDate ?? now);
    final DateTime firstDate = isFrom ? DateTime(2020) : (_fromDate ?? DateTime(2020));
    final DateTime lastDate = now;

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF4C338E), // 🟣 themed purple
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isFrom) {
          _fromDate = picked;
          _fromDateController.text = DateFormat('yyyy-MM-dd').format(picked);
          if (_toDate != null && _toDate!.isBefore(picked)) {
            _toDate = null;
            _toDateController.clear();
          }
        } else {
          _toDate = picked;
          _toDateController.text = DateFormat('yyyy-MM-dd').format(picked);
        }
      });
    }
  }

  @override
  void dispose() {
    _fromDateController.dispose();
    _toDateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🔹 Section title
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              "Export Data",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Colors.black87,
              ),
            ),
          ),

          // 🔹 Card container
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: const Color(0xFF4C338E),
                width: 0.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 🔹 From Date
                TextFormField(
                  controller: _fromDateController,
                  readOnly: true,
                  onTap: () => _selectDate(context, true),
                  decoration: const InputDecoration(
                    labelText: "From Date",
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.calendar_today, color: Color(0xFF4C338E)),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 15),

                // 🔹 To Date
                TextFormField(
                  controller: _toDateController,
                  readOnly: true,
                  onTap: () => _selectDate(context, false),
                  decoration: const InputDecoration(
                    labelText: "To Date",
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.calendar_today, color: Color(0xFF4C338E)),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 20),

                // 🔹 Generate Report button (Duolingo-style)
                SizedBox(
                  width: double.infinity,
                  height: 45,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.file_download_outlined, color: Colors.white),
                    label: const Text(
                      "Generate Report",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.white
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1CB0F6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    onPressed: () {
                      if (_fromDate == null || _toDate == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Please select both From and To dates."),
                          ),
                        );
                        return;
                      }

                      if (_toDate!.isBefore(_fromDate!)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("To Date cannot be before From Date."),
                          ),
                        );
                        return;
                      }

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              "Generating report from ${_fromDateController.text} to ${_toDateController.text}..."),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
