import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'secret_store.dart';
import 'webdav_client.dart';

class CloudSettings extends ChangeNotifier {
  CloudSettings(this._prefs, this._store);

  static const String _urlKey = 'pero.cloud.url';
  static const String _loginKey = 'pero.cloud.login';
  static const String _folderKey = 'pero.cloud.folder';
  static const String _passwordKey = 'pero.cloud.password';

  final SharedPreferences _prefs;
  final SecretStore _store;

  String url = '';
  String login = '';
  String folder = 'pero';
  String? _password;

  String? get password => _password;

  bool get hasPassword => _password != null && _password!.isNotEmpty;

  bool get persistsSecrets => _store.persistsSecrets;

  bool get isConfigured =>
      url.trim().isNotEmpty && login.trim().isNotEmpty && hasPassword;

  static Future<CloudSettings> load(SharedPreferences preferences) async {
    final store = await createSecretStore(preferences);
    final settings = CloudSettings(preferences, store);
    settings.url = preferences.getString(_urlKey) ?? '';
    settings.login = preferences.getString(_loginKey) ?? '';
    settings.folder = preferences.getString(_folderKey) ?? 'pero';
    settings._password = await store.read(_passwordKey);
    return settings;
  }

  Future<void> save({
    required String url,
    required String login,
    required String folder,
    String? password,
  }) async {
    final normalizedUrl = normalizeBaseUrl(url);
    final cleanedFolder = folder.trim().replaceAll(RegExp(r'^/+|/+$'), '');
    this.url = normalizedUrl;
    this.login = login.trim();
    this.folder = cleanedFolder.isEmpty ? 'pero' : cleanedFolder;
    if (password != null && password.isNotEmpty) {
      _password = password;
      await _store.write(_passwordKey, password);
    }
    await _prefs.setString(_urlKey, this.url);
    await _prefs.setString(_loginKey, this.login);
    await _prefs.setString(_folderKey, this.folder);
    notifyListeners();
  }

  Future<void> clearPassword() async {
    _password = null;
    try {
      await _store.delete(_passwordKey);
    } catch (_) {
      // The in-memory value is cleared anyway.
    }
    notifyListeners();
  }

  WebDavClient createClient() {
    if (!isConfigured) {
      throw WebDavException('Заполните адрес, логин и пароль');
    }
    return WebDavClient(
      baseUrl: normalizeBaseUrl(url),
      username: login.trim(),
      password: _password!,
    );
  }

  static String normalizeBaseUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('Укажите адрес WebDAV-сервера');
    }
    final uri = Uri.tryParse(trimmed);
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty) {
      throw const FormatException(
        'Адрес должен начинаться с http:// или https://',
      );
    }
    return trimmed.replaceAll(RegExp(r'/+$'), '');
  }
}
