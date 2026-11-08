import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:courtside_mobile/utils/app_locale.dart';
import 'package:courtside_mobile/utils/util.dart';

class _Screen extends StatelessWidget {
  final String name;

  const _Screen(this.name);

  @override
  Widget build(BuildContext context) => Scaffold(body: Center(child: Text(name)));
}

Future<NavigatorState> _pumpApp(WidgetTester tester) async {
  final navigator = GlobalKey<NavigatorState>();
  await tester.pumpWidget(
    ChangeNotifierProvider(
      create: (_) => LocaleProvider(),
      child: MaterialApp(
        navigatorKey: navigator,
        navigatorObservers: [ErrorSnackBarObserver()],
        home: const _Screen('A'),
      ),
    ),
  );
  return navigator.currentState!;
}

MaterialPageRoute<void> _route(String name) => MaterialPageRoute(builder: (_) => _Screen(name));

void main() {
  testWidgets('an error is closed when another screen opens over it', (tester) async {
    final navigator = await _pumpApp(tester);
    showError(tester.element(find.text('A')), 'Greška na A');
    await tester.pumpAndSettle();
    expect(find.text('Greška na A'), findsOneWidget);

    navigator.push(_route('B'));
    await tester.pumpAndSettle();

    expect(find.text('B'), findsOneWidget);
    expect(find.text('Greška na A'), findsNothing);
  });

  testWidgets('an error is closed when its screen is closed', (tester) async {
    final navigator = await _pumpApp(tester);
    navigator.push(_route('B'));
    await tester.pumpAndSettle();
    showError(tester.element(find.text('B')), 'Greška na B');
    await tester.pumpAndSettle();
    expect(find.text('Greška na B'), findsOneWidget);

    navigator.pop();
    await tester.pumpAndSettle();

    expect(find.text('A'), findsOneWidget);
    expect(find.text('Greška na B'), findsNothing);
  });

  testWidgets('a dialog over the screen leaves the error in place', (tester) async {
    final navigator = await _pumpApp(tester);
    final context = tester.element(find.text('A'));
    showError(context, 'Greška na A');
    await tester.pumpAndSettle();

    showDialog<void>(context: context, builder: (_) => const AlertDialog(content: Text('Dijalog')));
    await tester.pumpAndSettle();
    navigator.pop();
    await tester.pumpAndSettle();

    expect(find.text('Dijalog'), findsNothing);
    expect(find.text('Greška na A'), findsOneWidget);
  });

  testWidgets('an error shown right after navigating stays on the new screen until it is left',
      (tester) async {
    final navigator = await _pumpApp(tester);
    final context = tester.element(find.text('A'));

    navigator.pushReplacement(_route('B'));
    showError(context, 'Poruka za B');
    await tester.pumpAndSettle();

    expect(find.text('B'), findsOneWidget);
    expect(find.text('Poruka za B'), findsOneWidget);

    navigator.push(_route('C'));
    await tester.pumpAndSettle();

    expect(find.text('Poruka za B'), findsNothing);
  });

  testWidgets('a success message is not affected', (tester) async {
    final navigator = await _pumpApp(tester);
    showSuccess(tester.element(find.text('A')), 'Sačuvano');
    await tester.pump();

    navigator.push(_route('B'));
    await tester.pumpAndSettle();

    expect(find.text('B'), findsOneWidget);
    expect(find.text('Sačuvano'), findsOneWidget);
  });
}
