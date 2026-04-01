import 'package:flutter/material.dart';
import 'screens/welcome_screen.dart';
import 'services/sms_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SmsService.instance.init(
    onTransaction: (tx) {
      debugPrint("💰 Transaction: $tx");
    },
    onStatus: (status) {
      debugPrint(status);
    },
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Email Verification App',
      theme: ThemeData(primarySwatch: Colors.green),
      home: const WelcomeScreen(),
    );
  }
}