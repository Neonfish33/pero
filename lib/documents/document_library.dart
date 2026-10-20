import 'dart:async';

import 'package:flutter/foundation.dart';

import '../editor/markdown_parser.dart';
import 'document.dart';
import 'document_repository.dart';

class DocumentLibrary extends ChangeNotifier {
  DocumentLibrary(this._repository);

  final DocumentRepository _repository;
  final List<PeroDocument> _documents = [];
  PeroDocument? _current;
  String _query = '';
  Timer? _saveTimer;
  String? _lastError;
  bool _disposed = false;

  List<PeroDocument> get documents =>
      List<PeroDocument>.unmodifiable(_documents);

  PeroDocument? get current => _current;

  String get query => _query;

  String? get lastError => _lastError;

  List<PeroDocument> get filteredDocuments {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) {
      return List<PeroDocument>.unmodifiable(_documents);
    }
    return _documents
        .where(
          (document) =>
              document.title.toLowerCase().contains(query) ||
              document.markdown.toLowerCase().contains(query),
        )
        .toList(growable: false);
  }

  void load() {
    _documents
      ..clear()
      ..addAll(_repository.all());
    if (_documents.isEmpty) {
      final welcome = PeroDocument.create(markdown: kWelcomeMarkdown);
      _repository.upsert(welcome);
      _documents.add(welcome);
    }
    _current = _documents.first;
    _notify();
  }

  void open(String id) {
    if (_current?.id == id) {
      return;
    }
    final index = _documents.indexWhere((document) => document.id == id);
    if (index < 0) {
      return;
    }
    flush();
    _current = _documents[index];
    _notify();
  }

  void createDocument() {
    flush();
    final document = PeroDocument.create();
    _repository.upsert(document);
    _documents.insert(0, document);
    _current = document;
    _notify();
  }

  void openMarkdownGuide() {
    final index = _documents.indexWhere(
      (document) => document.id == kMarkdownGuideId,
    );
    if (index >= 0) {
      open(kMarkdownGuideId);
      return;
    }

    flush();
    final now = DateTime.now();
    final guide = PeroDocument(
      id: kMarkdownGuideId,
      title: 'Гайд по Markdown',
      markdown: kMarkdownGuide,
      createdAt: now,
      updatedAt: now,
      revision: 0,
    );
    _repository.upsert(guide);
    _documents.insert(0, guide);
    _current = guide;
    _notify();
  }

  void updateText(String markdown) {
    final current = _current;
    if (current == null) {
      return;
    }
    final title = deriveTitle(markdown);
    final updated = current.copyWith(
      title: title,
      markdown: markdown,
      updatedAt: DateTime.now(),
      revision: current.revision + 1,
    );
    _current = updated;
    final index = _documents.indexWhere(
      (document) => document.id == updated.id,
    );
    if (index >= 0) {
      _documents[index] = updated;
    }
    _scheduleSave();
    if (title != current.title) {
      _notify();
    }
  }

  void deleteDocument(String id) {
    final index = _documents.indexWhere((document) => document.id == id);
    if (index < 0) {
      return;
    }
    if (_current?.id == id) {
      _saveTimer?.cancel();
      _saveTimer = null;
    }
    _repository.delete(id);
    _documents.removeAt(index);

    if (_current?.id == id) {
      _current = null;
      if (_documents.isEmpty) {
        final document = PeroDocument.create();
        _repository.upsert(document);
        _documents.add(document);
      }
      _current = _documents.first;
    }
    _notify();
  }

  void importMarkdown(
    String markdown, {
    String? filePath,
    String? fallbackTitle,
  }) {
    flush();
    final normalized = normalizeNewlines(markdown);
    final title = deriveTitle(
      normalized,
      fallback: fallbackTitle?.trim().isNotEmpty == true
          ? fallbackTitle!.trim()
          : 'Без названия',
    );
    final document = PeroDocument.create(
      markdown: normalized,
      filePath: filePath,
      title: title,
    );
    _repository.upsert(document);
    _documents.insert(0, document);
    _current = document;
    _notify();
  }

  int importDocuments(List<PeroDocument> documents) {
    if (documents.isEmpty) {
      return 0;
    }
    flush();
    final knownIds = _documents.map((document) => document.id).toSet();
    var imported = 0;
    for (final document in documents) {
      if (!knownIds.add(document.id)) {
        continue;
      }
      _repository.upsert(document);
      _documents.add(document);
      imported++;
    }
    if (imported > 0) {
      _documents.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      _current = _documents.first;
      _notify();
    }
    return imported;
  }

  PeroDocument? documentById(String id) {
    for (final document in _documents) {
      if (document.id == id) {
        return document;
      }
    }
    return null;
  }

  void insertDocument(PeroDocument document) {
    if (_documents.any((existing) => existing.id == document.id)) {
      return;
    }
    _repository.upsert(document);
    _documents.add(document);
    _notify();
  }

  void updateFromRemote(
    String id, {
    required String markdown,
    required DateTime updatedAt,
  }) {
    final index = _documents.indexWhere((document) => document.id == id);
    if (index < 0) {
      return;
    }
    final existing = _documents[index];
    final normalized = normalizeNewlines(markdown);
    final updated = existing.copyWith(
      markdown: normalized,
      title: deriveTitle(normalized, fallback: existing.title),
      updatedAt: updatedAt,
      revision: existing.revision + 1,
    );
    _documents[index] = updated;
    if (_current?.id == id) {
      _current = updated;
    }
    _repository.upsert(updated);
    _notify();
  }

  void setQuery(String value) {
    if (_query == value) {
      return;
    }
    _query = value;
    _notify();
  }

  void flush() {
    _saveTimer?.cancel();
    _saveTimer = null;
    final current = _current;
    if (current != null) {
      _save(current);
    }
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 450), () {
      _saveTimer = null;
      final current = _current;
      if (current != null) {
        _save(current);
      }
    });
  }

  void _save(PeroDocument document) {
    try {
      _repository.upsert(document);
      if (_lastError != null) {
        _lastError = null;
        _notify();
      }
    } catch (error) {
      _lastError = 'Не удалось сохранить документ: $error';
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _saveTimer = null;
    final current = _current;
    if (current != null) {
      try {
        _repository.upsert(current);
      } catch (_) {
        // Nothing sensible to do while shutting down.
      }
    }
    _disposed = true;
    super.dispose();
  }
}
