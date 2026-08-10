import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/auth_provider.dart';
import 'providers/availability_block_provider.dart';
import 'providers/availability_provider.dart';
import 'providers/city_provider.dart';
import 'providers/court_provider.dart';
import 'providers/reservation_provider.dart';
import 'providers/sport_center_provider.dart';
import 'providers/sport_provider.dart';
import 'screens/auth/login_screen.dart';
import 'utils/app_navigator.dart';
import 'utils/util.dart';

void main() {
  onUnauthorized = () {
    appNavigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  };
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => CourtProvider()),
        ChangeNotifierProvider(create: (_) => SportProvider()),
        ChangeNotifierProvider(create: (_) => CityProvider()),
        ChangeNotifierProvider(create: (_) => SportCenterProvider()),
        ChangeNotifierProvider(create: (_) => AvailabilityProvider()),
        ChangeNotifierProvider(create: (_) => AvailabilityBlockProvider()),
        ChangeNotifierProvider(create: (_) => ReservationProvider()),
      ],
      child: const CourtSideAdminApp(),
    ),
  );
}

class CourtSideAdminApp extends StatelessWidget {
  const CourtSideAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CourtSide Admin',
      debugShowCheckedModeBanner: false,
      navigatorKey: appNavigatorKey,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: kPrimaryColor),
        useMaterial3: true,
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey.shade50,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: kPrimaryColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(vertical: 14),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
      ),
      home: const LoginScreen(),
    );
  }
}
