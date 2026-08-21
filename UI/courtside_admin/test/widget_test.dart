import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:courtside_admin/main.dart';
import 'package:courtside_admin/providers/auth_provider.dart';
import 'package:courtside_admin/providers/city_provider.dart';
import 'package:courtside_admin/providers/court_provider.dart';
import 'package:courtside_admin/providers/sport_center_provider.dart';
import 'package:courtside_admin/providers/sport_provider.dart';
import 'package:courtside_admin/utils/app_locale.dart';

void main() {
  testWidgets('App renders', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => LocaleProvider()),
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => CourtProvider()),
          ChangeNotifierProvider(create: (_) => SportProvider()),
          ChangeNotifierProvider(create: (_) => CityProvider()),
          ChangeNotifierProvider(create: (_) => SportCenterProvider()),
        ],
        child: const CourtSideAdminApp(),
      ),
    );

    expect(find.text('CourtSide Admin'), findsWidgets);
    expect(find.text('Prijava'), findsWidgets);
  });
}
