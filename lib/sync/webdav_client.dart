import 'dart:async';
import 'dart:convert';
import 'dart:io';

class WebDavException implements Exception {
  WebDavException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class RemoteEntry {
  const RemoteEntry({required this.name, required this.modified});

  final String name;
  final DateTime? modified;
}

class WebDavClient {
  WebDavClient({
    required String baseUrl,
    required String username,
    required String password,
    this.timeout = const Duration(seconds: 25),
  })  : _base = Uri.parse(baseUrl.endsWith('/') ? baseUrl : '$baseUrl/'),
        _authorization =
            'Basic ${base64Encode(utf8.encode('$username:$password'))}';

  static const String _propfindBody =
      '<?xml version="1.0" encoding="utf-8"?>'
      '<d:propfind xmlns:d="DAV:">'
      '<d:prop><d:getlastmodified/><d:resourcetype/></d:prop>'
      '</d:propfind>';

  static final RegExp _responsePattern = RegExp(
    r'<(?:[A-Za-z0-9]+:)?response\b[^>]*>(.*?)</(?:[A-Za-z0-9]+:)?response>',
    dotAll: true,
  );
  static final RegExp _hrefPattern = RegExp(
    r'<(?:[A-Za-z0-9]+:)?href\b[^>]*>(.*?)</(?:[A-Za-z0-9]+:)?href>',
    dotAll: true,
  );
  static final RegExp _modifiedPattern = RegExp(
    r'<(?:[A-Za-z0-9]+:)?getlastmodified\b[^>]*>(.*?)</(?:[A-Za-z0-9]+:)?getlastmodified>',
    dotAll: true,
  );

  final Uri _base;
  final String _authorization;
  final Duration timeout;
  HttpClient? _client;

  HttpClient get _http =>
      _client ??= HttpClient()..connectionTimeout = timeout;

  void close() {
    _client?.close(force: true);
    _client = null;
  }

  Future<void> ensureFolder(String folder) async {
    final relative = _clean(folder);
    if (relative.isEmpty) {
      return;
    }

    final status = await _probe(relative);
    if (_isSuccess(status)) {
      return;
    }
    if (status != 404) {
      throw _statusError('открыть папку', relative, status);
    }

    var current = '';
    for (final segment in relative.split('/')) {
      current = current.isEmpty ? segment : '$current/$segment';
      final probe = await _probe(current);
      if (_isSuccess(probe)) {
        continue;
      }
      if (probe != 404) {
        throw _statusError('открыть папку', current, probe);
      }
      final response = await _request('MKCOL', current, depth: '');
      if (response.status != 201 && response.status != 200) {
        throw _statusError('создать папку', current, response.status);
      }
    }
  }

  Future<List<RemoteEntry>> list(String folder) async {
    final relative = _clean(folder);
    final response = await _request(
      'PROPFIND',
      relative,
      depth: '1',
      body: _propfindBody,
    );
    _ensureSuccess('получить список файлов', relative, response.status);
    return _parseEntries(response.body);
  }

  Future<DateTime?> modified(String folder, String name) async {
    final relative = _join(folder, name);
    final response = await _request(
      'PROPFIND',
      relative,
      depth: '0',
      body: _propfindBody,
    );
    if (response.status == 404) {
      return null;
    }
    _ensureSuccess('получить дату файла', relative, response.status);
    final entries = _parseEntries(response.body);
    return entries.isEmpty ? null : entries.first.modified;
  }

  Future<String> download(String folder, String name) async {
    final relative = _join(folder, name);
    final response = await _request('GET', relative, depth: '');
    _ensureSuccess('скачать файл', relative, response.status);
    return response.body;
  }

  Future<void> upload(String folder, String name, String content) async {
    final relative = _join(folder, name);
    final response = await _request(
      'PUT',
      relative,
      depth: '',
      body: content,
      contentType: 'text/markdown; charset=utf-8',
    );
    _ensureSuccess('загрузить файл', relative, response.status);
  }

  Future<void> delete(String folder, String name) async {
    final relative = _join(folder, name);
    final response = await _request('DELETE', relative, depth: '');
    if (response.status == 404) {
      return;
    }
    _ensureSuccess('удалить файл', relative, response.status);
  }

  Future<int> _probe(String relative) async {
    final response = await _request(
      'PROPFIND',
      relative,
      depth: '0',
      body: _propfindBody,
    );
    if (response.status == 401 || response.status == 403) {
      throw _statusError('войти на сервер', relative, response.status);
    }
    return response.status;
  }

  Future<_WebDavResponse> _request(
    String method,
    String relative, {
    required String depth,
    String? body,
    String? contentType,
  }) async {
    final uri = _resolve(relative);
    try {
      final request = await _http.openUrl(method, uri).timeout(timeout);
      request.headers.set(HttpHeaders.authorizationHeader, _authorization);
      if (depth.isNotEmpty) {
        request.headers.set('Depth', depth);
      }
      if (body != null) {
        final bytes = utf8.encode(body);
        request.headers.contentType =
            ContentType.parse(contentType ?? 'application/xml; charset=utf-8');
        request.contentLength = bytes.length;
        request.add(bytes);
      }
      final response = await request.close().timeout(timeout);
      final text = await response
          .transform(const Utf8Decoder(allowMalformed: true))
          .join()
          .timeout(timeout);
      return _WebDavResponse(response.statusCode, text);
    } on SocketException catch (error) {
      throw WebDavException('Нет соединения с сервером: ${error.message}');
    } on HandshakeException catch (error) {
      throw WebDavException('Ошибка TLS: ${error.message}');
    } on TimeoutException {
      throw WebDavException('Сервер не ответил вовремя');
    } on HttpException catch (error) {
      throw WebDavException('Ошибка HTTP: ${error.message}');
    }
  }

  Uri _resolve(String relative) {
    final encoded = relative
        .split('/')
        .where((segment) => segment.isNotEmpty)
        .map(Uri.encodeComponent)
        .join('/');
    return _base.resolve(encoded);
  }

  List<RemoteEntry> _parseEntries(String body) {
    final entries = <RemoteEntry>[];
    for (final match in _responsePattern.allMatches(body)) {
      final block = match.group(1) ?? '';
      final hrefMatch = _hrefPattern.firstMatch(block);
      if (hrefMatch == null) {
        continue;
      }
      final href = _decodeXml(hrefMatch.group(1)!.trim());
      final path = href.split('?').first;
      if (path.endsWith('/')) {
        continue;
      }
      final decoded = Uri.decodeComponent(path);
      final name = decoded.split('/').last;
      if (name.isEmpty) {
        continue;
      }
      final modifiedText = _modifiedPattern.firstMatch(block)?.group(1)?.trim();
      DateTime? modified;
      if (modifiedText != null && modifiedText.isNotEmpty) {
        try {
          modified = HttpDate.parse(modifiedText).toLocal();
        } catch (_) {
          modified = null;
        }
      }
      entries.add(RemoteEntry(name: name, modified: modified));
    }
    return entries;
  }

  void _ensureSuccess(String action, String relative, int status) {
    if (_isSuccess(status)) {
      return;
    }
    throw _statusError(action, relative, status);
  }

  WebDavException _statusError(String action, String relative, int status) {
    final message = switch (status) {
      401 || 403 => 'Неверный логин или пароль',
      404 => 'Не найдено: $relative',
      409 => 'Конфликт пути: $relative',
      507 => 'На сервере закончилось место',
      _ => 'Не удалось $action ($relative): код $status',
    };
    return WebDavException(message, statusCode: status);
  }

  static bool _isSuccess(int status) => status >= 200 && status < 300;

  static String _clean(String value) {
    final parts = value
        .split('/')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty);
    return parts.join('/');
  }

  static String _join(String folder, String name) {
    final cleaned = _clean(folder);
    return cleaned.isEmpty ? name : '$cleaned/$name';
  }

  static String _decodeXml(String value) {
    var result = value
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'")
        .replaceAll('&amp;', '&');
    result = result.replaceAllMapped(
      RegExp(r'&#(\d+);'),
      (match) => String.fromCharCode(int.parse(match.group(1)!)),
    );
    result = result.replaceAllMapped(
      RegExp(r'&#x([0-9a-fA-F]+);'),
      (match) => String.fromCharCode(int.parse(match.group(1)!, radix: 16)),
    );
    return result;
  }
}

class _WebDavResponse {
  const _WebDavResponse(this.status, this.body);

  final int status;
  final String body;
}

