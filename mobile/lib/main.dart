import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dijital_dolap/providers/auth_provider.dart';
import 'package:dijital_dolap/providers/clothing_provider.dart';
import 'package:dijital_dolap/screens/home_screen.dart';
import 'package:dijital_dolap/screens/login_screen.dart';
import 'package:dijital_dolap/theme/app_theme.dart';

void main() {
  runApp(const DijitalDolapApp());
}

class DijitalDolapApp extends StatelessWidget {
  const DijitalDolapApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..bootstrap()),
        ChangeNotifierProvider(create: (_) => ClothingProvider()),
      ],
      child: MaterialApp(
        title: 'Dijital Dolap',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const _RootGate(),
      ),
    );
  }
}

class _RootGate extends StatelessWidget {
  const _RootGate();

  @override
  Widget build(BuildContext context) {
    final status = context.watch<AuthProvider>().status;

    switch (status) {
      case AuthStatus.unknown:
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      case AuthStatus.authenticated:
        return const HomeScreen();
      case AuthStatus.unauthenticated:
        return const LoginScreen();
    }
  }
}