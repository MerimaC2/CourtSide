import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:courtside_mobile/main.dart';
import 'package:courtside_mobile/providers/auth_provider.dart';
import 'package:courtside_mobile/providers/city_provider.dart';
import 'package:courtside_mobile/providers/court_provider.dart';
import 'package:courtside_mobile/providers/sport_provider.dart';

void main() {
  testWidgets('Login screen renders', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => CourtProvider()),
          ChangeNotifierProvider(create: (_) => SportProvider()),
          ChangeNotifierProvider(create: (_) => CityProvider()),
        ],
        child: const CourtSideApp(),
      ),
    );

    expect(find.text('CourtSide'), findsWidgets);
    expect(find.text('Prijava'), findsWidgets);
  });
}
