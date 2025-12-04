import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> initializeGlobalIncomeCategories() async {
  final firestore = FirebaseFirestore.instance;
  final incomeCollection = firestore.collection('income_categories');

  final incomeCategories = [
    {
      "name": "Salary and Stipend",
      "subcategories": [
        "Basic Salary",
        "Bonus",
        "Overtime",
        "Allowances",
        "Reimbursements",
      ]
    },
    {
      "name": "Business and Freelance",
      "subcategories": [
        "Project Payments",
        "Retainer Payments",
        "Consulting Fees",
        "Freelance Payments",
        "Invoice Payments",
      ]
    },
    {
      "name": "Allowance",
      "subcategories": [
        "Monthly Allowance",
        "Pocket Money",
        "Family Support",
      ]
    },
    {
      "name": "Scholarship and Grant",
      "subcategories": [
        "Merit Scholarship",
        "Research Grant",
        "Fellowship Stipend",
        "Travel Grant",
      ]
    },
    {
      "name": "Investment Income",
      "subcategories": [
        "Interest Earnings",
        "Dividends",
        "Capital Gains",
        "Mutual Fund Returns",
        "Crypto Gains",
        "Bond Interest",
      ]
    },
    {
      "name": "Rental Income",
      "subcategories": [
        "House Rent",
        "Commercial Property Rent",
        "Short Term Rental",
        "Parking Rent",
      ]
    },
    {
      "name": "Refunds and Cashback",
      "subcategories": [
        "Bank Refund",
        "Shopping Refund",
        "Payment Refund",
        "Cashback",
        "Reward Income",
      ]
    },
    {
      "name": "Gifts Received",
      "subcategories": [
        "Family Gift",
        "Friend Gift",
        "Event Gift",
      ]
    },
    {
      "name": "Other Income",
      "subcategories": [
        "Prize Money",
        "One Time Income",
        "Miscellaneous Income",
      ]
    },
  ];

  print('⏳ Initializing global income categories...');

  for (int i = 0; i < incomeCategories.length; i++) {
    final cat = incomeCategories[i];
    final categoryId = 'IC${i + 1}';

    final subcats = (cat['subcategories'] as List)
        .asMap()
        .entries
        .map((entry) => {
              'id': 'ISC${entry.key + 1}',
              'name': entry.value,
            })
        .toList();

    await incomeCollection.doc(categoryId).set({
      'id': categoryId,
      'name': cat['name'],
      'subcategories': subcats,
      'createdAt': FieldValue.serverTimestamp(),
    });

    print('✅ Added ${cat['name']} → $categoryId with ${subcats.length} subcategories');
  }

  print('🎉 Global income categories initialized successfully!');
}
