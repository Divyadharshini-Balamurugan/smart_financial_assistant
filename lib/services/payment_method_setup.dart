import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> initializePaymentMethods() async {
  final firestore = FirebaseFirestore.instance;
  final paymentMethodsCollection = firestore.collection('payment_methods');

  final methods = [
    'Cash',
    'UPI',
    'Credit Card',
    'Debit Card',
    'Net Banking',
    'Wallet',
    'Cheque',
    'Others',
  ];

  int counter = 1;

  for (final method in methods) {
    final methodId = 'pm${counter.toString().padLeft(2, '0')}'; // pm01, pm02...
    await paymentMethodsCollection.doc(methodId).set({
      'id': methodId,
      'name': method,
      'createdAt': FieldValue.serverTimestamp(),
    });
    print('Added $method with ID: $methodId');
    counter++;
  }

  print('✅ Global payment methods added successfully!');
}
