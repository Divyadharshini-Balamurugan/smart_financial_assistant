import 'dart:async';
import 'package:flutter/material.dart';
import '/services/suggestion_service.dart';

class SuggestionsSection extends StatefulWidget {
  const SuggestionsSection({super.key});

  @override
  State<SuggestionsSection> createState() => _SuggestionsSectionState();
}

class _SuggestionsSectionState extends State<SuggestionsSection> {
  List<String> _advices = [];
  int _currentIndex = 0;
  Timer? _timer;

  final SuggestionService _suggestionService = SuggestionService();

  @override
void initState() {
  super.initState();
  _advices = []; // show loader while checking
  _initSuggestions();
}

Future<void> _initSuggestions() async {
  // 1) read cache or generate (this method returns stored instantly if exists)
  final suggestions = await _suggestionService.fetchOrGenerate();
  setState(() {
    _advices = suggestions.isNotEmpty
        ? suggestions
        : ['No suggestions available. Update profile or expenses.'];
  });

  // 2) start timer after advices loaded
  _timer = Timer.periodic(const Duration(seconds: 30), (timer) {
    if (_advices.isNotEmpty) {
      setState(() {
        _currentIndex = (_currentIndex + 1) % _advices.length;
      });
    }
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
      _currentIndex = (_currentIndex - 1 + _advices.length) % _advices.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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

          if (_advices.isEmpty)
            const Center(child: CircularProgressIndicator()),

          if (_advices.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 30),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: Color(0xFF4C338E),
                  width: 0.8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: Colors.grey),
                    onPressed: _prevAdvice,
                  ),
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
