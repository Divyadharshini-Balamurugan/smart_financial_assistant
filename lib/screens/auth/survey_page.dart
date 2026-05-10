import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:typed_data';
import '../home/home_page.dart';
import '../navbar/main_page.dart';
import 'package:first_app/services/budget_profile_engine.dart';

class SurveyQuestion {
  final String id;
  final String question;
  final List<dynamic> options;
  final int order;
  final String? tag;

  SurveyQuestion({
    required this.id,
    required this.question,
    required this.options,
    required this.order,
    this.tag,
  });

  factory SurveyQuestion.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SurveyQuestion(
      id: doc.id,
      question: data['question'] ?? '',
      options: List<dynamic>.from(data['options'] ?? []),
      order: (data['order'] ?? 0) is int
          ? data['order'] as int
          : (data['order'] as num).toInt(),
      tag: data['tag'] as String?,
    );
  }
}

class SurveyService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<List<SurveyQuestion>> fetchQuestions() async {
    final snap = await _db.collection('survey').orderBy('order').get();
    return snap.docs.map((d) => SurveyQuestion.fromDoc(d)).toList();
  }

 Future<void> saveAnswer({
    required String questionId,
    required String question,
    int? selectedIndex,             // nullable for multi-select
    String? selectedValue,          // nullable for multi-select
    List<int>? selectedIndexes,     // multi-select
    List<dynamic>? selectedValues,   // multi-select
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final ref = _db
        .collection('users')
        .doc(user.uid)
        .collection('surveyResponses')
        .doc(questionId);

    final Map<String, dynamic> data = {
      'questionId': questionId,
      'question': question,
      'timestamp': FieldValue.serverTimestamp(),
    };

    if (selectedIndex != null && selectedValue != null) {
      data['selectedIndex'] = selectedIndex;
      data['selectedValue'] = selectedValue;
    }

    if (selectedIndexes != null && selectedValues != null) {
      data['selectedIndexes'] = selectedIndexes;
      data['selectedValues'] = selectedValues;
    }

    await ref.set(data, SetOptions(merge: true));
  }

  Future<void> markSurveyCompleted() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final ref = _db.collection('users').doc(user.uid);

    await ref.set({
      'surveyCompleted': true,
      'surveyCompletedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}

class SurveyOnboardingExact extends StatefulWidget {
  const SurveyOnboardingExact({Key? key}) : super(key: key);

  @override
  State<SurveyOnboardingExact> createState() => _SurveyOnboardingExactState();
}

class _SurveyOnboardingExactState extends State<SurveyOnboardingExact> {

  Map<String, dynamic> _buildEnginePayload() {
  String? getSingleValueByTag(String tag) {
    final q = _questions.firstWhere(
      (q) => q.tag == tag,
      orElse: () => SurveyQuestion(
        id: '',
        question: '',
        options: [],
        order: 0,
        tag: '',
      ),
    );

    if (q.id.isEmpty) return null;

    final idx = _selectedIndexForQuestion[q.id];
    if (idx == null) return null;

    final opt = q.options[idx];
    return (opt is String) ? opt : (opt['label'] ?? opt.toString());
  }

List<String> getMultiValuesByTag(String tag) {
  final q = _questions.firstWhere(
    (q) => q.tag == tag,
    orElse: () => SurveyQuestion(
      id: '',
      question: '',
      options: [],
      order: 0,
      tag: '',
    ),
  );

  if (q.id.isEmpty) return <String>[];

  final List<int> idxList =
      List<int>.from(_selectedValuesForQuestion[q.id] ?? []);

  return idxList.map<String>((i) {
    final dynamic opt = q.options[i];

    if (opt is String) {
      return opt;
    }

    if (opt is Map && opt.containsKey('label')) {
      return opt['label'].toString();
    }

    return opt.toString();
  }).toList();
}


  return {
    "role": getSingleValueByTag("role"),
    "income source": getSingleValueByTag("income source"),
    "monthly obligation": getMultiValuesByTag("monthly obligation"),
    "goal": getMultiValuesByTag("goal"),
    "spending style": getSingleValueByTag("spending style"),
    "income frequency": getSingleValueByTag("income frequency"),
  };
}


  final SurveyService _service = SurveyService();
  final PageController _pageController = PageController();

  List<SurveyQuestion> _questions = [];
  bool _loading = true;
  int _currentPage = 0;
  final Map<String, int> _selectedIndexForQuestion = {};
  final Map<String, List<int>> _selectedValuesForQuestion = {};

  
  final String owlFilePath = 'asset/images/noteing.png';
  final String progressImagePath = 'asset/images/noteing.png';

  static const Color brandBlue = Color(0xFF58CC02);

  @override
  void initState() {
    super.initState();
    _initAndLoad();
  }

  Future<void> _initAndLoad() async {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await Firebase.initializeApp();
      } catch (_) {}

      if (FirebaseAuth.instance.currentUser == null) {
        try {
          await FirebaseAuth.instance.signInAnonymously();
        } catch (_) {}
      }

      await _loadQuestions();
    });
  }

  Future<void> _loadQuestions() async {
    setState(() => _loading = true);
    try {
      final q = await _service.fetchQuestions();
      setState(() => _questions = q);
    } catch (e) {
      debugPrint('fetchQuestions error: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  double get _progress {
    if (_questions.isEmpty) return 0.0;
    return (_currentPage + 1) / _questions.length;
  }

  Future<void> _onOptionTap(int optionIndex) async {
    final question = _questions[_currentPage];
    setState(() {
      _selectedIndexForQuestion[question.id] = optionIndex;
    });

    final dynamic opt = question.options[optionIndex];
    final String selectedValue =
        (opt is String) ? opt : (opt['label'] ?? opt.toString());

    try {
      await _service.saveAnswer(
        questionId: question.id,
        question: question.question,
        selectedIndex: optionIndex,
        selectedValue: selectedValue,
      );
    } catch (e) {
      debugPrint('saveAnswer error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save answer.')),
        );
      }
    }
  }

Future<void> _onContinuePressed() async {
  final currentQuestion = _questions[_currentPage];

  final selectedIndex = _selectedIndexForQuestion[currentQuestion.id];
  final selectedMultiIndexes =
      _selectedValuesForQuestion[currentQuestion.id] ?? [];

  final bool isSingleSelect = selectedIndex != null;
  final bool isMultiSelect =
      selectedMultiIndexes.isNotEmpty;

  if (!isSingleSelect && !isMultiSelect) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Please select an option")),
    );
    return;
  }

  try {
    if (isSingleSelect) {
      final opt = currentQuestion.options[selectedIndex];
      final selectedValue =
          (opt is String) ? opt : (opt["label"] ?? opt.toString());

      await _service.saveAnswer(
        questionId: currentQuestion.id,
        question: currentQuestion.question,
        selectedIndex: selectedIndex,
        selectedValue: selectedValue,
      );
    } else {
      final selectedValues = selectedMultiIndexes.map((i) {
        final opt = currentQuestion.options[i];
        return (opt is String) ? opt : (opt["label"] ?? opt.toString());
      }).toList();

      await _service.saveAnswer(
        questionId: currentQuestion.id,
        question: currentQuestion.question,
        selectedIndexes: List.from(selectedMultiIndexes),
        selectedValues: selectedValues,
      );
    }
  } catch (e) {
    debugPrint("saveAnswer error: $e");
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Failed to save answer.")),
    );
    return;
  }

  if (_currentPage < _questions.length - 1) {
    setState(() => _currentPage++);
    _pageController.animateToPage(
      _currentPage,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeInOut,
    );
  } else {
await _service.markSurveyCompleted();

// 🔥 Run Budget Profile Engine
final enginePayload = _buildEnginePayload();
await BudgetProfileEngine().generateAndSaveProfile(enginePayload);

if (!mounted) return;

Navigator.pushReplacement(
  context,
  MaterialPageRoute(builder: (_) => const MainPage()),
);

  }
}

  Widget _buildProgressBar() {
    const double barHeight = 20.0;
    const double leftArrowWidth = 36.0;

    return Padding(
      padding: const EdgeInsets.only(left: 12, right: 12, top: 10, bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: leftArrowWidth,
            child: IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: const Icon(Icons.arrow_back, color: Colors.grey, size: 30),
              onPressed: () {
                if (_currentPage > 0) {
                  final prev = _currentPage - 1;
                  setState(() => _currentPage = prev);
                  _pageController.animateToPage(
                    prev,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                }
              },
            ),
          ),
          Expanded(
            child: LayoutBuilder(builder: (context, constraints) {
              final trackW = constraints.maxWidth;
              final value = _progress.clamp(0.0, 1.0);

              return TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: value),
                duration: const Duration(milliseconds: 420),
                builder: (context, animatedValue, child) {
                  return SizedBox(
                    height: barHeight,
                    child: Stack(
                      alignment: Alignment.centerLeft,
                      children: [
                        Container(
                          height: barHeight,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0F0F0),
                            borderRadius: BorderRadius.circular(barHeight),
                          ),
                        ),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(barHeight),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            widthFactor: animatedValue,
                            child: File(progressImagePath).existsSync()
                                ? Image.file(
                                    File(progressImagePath),
                                    width: trackW,
                                    height: barHeight,
                                    fit: BoxFit.cover,
                                  )
                                : Container(
                                    width: trackW * animatedValue,
                                    height: barHeight,
                                    decoration: BoxDecoration(
                                      color: brandBlue,
                                      borderRadius:
                                          BorderRadius.circular(barHeight),
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildSpeechRow(String questionText) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration:
                BoxDecoration(borderRadius: BorderRadius.circular(14)),
            child: FutureBuilder<ByteData?>(
              future: rootBundle
                  .load('asset/images/noteing.png')
                  .then((bd) => bd)
                  .catchError((_) => null),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Container(
                    width: 72,
                    height: 72,
                    color: Colors.grey.shade100,
                  );
                }
                if (snapshot.hasData && snapshot.data != null) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.asset(
                      'asset/images/noteing.png',
                      width: 72,
                      height: 72,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 72,
                          height: 72,
                          color: Colors.grey.shade200,
                          child: const Icon(Icons.broken_image,
                              size: 36, color: Colors.grey),
                        );
                      },
                    ),
                  );
                } else {
                  return Container(
                    width: 72,
                    height: 72,
                    color: Colors.grey.shade200,
                    child: const Icon(Icons.broken_image,
                        size: 36, color: Colors.grey),
                  );
                }
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: const Color(0xFFDDDDDD), width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Text(
                    questionText,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
                Positioned(
                  left: -8,
                  top: 26,
                  child: Transform.rotate(
                    angle: -0.35,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(
                            color: const Color(0xFFDDDDDD), width: 1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionCard({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFFE6F5FB)
              : const Color(0xFFF6F6F8),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFDFDFDF), width: 1.4),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight:
                      selected ? FontWeight.w700 : FontWeight.w600,
                  color: selected ? const Color(0xFF1CB0F6) : Colors.black87,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

Widget _buildPage(SurveyQuestion q) {
  if (q.tag == 'monthly obligation') {
    final List<int> selectedIdxList =
        List.from(_selectedValuesForQuestion[q.id] ?? []);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildProgressBar(),
        const SizedBox(height: 6),
        _buildSpeechRow(q.question),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 120, top: 4),
            itemCount: q.options.length,
            itemBuilder: (context, idx) {
              final dynamic opt = q.options[idx];
              final String label =
                  (opt is String) ? opt : (opt['label'] ?? opt.toString());
              final bool isSelected = selectedIdxList.contains(idx);

              return _buildOptionCard(
                label: label,
                selected: isSelected,
onTap: () async {
  setState(() {
    if (isSelected) {
      selectedIdxList.remove(idx);
    } else {
      selectedIdxList.add(idx);
    }
    _selectedValuesForQuestion[q.id] = selectedIdxList;
  });

  final selectedValues = selectedIdxList
      .map((i) => q.options[i].toString())
      .toList();

  await _service.saveAnswer(
    questionId: q.id,
    question: q.question,
    selectedIndexes: selectedIdxList,
    selectedValues: selectedValues,
  );
}

              );
            },
          ),
        ),
      ],
    );
  } else {
    final selectedIdx = _selectedIndexForQuestion[q.id];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildProgressBar(),
        const SizedBox(height: 6),
        _buildSpeechRow(q.question),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 120, top: 4),
            itemCount: q.options.length,
            itemBuilder: (context, idx) {
              final dynamic opt = q.options[idx];
              final String label =
                  (opt is String) ? opt : (opt['label'] ?? opt.toString());
              final bool sel = selectedIdx == idx;

              return _buildOptionCard(
                label: label,
                selected: sel,
                onTap: () => _onOptionTap(idx),
              );
            },
          ),
        ),
      ],
    );
  }
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
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _questions.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('No survey questions found.'),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _loadQuestions,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : Stack(
                    children: [
                      PageView.builder(
                        controller: _pageController,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _questions.length,
                        itemBuilder: (ctx, i) => _buildPage(_questions[i]),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 12,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16.0),
                          child: SizedBox(
                            height: 56,
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _onContinuePressed,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: brandBlue,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 6,
                              ),
                              child: Text(
                                _currentPage < _questions.length - 1
                                    ? 'CONTINUE'
                                    : 'FINISH',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}
