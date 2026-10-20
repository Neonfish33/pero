import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/pero_theme.dart';
import 'cloud_settings.dart';
import 'cloud_sync.dart';

class CloudSyncDialog extends StatefulWidget {
  const CloudSyncDialog({super.key});

  @override
  State<CloudSyncDialog> createState() => _CloudSyncDialogState();
}

class _CloudSyncDialogState extends State<CloudSyncDialog> {
  late final CloudSettings _settings;
  late final CloudSync _sync;
  late final TextEditingController _url;
  late final TextEditingController _login;
  late final TextEditingController _password;
  late final TextEditingController _folder;

  String? _status;
  List<String> _errors = const <String>[];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _settings = context.read<CloudSettings>();
    _sync = context.read<CloudSync>();
    _url = TextEditingController(text: _settings.url);
    _login = TextEditingController(text: _settings.login);
    _password = TextEditingController(text: _settings.password ?? '');
    _folder = TextEditingController(text: _settings.folder);
  }

  @override
  void dispose() {
    _url.dispose();
    _login.dispose();
    _password.dispose();
    _folder.dispose();
    super.dispose();
  }

  Future<bool> _persist() async {
    try {
      await _settings.save(
        url: _url.text,
        login: _login.text,
        folder: _folder.text,
        password: _password.text,
      );
      return true;
    } catch (error) {
      setState(() {
        _status = 'Проверьте настройки: $error';
      });
      return false;
    }
  }

  Future<void> _test() async {
    if (!await _persist()) {
      return;
    }
    setState(() {
      _busy = true;
      _errors = const <String>[];
      _status = 'Проверяю подключение…';
    });
    try {
      await _sync.testConnection();
      if (mounted) {
        setState(() => _status = 'Подключение работает');
      }
    } catch (error) {
      if (mounted) {
        setState(() => _status = 'Ошибка: $error');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _synchronize() async {
    if (!await _persist()) {
      return;
    }
    setState(() {
      _busy = true;
      _errors = const <String>[];
      _status = 'Синхронизация…';
    });
    try {
      final report = await _sync.synchronize();
      if (mounted) {
        setState(() {
          _status = 'Готово: ${report.describe()}';
          _errors = List<String>.unmodifiable(report.errors);
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _status = 'Ошибка синхронизации: $error');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<PeroPalette>();
    final accent = palette?.accent ?? Theme.of(context).colorScheme.primary;
    return AlertDialog(
      title: const Text('Облако (WebDAV)'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _settings.persistsSecrets
                    ? 'Подходит для Яндекс.Диска, Nextcloud, ownCloud и других '
                        'WebDAV-серверов. Пароль шифруется средствами Windows '
                        'и хранится только для вашей учётной записи.'
                    : 'Подходит для Яндекс.Диска, Nextcloud, ownCloud и других '
                        'WebDAV-серверов. На этой платформе пароль хранится '
                        'только до закрытия приложения.',
                style: const TextStyle(fontSize: 12.5),
              ),
              const SizedBox(height: 14),
              _field(
                controller: _url,
                label: 'Адрес сервера',
                hint: 'https://webdav.yandex.ru',
              ),
              const SizedBox(height: 10),
              _field(controller: _login, label: 'Логин'),
              const SizedBox(height: 10),
              _field(
                controller: _password,
                label: 'Пароль приложения',
                obscure: true,
              ),
              const SizedBox(height: 10),
              _field(
                controller: _folder,
                label: 'Папка в облаке',
                hint: 'pero',
              ),
              if (_status != null) ...[
                const SizedBox(height: 14),
                Text(
                  _status!,
                  style: TextStyle(fontSize: 12.5, color: palette?.ui),
                ),
              ],
              if (_errors.isNotEmpty) ...[
                const SizedBox(height: 8),
                for (final error in _errors.take(5))
                  Text(
                    '• $error',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                if (_errors.length > 5)
                  Text(
                    '…и ещё ${_errors.length - 5}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
              ],
              if (_busy) ...[
                const SizedBox(height: 14),
                LinearProgressIndicator(color: accent),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Закрыть'),
        ),
        TextButton(
          onPressed: _busy ? null : _test,
          child: const Text('Проверить'),
        ),
        FilledButton(
          onPressed: _busy ? null : _synchronize,
          child: const Text('Синхронизировать'),
        ),
      ],
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    String? hint,
    bool obscure = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      enabled: !_busy,
      style: const TextStyle(fontFamily: kSansFamily, fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        isDense: true,
        border: const OutlineInputBorder(),
      ),
    );
  }
}
