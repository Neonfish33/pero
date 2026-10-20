import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'documents/document_library.dart';
import 'documents/document_repository.dart';
import 'settings/settings.dart';
import 'storage/database.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    final preferences = await SharedPreferences.getInstance();
    final settings = SettingsController(preferences);
    final database = await PeroDatabase.open();
    final repository = DocumentRepository(database);
    final library = DocumentLibrary(repository);
    library.load();
    await _importStartupFile(library, args);

    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsController>.value(value: settings),
          ChangeNotifierProvider<DocumentLibrary>.value(value: library),
        ],
        child: const PeroApp(),
      ),
    );
  } catch (error, stackTrace) {
    runApp(_StartupErrorApp(error: error, stackTrace: stackTrace));
  }
}

const List<String> _markdownExtensions = <String>[
  '.md',
  '.markdown',
  '.txt',
];

Future<void> _importStartupFile(
  DocumentLibrary library,
  List<String> args,
) async {
  for (final arg in args) {
    if (arg.startsWith('-')) {
      continue;
    }
    final lower = arg.toLowerCase();
    if (!_markdownExtensions.any(lower.endsWith)) {
      continue;
    }
    try {
      final file = File(arg);
      if (!await file.exists()) {
        continue;
      }
      var text = utf8.decode(await file.readAsBytes(), allowMalformed: true);
      if (text.startsWith('\uFEFF')) {
        text = text.substring(1);
      }
      library.importMarkdown(
        text,
        filePath: arg,
        fallbackTitle: _fileBaseName(arg),
      );
      return;
    } catch (_) {
      return;
    }
  }
}

String _fileBaseName(String path) {
  final name = path.split(RegExp(r'[\\/]')).last;
  final dot = name.lastIndexOf('.');
  return dot > 0 ? name.substring(0, dot) : name;
}

class _StartupErrorApp extends StatelessWidget {
  const _StartupErrorApp({required this.error, required this.stackTrace});

  final Object error;
  final StackTrace stackTrace;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: const Locale('ru'),
      supportedLocales: const <Locale>[Locale('ru'), Locale('en')],
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF1A8CFF),
        fontFamily: 'Inter',
      ),
      home: Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Не удалось запустить «Перо»',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Проверьте, что у приложения есть доступ к папке данных.',
                  ),
                  const SizedBox(height: 16),
                  SelectableText(
                    '$error\n\n$stackTrace',
                    style: const TextStyle(
                      fontFamily: 'IBM Plex Mono',
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
