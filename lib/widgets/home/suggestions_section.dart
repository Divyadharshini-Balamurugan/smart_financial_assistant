import 'dart:async';
import 'package:flutter/material.dart';

class SuggestionsSection extends StatefulWidget {
  const SuggestionsSection({super.key});

  @override
  State<SuggestionsSection> createState() => _SuggestionsSectionState();
}

class _SuggestionsSectionState extends State<SuggestionsSection> {
  final List<String> _advices = [
    "Save at least 10% of your income every month.",
    "Track your daily expenses to find hidden spending habits.",
    "Invest early to benefit from compound interest.",
    "Set small weekly financial goals to stay motivated.",
  ];

  int _currentIndex = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Auto slide every 30 seconds
    _timer = Timer.periodic(const Duration(seconds: 30), (timer) {
      setState(() {
        _currentIndex = (_currentIndex + 1) % _advices.length;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _nextAdvice() {
    setState(() {
      _currentIndex = (_currentIndex + 1) % _advices.length;
    });
  }

  void _prevAdvice() {
    setState(() {
      _currentIndex =
          (_currentIndex - 1 + _advices.length) % _advices.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🔹 Section Title
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              "Personalized Tips",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Colors.black87,
              ),
            ),
          ),

          // 🔹 Advice Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 30),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: const Color(0xFF4C338E), // 🟣 subtle purple border
                width: 0.8, // very thin border
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                // ◀️ Previous
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.grey),
                  onPressed: _prevAdvice,
                ),

                // 🧠 Advice Text
                Expanded(
                  child: Center(
                    child: Text(
                      _advices[_currentIndex],
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        color: Colors.black87,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                    ),
                  ),
                ),

                // ▶️ Next
                IconButton(
                  icon: const Icon(Icons.arrow_forward_ios_rounded,
                      color: Colors.grey),
                  onPressed: _nextAdvice,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
