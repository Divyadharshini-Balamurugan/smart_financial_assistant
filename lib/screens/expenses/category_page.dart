// category_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CategoryPage extends StatefulWidget {
  final bool forIncome; // <-- flag

  const CategoryPage({super.key, this.forIncome = false});

  @override
  State<CategoryPage> createState() => _CategoryPageState();
}

class _CategoryPageState extends State<CategoryPage> {
  final TextEditingController _newCategoryController = TextEditingController();
  bool _showPopup = false;

  List<Map<String, dynamic>> _categories = [];
  bool _isLoading = true;

  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      // choose collection names based on flag
      final globalCollectionName = widget.forIncome ? 'income_categories' : 'categories';
      final userCollectionName = widget.forIncome ? 'income_categories' : 'categories';

      // 🔹 Fetch global categories
      final globalSnap = await _firestore.collection(globalCollectionName).get();
      final globalCategories = globalSnap.docs
          .map((doc) => {'id': doc.id, 'name': doc['name'] as String})
          .toList();

      // 🔹 Fetch user-specific categories
      final userSnap = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection(userCollectionName)
          .get();
      final userCategories = userSnap.docs
          .map((doc) => {'id': doc.id, 'name': doc['name'] as String})
          .toList();

      // 🔹 Combine both (avoid duplicates by name)
      final combinedNames = <String>{};
      final combined = <Map<String, dynamic>>[];

      for (final c in [...globalCategories, ...userCategories]) {
        if (!combinedNames.contains(c['name'])) {
          combinedNames.add(c['name']!);
          combined.add(c);
        }
      }

      setState(() {
        _categories = combined;
        _categories.add({'id': '+', 'name': '+'}); // Add button at last
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading categories: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addUserCategory(String name) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final userCollectionName = widget.forIncome ? 'income_categories' : 'categories';

      final catRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection(userCollectionName)
          .doc();

      await catRef.set({
        'name': name,
        'subcategories': [],
        'createdAt': FieldValue.serverTimestamp(),
      });

      setState(() {
        _categories.insert(_categories.length - 1, {'id': catRef.id, 'name': name});
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Category "$name" added successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugPrint('Error adding category: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to add category'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
        title: const Text(
          "Category",
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 18,
                      mainAxisSpacing: 18,
                      childAspectRatio: 1.2,
                    ),
                    itemCount: _categories.length,
                    itemBuilder: (context, index) {
                      final category = _categories[index];
                      return _buildCategoryCard(context, category);
                    },
                  ),
                ),

                // 🔹 Grey overlay with popup
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
                              "Category Name",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: _newCategoryController,
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
                                      _newCategoryController.clear();
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
                                        _newCategoryController.text.trim();
                                    if (name.isNotEmpty) {
                                      await _addUserCategory(name);
                                      setState(() {
                                        _showPopup = false;
                                        _newCategoryController.clear();
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
            ),
    );
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
          color:
              isAddButton ? const Color(0xFF58CC02) : const Color(0xFFF4F4F4),
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
}
