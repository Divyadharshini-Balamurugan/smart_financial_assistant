import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SubcategoryPage extends StatefulWidget {
  final String categoryId;
  final String categoryName;
  final bool forIncome;

  const SubcategoryPage({
    super.key,
    required this.categoryId,
    required this.categoryName,
    this.forIncome = false,
  });

  @override
  State<SubcategoryPage> createState() => _SubcategoryPageState();
}

class _SubcategoryPageState extends State<SubcategoryPage> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  final TextEditingController _newSubcategoryController =
      TextEditingController();

  bool _showPopup = false;
  bool _isLoading = true;
  List<Map<String, dynamic>> _subcategories = [];

  @override
  void initState() {
    super.initState();
    _loadSubcategories();
  }

  Future<void> _loadSubcategories() async {
    setState(() => _isLoading = true);

    try {
      final parentCollection =
          widget.forIncome ? 'income_categories' : 'categories';
      final user = _auth.currentUser;

      List<Map<String, dynamic>> globalSubs = [];
      List<Map<String, dynamic>> userSubs = [];

      // 🔹 1) Load from GLOBAL collection (categories / income_categories)
      final globalDoc = await _firestore
          .collection(parentCollection)
          .doc(widget.categoryId)
          .get();

      if (globalDoc.exists) {
        final data = globalDoc.data();
        final List subs =
            (data != null && data['subcategories'] is List) ? data['subcategories'] : [];
        globalSubs = subs.map((e) => Map<String, dynamic>.from(e)).toList();
      }

      // 🔹 2) Load from USER collection (users/{uid}/categories or income_categories)
      if (user != null) {
        final userDoc = await _firestore
            .collection('users')
            .doc(user.uid)
            .collection(parentCollection)
            .doc(widget.categoryId)
            .get();

        if (userDoc.exists) {
          final data = userDoc.data();
          final List subs =
              (data != null && data['subcategories'] is List) ? data['subcategories'] : [];
          userSubs = subs.map((e) => Map<String, dynamic>.from(e)).toList();
        }
      }

      // 🔹 3) Merge global + user subcategories (avoid duplicates by id/name)
      final combined = <Map<String, dynamic>>[];
      final seen = <String>{};

      for (final s in [...globalSubs, ...userSubs]) {
        final idKey = (s['id']?.toString().isNotEmpty ?? false)
            ? s['id'].toString()
            : (s['name']?.toString() ?? '');
        if (idKey.isEmpty) continue;
        if (seen.contains(idKey)) continue;
        seen.add(idKey);
        combined.add(s);
      }

      setState(() {
        _subcategories = combined;
        // Always allow adding your own subcategory
        _subcategories.add({'id': '+', 'name': '+'});
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading subcategories: $e');
      setState(() {
        _subcategories = [
          {'id': '+', 'name': '+'}
        ];
        _isLoading = false;
      });
    }
  }

  Future<void> _addUserSubcategory(String name) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final parentCollection =
          widget.forIncome ? 'income_categories' : 'categories';

      final catDocRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection(parentCollection)
          .doc(widget.categoryId);

      final newSub = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'name': name,
      };

      // Add to array in Firestore (create doc if missing)
      await _firestore.runTransaction((tx) async {
        final snap = await tx.get(catDocRef);
        if (!snap.exists) {
          tx.set(catDocRef, {
            'name': widget.categoryName,
            'subcategories': [newSub],
            'createdAt': FieldValue.serverTimestamp(),
          });
        } else {
          tx.update(catDocRef, {
            'subcategories': FieldValue.arrayUnion([newSub])
          });
        }
      });

      // Update local list (insert before + tile)
      setState(() {
        if (_subcategories.isNotEmpty &&
            _subcategories.last['name'] == '+') {
          _subcategories.removeLast();
        }
        _subcategories.insert(_subcategories.length, newSub);
        _subcategories.add({'id': '+', 'name': '+'});
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Subcategory "$name" added successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugPrint('Error adding subcategory: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to add subcategory'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildCategoryCard(
      BuildContext context, Map<String, dynamic> category) {
    final isAddButton = category['name'] == '+';

    return GestureDetector(
      onTap: () {
        if (isAddButton) {
          setState(() => _showPopup = true);
        } else {
          Navigator.pop(context, category);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: isAddButton ? const Color(0xFF58CC02) : const Color(0xFFF4F4F4),
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.15),
              spreadRadius: 2,
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Text(
            category['name'],
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isAddButton ? Colors.white : Colors.black87,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _newSubcategoryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Text(
          widget.categoryName,
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _subcategories.length <= 1 // only '+' present
              ? Stack(
                  children: [
                    const Center(
                      child: Text(
                        'No subcategories available for this category',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ),
                    _buildGrid(),
                  ],
                )
              : _buildGrid(),
    );
  }

  Widget _buildGrid() {
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 18,
              mainAxisSpacing: 18,
              childAspectRatio: 1.2,
            ),
            itemCount: _subcategories.length,
            itemBuilder: (context, index) {
              final subcat = _subcategories[index];
              return _buildCategoryCard(context, subcat);
            },
          ),
        ),

        // Popup overlay for adding
        if (_showPopup)
          Container(
            color: Colors.black.withOpacity(0.5),
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 25),
                width: MediaQuery.of(context).size.width * 0.8,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Subcategory Name",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _newSubcategoryController,
                      decoration: InputDecoration(
                        hintText: 'Enter Name',
                        hintStyle: const TextStyle(
                          color: Colors.black54,
                          fontSize: 15,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        filled: true,
                        fillColor: Colors.grey.shade200,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _showPopup = false;
                              _newSubcategoryController.clear();
                            });
                          },
                          child: const Text(
                            "Cancel",
                            style: TextStyle(
                                color: Colors.grey,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF58CC02),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          onPressed: () async {
                            final name =
                                _newSubcategoryController.text.trim();
                            if (name.isNotEmpty) {
                              await _addUserSubcategory(name);
                              setState(() {
                                _showPopup = false;
                                _newSubcategoryController.clear();
                              });
                            }
                          },
                          child: const Text(
                            "Add",
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
          ),
      ],
    );
  }
}
