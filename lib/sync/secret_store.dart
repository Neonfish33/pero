import 'dart:convert';
import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:win32/win32.dart';

const int _cryptProtectUiForbidden = 0x1;

abstract class SecretStore {
  bool get persistsSecrets;

  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);
}

Future<SecretStore> createSecretStore(SharedPreferences preferences) async {
  if (defaultTargetPlatform == TargetPlatform.windows) {
    return WindowsSecretStore(preferences);
  }
  return MemorySecretStore();
}

class MemorySecretStore implements SecretStore {
  final Map<String, String> _values = <String, String>{};

  @override
  bool get persistsSecrets => false;

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async {
    _values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _values.remove(key);
  }
}

class WindowsSecretStore implements SecretStore {
  WindowsSecretStore(this._preferences);

  static const String _prefix = 'pero.secret.';

  final SharedPreferences _preferences;

  @override
  bool get persistsSecrets => true;

  @override
  Future<String?> read(String key) async {
    final encoded = _preferences.getString('$_prefix$key');
    if (encoded == null || encoded.isEmpty) {
      return null;
    }
    try {
      return utf8.decode(_unprotect(base64Decode(encoded)));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(String key, String value) async {
    final encrypted = _protect(utf8.encode(value));
    await _preferences.setString('$_prefix$key', base64Encode(encrypted));
  }

  @override
  Future<void> delete(String key) async {
    await _preferences.remove('$_prefix$key');
  }

  Uint8List _protect(List<int> data) {
    final input = calloc<Uint8>(data.isEmpty ? 1 : data.length);
    final inputBlob = calloc<CRYPT_INTEGER_BLOB>();
    final outputBlob = calloc<CRYPT_INTEGER_BLOB>();
    try {
      input.asTypedList(data.length).setAll(0, data);
      inputBlob.ref
        ..cbData = data.length
        ..pbData = input;

      final result = CryptProtectData(
        inputBlob,
        null,
        null,
        null,
        _cryptProtectUiForbidden,
        outputBlob,
      );
      if (!result.value) {
        throw StateError('CryptProtectData: ${result.error}');
      }

      final length = outputBlob.ref.cbData;
      final encrypted = Uint8List.fromList(
        outputBlob.ref.pbData.asTypedList(length),
      );
      HLOCAL(outputBlob.ref.pbData).close();
      outputBlob.ref.pbData = nullptr;
      return encrypted;
    } finally {
      calloc.free(input);
      calloc.free(inputBlob);
      calloc.free(outputBlob);
    }
  }

  Uint8List _unprotect(List<int> data) {
    final input = calloc<Uint8>(data.isEmpty ? 1 : data.length);
    final inputBlob = calloc<CRYPT_INTEGER_BLOB>();
    final outputBlob = calloc<CRYPT_INTEGER_BLOB>();
    try {
      input.asTypedList(data.length).setAll(0, data);
      inputBlob.ref
        ..cbData = data.length
        ..pbData = input;

      final result = CryptUnprotectData(
        inputBlob,
        null,
        null,
        null,
        _cryptProtectUiForbidden,
        outputBlob,
      );
      if (!result.value) {
        throw StateError('CryptUnprotectData: ${result.error}');
      }

      final length = outputBlob.ref.cbData;
      final decrypted = Uint8List.fromList(
        outputBlob.ref.pbData.asTypedList(length),
      );
      HLOCAL(outputBlob.ref.pbData).close();
      outputBlob.ref.pbData = nullptr;
      return decrypted;
    } finally {
      calloc.free(input);
      calloc.free(inputBlob);
      calloc.free(outputBlob);
    }
  }
}
