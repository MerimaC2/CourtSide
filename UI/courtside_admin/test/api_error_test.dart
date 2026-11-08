import 'dart:async';
import 'dart:io';

import 'package:courtside_admin/providers/api_error.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';

void main() {
  const unreachable = 'Server trenutno nije dostupan. Pokušajte ponovo za nekoliko trenutaka.';

  test('an unreachable server is described in plain words', () {
    expect(describeError(ClientException('Connection closed before full header was received')), unreachable);
    expect(describeError(const SocketException('Connection refused')), unreachable);
    expect(describeError(TimeoutException('no answer')), unreachable);
  });

  test('any other error keeps its own message', () {
    expect(describeError(Exception('Pogrešno korisničko ime ili lozinka.')), 'Pogrešno korisničko ime ili lozinka.');
  });
}
