import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/finance_provider.dart';
import 'providers/auth_provider.dart';
import 'screens/welcome_screen.dart';
import 'screens/main_shell.dart';
import 'services/sms_classifier.dart';
import 'services/sms_pipeline.dart';
import 'services/sms_sync_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load telecom keyword list from asset before the first SMS arrives.
  await SmsClassifier.loadKeywords();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => FinanceProvider()),
        ChangeNotifierProvider(
          create: (context) {
            // Wire the pipeline callback before start() so no SMS is dropped
            // during the startup window. The FinanceProvider is already in the
            // tree at this point because it is declared first.
            SmsPipeline.instance.onTransaction =
                context.read<FinanceProvider>().prependSmsTransaction;

            // Auto-create accounts when a new bank account number is detected.
            SmsPipeline.instance.onAccountDetected =
                context.read<FinanceProvider>().ensureAccountExists;

            // Wire SmsSyncService callback alongside SmsPipeline so historical
            // inbox transactions are also reflected in the UI immediately.
            SmsSyncService.instance.onTransaction =
                context.read<FinanceProvider>().prependSmsTransaction;

            // Auto-create accounts from historical inbox sync as well.
            SmsSyncService.instance.onAccountDetected =
                context.read<FinanceProvider>().ensureAccountExists;

            // Start listening only after the callback is registered.
            SmsPipeline.instance.start();

            return AuthProvider()..restoreSession();
          },
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SmartFin',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFFF4F6F9),
      ),
      home: const AuthWrapper(),
    );
  }
}

/// Listens to [AuthProvider] and routes to the correct root screen.
///
/// Fix #1 — splash screen during session restore prevents welcome-screen flash.
/// Fix #2 — on auth success the entire navigator stack is cleared so auth
///           screens (signup / login / OTP) can never be popped back to.
/// Fix #12 — loadAll() is guarded by a flag so it only fires once per
///            authentication event, not on every rebuild.
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> with WidgetsBindingObserver {
  bool _wasAuthenticated = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SmsSyncService.instance.autoSync(); // fire-and-forget
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      SmsSyncService.instance.autoSync(); // fire-and-forget
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    // Fix #1: show a neutral splash while the secure-storage read is in flight.
    if (auth.isRestoring) {
      return const Scaffold(
        backgroundColor: Color(0xFFF4F6F9),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final isAuthenticated = auth.isAuthenticated;
    final finance = context.read<FinanceProvider>();

    // Fix: loadAll() must NOT be called synchronously inside build() because
    // it immediately calls notifyListeners() (to set loading state), which
    // triggers a rebuild while the current frame is still executing.
    // addPostFrameCallback defers the call until after the frame completes.
    if (isAuthenticated && !_wasAuthenticated) {
      _wasAuthenticated = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) finance.loadAll(userId: auth.userId);
      });
    }

    if (!isAuthenticated && _wasAuthenticated) {
      _wasAuthenticated = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) finance.clear();
      });
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: isAuthenticated
          ? const MainShell(key: ValueKey('shell'))
          : const SmartFinScreen(key: ValueKey('welcome')),
    );
  }
}
