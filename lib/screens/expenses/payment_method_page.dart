import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PaymentMethodPage extends StatefulWidget {
  const PaymentMethodPage({super.key});

  @override
  State<PaymentMethodPage> createState() => _PaymentMethodPageState();
}

class _PaymentMethodPageState extends State<PaymentMethodPage> {
  final TextEditingController _newMethodController = TextEditingController();
  bool _showPopup = false;

  List<Map<String, String>> allMethods = [];
  List<Map<String, String>> globalMethods = [];

  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _loadPaymentMethods();
  }

  /// 🔹 Load both global and user-specific payment methods
  Future<void> _loadPaymentMethods() async {
    final user = _auth.currentUser;
    if (user == null) return;

    // Fetch global methods
    final globalSnapshot = await _firestore.collection('payment_methods').get();
    final globalList = globalSnapshot.docs.map((doc) {
      return {'id': doc.id, 'name': doc['name'] as String};
    }).toList();

    // Fetch user-added methods
    final userSnapshot = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('paymentMethods')
        .get();
    final userList = userSnapshot.docs.map((doc) {
      return {'id': doc.id, 'name': doc['name'] as String};
    }).toList();

    setState(() {
      globalMethods = globalList;
      allMethods = [...globalList, ...userList, {'id': 'add', 'name': '+'}];
    });
  }

  /// 🔹 Add new method and return ID + name
  Future<Map<String, String>> _addPaymentMethod(String name) async {
    final user = _auth.currentUser;
    if (user == null) return {};

    final methodRef = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('paymentMethods')
        .doc();

    await methodRef.set({
      'name': name,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return {'id': methodRef.id, 'name': name};
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
          "Payment Method",
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: allMethods.isEmpty
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF58CC02)),
                  )
                : GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 18,
                      mainAxisSpacing: 18,
                      childAspectRatio: 1.2,
                    ),
                    itemCount: allMethods.length,
                    itemBuilder: (context, index) {
                      final method = allMethods[index];
                      return _buildPaymentCard(context, method);
                    },
                  ),
          ),

          // 🔹 Popup Overlay
          if (_showPopup)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
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
                        "Payment Method Name",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _newMethodController,
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
                                _newMethodController.clear();
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
                              final name = _newMethodController.text.trim();
                              if (name.isNotEmpty) {
                                final newMethod =
                                    await _addPaymentMethod(name);
                                setState(() {
                                  allMethods.insert(
                                      allMethods.length - 1, newMethod);
                                  _showPopup = false;
                                  _newMethodController.clear();
                                });

                                Navigator.pop(context, newMethod);
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

  Widget _buildPaymentCard(BuildContext context, Map<String, String> method) {
    final bool isAddButton = method['name'] == '+';
    return GestureDetector(
      onTap: () {
        if (isAddButton) {
          setState(() => _showPopup = true);
        } else {
          Navigator.pop(context, method);
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
            method['name'] ?? '',
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
