import 'package:another_telephony/telephony.dart';
import 'package:flutter/material.dart';

// 1. TOP-LEVEL BACKGROUND HANDLER
// This must be outside the class to work when the app is in the background.
@pragma('vm:entry-point')
Future<void> backgroundMessageHandler(SmsMessage message) async {
  // Logic to handle message when app is closed (optional for UI updates)
  debugPrint("Background SMS: ${message.body}");
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final Telephony telephony = Telephony.instance;

  // Variables to hold the data
  String _amount = "0.00";
  String _sender = "No Data";
  String _status = "Waiting for Bank SMS...";

  @override
  void initState() {
    super.initState();
    _initSmsListener();
  }

  // 2. INITIALIZE LISTENER
  void _initSmsListener() async {
    // Request permissions
    bool? permissionsGranted = await telephony.requestPhoneAndSmsPermissions;

    if (permissionsGranted != true) {
      setState(() => _status = "SMS Permission Denied");
      return;
    }

    // Start Listening
    telephony.listenIncomingSms(
      onNewMessage: (SmsMessage message) {
        // This runs when the app is OPEN
        _processMessage(message);
      },
      onBackgroundMessage: backgroundMessageHandler,
    );
  }

  // 3. LOGIC TO EXTRACT DATA
    void _processMessage(SmsMessage message) {
    String body = message.body ?? "";
    String sender = message.address ?? "Unknown";

    // 1. Check if sender is a bank (Alphanumeric sender IDs usually)
    bool isBank = !RegExp(r'^\+?[0-9]+$').hasMatch(sender);

    if (isBank) {
      // 2. Updated Regex to be slightly more flexible regarding spaces and decimals
      // Matches: "A/C X1234 debited by 500.00 on date..."
      RegExp amountRegex = RegExp(
        r"A/C\s+X(\d{4})\s+(debited|credited)\s+by\s+(\d+(?:\.\d{1,2})?)\s+on",
        caseSensitive: false,
      );
      
      Match? match = amountRegex.firstMatch(body);

      if (match != null) {
        // Group 1: Account Digits
        // Group 2: debited/credited
        // Group 3: AMOUNT
        String type = match.group(2) ?? "Transaction";
        String extractedAmount = match.group(3) ?? "0";
        
        setState(() {
          _status = "$type detected!";
          _sender = sender;
          _amount = extractedAmount;
        });
      } else {
        debugPrint("Bank SMS detected but format didn't match.");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Dashboard")),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "Welcome to your Dashboard!",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 30),
              
              // Status Indicator
              Text(
                _status,
                style: TextStyle(color: Colors.grey[600], fontStyle: FontStyle.italic),
              ),
              const SizedBox(height: 20),

              // TRANSACTION CARD
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  children: [
                    const Text("Last Transaction", style: TextStyle(color: Colors.blueGrey)),
                    const SizedBox(height: 10),
                    Text(
                      _amount,
                      style: const TextStyle(
                        fontSize: 40, 
                        fontWeight: FontWeight.bold, 
                        color: Colors.blueAccent
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.account_balance, size: 16, color: Colors.grey),
                        const SizedBox(width: 5),
                        Text("Bank: $_sender", style: const TextStyle(fontWeight: FontWeight.w500)),
                      ],
                    )
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}