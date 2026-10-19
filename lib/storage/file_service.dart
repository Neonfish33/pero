import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:share_plus/share_plus.dart';

class OpenedMarkdown {
  const OpenedMarkdown({
    required this.text,
    this.path,
    this.name,
  });

  final String text;
  final String? path;
  final String? name;
}

class FileService {
  static XTypeGroup get _markdownType {
    if (Platform.isIOS) {
      return const XTypeGroup(
        label: 'Markdown',
        uniformTypeIdentifiers: <String>[
          'net.daringfireball.markdown',
          'public.plain-text',
        ],
      );
    }
    if (Platform.isAndroid) {
      return const XTypeGroup(
        label: 'Markdown',
        mimeTypes: <String>['text/markdown', 'text/plain'],
      );
    }
    return const XTypeGroup(
      label: 'Markdown',
      extensions: <String>['md', 'markdown', 'txt'],
    );
  }

  static XTypeGroup get _htmlType {
    if (Platform.isIOS) {
      return const XTypeGroup(
        label: 'HTML',
        uniformTypeIdentifiers: <String>['public.html'],
      );
    }
    if (Platform.isAndroid) {
      return const XTypeGroup(
        label: 'HTML',
        mimeTypes: <String>['text/html'],
      );
    }
    return const XTypeGroup(
      label: 'HTML',
      extensions: <String>['html', 'htm'],
    );
  }

  static XTypeGroup get _jsonType {
    if (Platform.isIOS) {
      return const XTypeGroup(
        label: 'JSON',
        uniformTypeIdentifiers: <String>['public.json'],
      );
    }
    if (Platform.isAndroid) {
      return const XTypeGroup(
        label: 'JSON',
        mimeTypes: <String>['application/json', 'text/plain'],
      );
    }
    return const XTypeGroup(
      label: 'JSON',
      extensions: <String>['json', 'txt'],
    );
  }

  static bool get usesShareSheet => Platform.isAndroid || Platform.isIOS;

  Future<OpenedMarkdown?> openMarkdown() async {
    final file = await openFile(
      acceptedTypeGroups: <XTypeGroup>[_markdownType],
      confirmButtonText: 'Открыть',
    );
    return _read(file);
  }

  Future<OpenedMarkdown?> openBackup() async {
    final file = await openFile(
      acceptedTypeGroups: <XTypeGroup>[_jsonType],
      confirmButtonText: 'Импортировать',
    );
    return _read(file);
  }

  Future<OpenedMarkdown?> _read(XFile? file) async {
    if (file == null) {
      return null;
    }

    final bytes = await file.readAsBytes();
    var text = utf8.decode(bytes, allowMalformed: true);
    if (text.startsWith('\uFEFF')) {
      text = text.substring(1);
    }
    return OpenedMarkdown(
      text: text,
      path: file.path,
      name: file.name,
    );
  }

  Future<bool> saveMarkdown({
    required String title,
    required String content,
  }) async {
    return _save(
      suggestedName: _suggestedName(title, 'md'),
      content: content,
      type: _markdownType,
      mimeType: 'text/markdown',
    );
  }

  Future<bool> saveHtml({
    required String title,
    required String content,
  }) async {
    return _save(
      suggestedName: _suggestedName(title, 'html'),
      content: content,
      type: _htmlType,
      mimeType: 'text/html',
    );
  }

  Future<bool> _save({
    required String suggestedName,
    required String content,
    required XTypeGroup type,
    required String mimeType,
  }) async {
    if (usesShareSheet) {
      return _shareFile(
        fileName: suggestedName,
        content: content,
        mimeType: mimeType,
      );
    }

    final location = await getSaveLocation(
      suggestedName: suggestedName,
      acceptedTypeGroups: <XTypeGroup>[type],
      confirmButtonText: 'Сохранить',
    );
    if (location == null) {
      return false;
    }
    await File(location.path).writeAsString(content, flush: true);
    return true;
  }

  Future<bool> _shareFile({
    required String fileName,
    required String content,
    required String mimeType,
  }) async {
    final bytes = Uint8List.fromList(utf8.encode(content));
    final result = await SharePlus.instance.share(
      ShareParams(
        files: <XFile>[XFile.fromData(bytes, mimeType: mimeType)],
        fileNameOverrides: <String>[fileName],
        subject: fileName,
        title: fileName,
      ),
    );
    return result.status != ShareResultStatus.dismissed;
  }

  String _suggestedName(String title, String extension) {
    var name = title
        .replaceAll(RegExp(r'[\\/:*?"<>|\n\r\t]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (name.isEmpty) {
      name = 'Без названия';
    }
    if (name.length > 80) {
      name = name.substring(0, 80).trim();
    }
    return '$name.$extension';
  }
}
