import 'package:flutter_test/flutter_test.dart';
import 'package:pero/sync/secret_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('WindowsSecretStore encrypts the password with DPAPI', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final preferences = await SharedPreferences.getInstance();
    final store = WindowsSecretStore(preferences);

    expect(store.persistsSecrets, isTrue);
    expect(await store.read('cloud'), isNull);

    await store.write('cloud', 'app-password-123');
    expect(await store.read('cloud'), 'app-password-123');

    final stored = preferences.getString('pero.secret.cloud');
    expect(stored, isNotNull);
    expect(stored, isNot(contains('app-password-123')));

    await store.delete('cloud');
    expect(await store.read('cloud'), isNull);
    expect(preferences.getString('pero.secret.cloud'), isNull);
  });
}
