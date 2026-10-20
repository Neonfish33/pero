import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pero/sync/webdav_client.dart';

class _FakeDavServer {
  _FakeDavServer(this.server) {
    server.listen(handle);
  }

  final HttpServer server;
  final Map<String, String> files = <String, String>{};
  final Set<String> folders = <String>{};
  DateTime modified = DateTime.utc(2026, 5, 6, 7, 8, 9);

  String get baseUrl => 'http://127.0.0.1:${server.port}/dav';

  void handle(HttpRequest request) {
    final expected = 'Basic ${base64Encode(utf8.encode('user:secret'))}';
    if (request.headers.value(HttpHeaders.authorizationHeader) != expected) {
      request.response.statusCode = HttpStatus.unauthorized;
      request.response.close();
      return;
    }

    final path = Uri.decodeComponent(request.uri.path);
    final relative = path.startsWith('/dav/') ? path.substring(5) : '';
    final segments = relative
        .split('/')
        .where((segment) => segment.isNotEmpty)
        .toList();

    switch (request.method) {
      case 'PROPFIND':
        final depth = request.headers.value('Depth') ?? '0';
        final exists = segments.isEmpty ||
            folders.contains(relative) ||
            files.containsKey(relative);
        if (!exists) {
          request.response.statusCode = HttpStatus.notFound;
          request.response.close();
          return;
        }
        final entries = <String>[];
        if (segments.isEmpty) {
          for (final folder in folders) {
            entries.add(entry(folder, isFolder: true));
          }
          if (depth == '1') {
            for (final file in files.keys) {
              if (!file.contains('/')) {
                entries.add(entry(file));
              }
            }
          }
        } else if (files.containsKey(relative)) {
          entries.add(entry(relative));
        } else if (depth == '1') {
          for (final file in files.keys) {
            if (file.startsWith('$relative/') &&
                !file.substring(relative.length + 1).contains('/')) {
              entries.add(entry(file));
            }
          }
        }
        request.response
          ..statusCode = 207
          ..headers.contentType = ContentType('application', 'xml')
          ..write(
            '<?xml version="1.0" encoding="utf-8"?>'
            '<d:multistatus xmlns:d="DAV:">${entries.join()}</d:multistatus>',
          );
        request.response.close();
      case 'MKCOL':
        folders.add(relative);
        request.response.statusCode = HttpStatus.created;
        request.response.close();
      case 'GET':
        final content = files[relative];
        if (content == null) {
          request.response.statusCode = HttpStatus.notFound;
        } else {
          request.response
            ..statusCode = HttpStatus.ok
            ..headers.contentType =
                ContentType('text', 'markdown', charset: 'utf-8')
            ..write(content);
        }
        request.response.close();
      case 'PUT':
        final body = utf8.decoder.bind(request).join();
        body.then((value) {
          files[relative] = value;
          request.response.statusCode = HttpStatus.created;
          request.response.close();
        });
      case 'DELETE':
        if (files.remove(relative) == null) {
          request.response.statusCode = HttpStatus.notFound;
        } else {
          request.response.statusCode = HttpStatus.noContent;
        }
        request.response.close();
      default:
        request.response.statusCode = HttpStatus.methodNotAllowed;
        request.response.close();
    }
  }

  String entry(String path, {bool isFolder = false}) {
    final href = '/dav/${path.split('/').map(Uri.encodeComponent).join('/')}'
        '${isFolder ? '/' : ''}';
    return '<d:response><d:href>$href</d:href><d:propstat><d:prop>'
        '<d:getlastmodified>${HttpDate.format(modified)}</d:getlastmodified>'
        '</d:prop><d:status>HTTP/1.1 200 OK</d:status></d:propstat>'
        '</d:response>';
  }
}

void main() {
  late _FakeDavServer fake;
  late WebDavClient client;

  setUp(() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    fake = _FakeDavServer(server);
    client = WebDavClient(
      baseUrl: fake.baseUrl,
      username: 'user',
      password: 'secret',
    );
  });

  tearDown(() async {
    client.close();
    await fake.server.close(force: true);
  });

  test('creates a folder and transfers files', () async {
    await client.ensureFolder('pero');
    expect(fake.folders, contains('pero'));

    await client.upload('pero', 'note-1.md', '# Заметка\n\nТекст');
    expect(fake.files['pero/note-1.md'], '# Заметка\n\nТекст');

    final entries = await client.list('pero');
    expect(entries.map((entry) => entry.name), contains('note-1.md'));
    expect(entries.first.modified, fake.modified.toLocal());

    final stat = await client.modified('pero', 'note-1.md');
    expect(stat, fake.modified.toLocal());

    expect(await client.download('pero', 'note-1.md'), '# Заметка\n\nТекст');

    await client.delete('pero', 'note-1.md');
    expect(fake.files.containsKey('pero/note-1.md'), isFalse);
    await client.delete('pero', 'missing.md');
  });

  test('creates nested folders', () async {
    await client.ensureFolder('one/two');
    expect(fake.folders, containsAll(<String>['one', 'one/two']));
  });

  test('reports wrong credentials', () async {
    final bad = WebDavClient(
      baseUrl: fake.baseUrl,
      username: 'user',
      password: 'wrong',
    );
    try {
      await expectLater(
        bad.list('pero'),
        throwsA(
          isA<WebDavException>().having(
            (error) => error.message,
            'message',
            contains('логин или пароль'),
          ),
        ),
      );
    } finally {
      bad.close();
    }
  });
}
