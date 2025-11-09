import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> initializeGlobalCategories() async {
  final firestore = FirebaseFirestore.instance;
  final categoriesCollection = firestore.collection('categories');

  final categories = [
    {
      "name": "Other",
      "subcategories": [
        "Miscellaneous",
        "Service Charges",
        "Unexpected Expenses",
        "Repairs & Maintenance",
        "Stationery",
        "Lost Items",
        "Fines & Penalties",
      ]
    },
    {
      "name": "Food",
      "subcategories": [
        "Groceries",
        "Restaurants",
        "Cafes",
        "Snacks",
        "Beverages",
        "Takeaway / Delivery",
        "Street Food",
      ]
    },
    {
      "name": "Shopping",
      "subcategories": [
        "Clothing",
        "Footwear",
        "Accessories",
        "Electronics & Gadgets",
        "Home Decor",
        "Furniture",
        "Online Shopping",
      ]
    },
    {
      "name": "Travelling",
      "subcategories": [
        "Fuel / Gas",
        "Public Transport",
        "Cab / Taxi",
        "Flight Tickets",
        "Hotel / Accommodation",
        "Parking Fees",
        "Toll Charges",
      ]
    },
    {
      "name": "Entertainment",
      "subcategories": [
        "Movies / Shows",
        "Subscriptions (Netflix, Spotify, etc.)",
        "Events / Concerts",
        "Games / Apps",
        "Hobbies",
        "Outdoor Activities",
      ]
    },
    {
      "name": "Medical",
      "subcategories": [
        "Medicines",
        "Doctor Consultation",
        "Health Checkup",
        "Hospitalization",
        "Insurance Premiums",
        "Dental Care",
        "Vision / Eye Care",
      ]
    },
    {
      "name": "Personal Care",
      "subcategories": [
        "Salon / Spa",
        "Cosmetics / Beauty",
        "Fitness / Gym",
        "Skincare Products",
        "Personal Hygiene",
        "Grooming Supplies",
      ]
    },
    {
      "name": "Education",
      "subcategories": [
        "Tuition Fees",
        "Books & Supplies",
        "Online Courses",
        "Coaching / Training",
        "Exam Fees",
        "Stationery",
        "School / College Fees",
      ]
    },
    {
      "name": "Bills & Utilities",
      "subcategories": [
        "Electricity",
        "Water",
        "Internet / Wi-Fi",
        "Mobile / Phone",
        "Gas",
        "TV / Cable",
        "Maintenance Charges",
      ]
    },
    {
      "name": "Investment",
      "subcategories": [
        "Stocks / Shares",
        "Mutual Funds",
        "Fixed Deposits",
        "Cryptocurrency",
        "Real Estate",
        "Bonds",
        "SIP Contributions",
      ]
    },
    {
      "name": "Rent",
      "subcategories": [
        "House Rent",
        "Office / Workspace Rent",
        "Storage / Garage Rent",
        "Equipment Lease",
      ]
    },
    {
      "name": "Taxes",
      "subcategories": [
        "Income Tax",
        "Property Tax",
        "GST / Sales Tax",
        "Vehicle Tax",
        "Professional Tax",
      ]
    },
    {
      "name": "Gifts & Donations",
      "subcategories": [
        "Family Gifts",
        "Friend Gifts",
        "Charity Donations",
        "Religious Offerings",
        "Wedding / Festival Gifts",
      ]
    },
  ];

  print('⏳ Initializing global categories...');

  for (int i = 0; i < categories.length; i++) {
    final cat = categories[i];
    final categoryId = 'C${i + 1}';

    // Create structured subcategory list with IDs like SC1, SC2, ...
    final subcats = (cat['subcategories'] as List)
        .asMap()
        .entries
        .map((entry) => {
              'id': 'SC${entry.key + 1}',
              'name': entry.value,
            })
        .toList();

    await categoriesCollection.doc(categoryId).set({
      'id': categoryId,
      'name': cat['name'],
      'subcategories': subcats,
      'createdAt': FieldValue.serverTimestamp(),
    });

    print('✅ Added ${cat['name']} → $categoryId with ${subcats.length} subcategories');
  }

  print('🎉 Global categories initialized successfully!');
}
