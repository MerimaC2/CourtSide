import 'package:flutter_test/flutter_test.dart';

import 'package:courtside_admin/providers/auth_provider.dart';
import 'package:courtside_admin/utils/authorization.dart';

void main() {
  tearDown(Authorization.clear);

  // The test binding answers every HTTP request with 400, which stands in for a server
  // that refuses the logout.
  testWidgets('a logout the server does not confirm is reported, and the local session still ends',
      (WidgetTester tester) async {
    Authorization.token = 'token';
    Authorization.username = 'admin';

    final confirmed = await AuthProvider().signOut();

    expect(confirmed, isFalse);
    expect(Authorization.token, isNull);
    expect(Authorization.username, isNull);
  });

  testWidgets('without a session there is nothing for the server to confirm',
      (WidgetTester tester) async {
    expect(await AuthProvider().signOut(), isTrue);
  });
}
