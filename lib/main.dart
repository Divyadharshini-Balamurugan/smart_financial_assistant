import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart'; 
import 'screens/splash_screen.dart';
import 'firebase_options.dart';
// import 'services/global_category_setup.dart';
// import 'services/payment_method_setup.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // await initializeGlobalCategories();
  // await initializePaymentMethods();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Smart Financial Assistant',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}
