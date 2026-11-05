import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart';
import 'screens/google_sign_in_screen.dart';
import 'screens/home_screen.dart';
import 'services/app_auth_service.dart';
import 'services/expense_repository.dart';
import 'services/firebase_app_auth_service.dart';
import 'services/firestore_expense_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    runApp(const MyApp());
  } catch (error, stackTrace) {
    debugPrint('Firebase initialization failed: $error\n$stackTrace');
    runApp(FirebaseInitializationErrorApp(error: error));
  }
}

class MyApp extends StatelessWidget {
  const MyApp({
    super.key,
    this.authService,
    this.expenseRepository,
  });

  final AppAuthService? authService;
  final ExpenseRepository? expenseRepository;

  @override
  Widget build(BuildContext context) {
    final auth = authService ?? FirebaseAppAuthService();
    final expenses = expenseRepository ?? FirestoreExpenseRepository();

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Expensio',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2878E8),
          brightness: Brightness.light,
          surface: const Color(0xFFF9FCFF),
        ),
        scaffoldBackgroundColor: const Color(0xFFEAF3FF),
        useMaterial3: true,
      ),
      home: AuthGate(authService: auth, expenseRepository: expenses),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({
    required this.authService,
    required this.expenseRepository,
    super.key,
  });

  final AppAuthService authService;
  final ExpenseRepository expenseRepository;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<String?>(
      stream: authService.userIdChanges,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const _AuthErrorScreen();
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final userId = snapshot.data;
        if (userId == null) {
          return GoogleSignInScreen(authService: authService);
        }
        return HomeScreen(
          userId: userId,
          authService: authService,
          expenseRepository: expenseRepository,
        );
      },
    );
  }
}

class _AuthErrorScreen extends StatelessWidget {
  const _AuthErrorScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Could not check your sign-in status. Please restart the app.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

class FirebaseInitializationErrorApp extends StatelessWidget {
  const FirebaseInitializationErrorApp({required this.error, super.key});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Firebase could not start. Check your Firebase configuration '
              'and try again.\n\n$error',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
