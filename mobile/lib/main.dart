import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:provider/provider.dart';
import 'package:dijital_dolap/data/api_client.dart';
import 'package:dijital_dolap/providers/auth_provider.dart';
import 'package:dijital_dolap/providers/clothing_provider.dart';
import 'package:dijital_dolap/providers/occasion_provider.dart';
import 'package:dijital_dolap/providers/outfit_provider.dart';
import 'package:dijital_dolap/providers/wear_provider.dart';
import 'package:dijital_dolap/providers/weather_provider.dart';
import 'package:dijital_dolap/providers/calendar_provider.dart';
import 'package:dijital_dolap/screens/home_screen.dart';
import 'package:dijital_dolap/screens/login_screen.dart';
import 'package:dijital_dolap/theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Web'de otomatik erişilebilirlik desteği: ekran okuyuculara semantik ağaç
  // sunulur. Diğer platformlarda etkisizdir (ağaç zaten mevcut).
  if (kIsWeb) {
    SemanticsBinding.instance.ensureSemantics();
  }
  runApp(const DijitalDolapApp());
}

class DijitalDolapApp extends StatefulWidget {
  const DijitalDolapApp({super.key});

  @override
  State<DijitalDolapApp> createState() => _DijitalDolapAppState();
}

class _DijitalDolapAppState extends State<DijitalDolapApp> {
  late final AuthProvider _auth;
  late final ClothingProvider _clothing;
  late final OutfitProvider _outfits;
  late final WearProvider _wear;
  late final OccasionProvider _occasions;
  late final WeatherProvider _weather;
  late final CalendarProvider _calendar;

  @override
  void initState() {
    super.initState();
    _auth = AuthProvider();
    _clothing = ClothingProvider();
    _outfits = OutfitProvider();
    _wear = WearProvider();
    _occasions = OccasionProvider();
    _weather = WeatherProvider();
    _calendar = CalendarProvider();

    // Token süresi dolunca (401) oturumu ve önceki hesabın verisini temizle.
    ApiClient.instance.onUnauthorized = _handleUnauthorized;
    _auth.bootstrap();
  }

  void _handleUnauthorized() {
    if (_auth.status != AuthStatus.authenticated) return;
    _clothing.clear();
    _outfits.clear();
    _wear.clear();
    _occasions.clear();
    _weather.clearCity();
    _calendar.clear();
    _auth.logout();
  }

  @override
  void dispose() {
    ApiClient.instance.onUnauthorized = null;
    _auth.dispose();
    _clothing.dispose();
    _outfits.dispose();
    _wear.dispose();
    _occasions.dispose();
    _weather.dispose();
    _calendar.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _auth),
        ChangeNotifierProvider.value(value: _clothing),
        ChangeNotifierProvider.value(value: _outfits),
        ChangeNotifierProvider.value(value: _wear),
        ChangeNotifierProvider.value(value: _occasions),
        ChangeNotifierProvider.value(value: _weather),
        ChangeNotifierProvider.value(value: _calendar),
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
