import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/theme/pero_theme.dart';
import '../documents/document.dart';
import '../documents/document_library.dart';
import '../editor/focus_mode.dart';
import '../editor/list_continuation_formatter.dart';
import '../editor/markdown_highlighter.dart';
import '../editor/markdown_parser.dart';
import '../editor/word_statistics.dart';
import '../preview/markdown_preview.dart';
import '../settings/settings.dart';
import '../storage/file_service.dart';
import '../storage/legacy_backup.dart';
import '../sync/cloud_sync_dialog.dart';

class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  late final DocumentLibrary _library;
  late final SettingsController _settings;
  late final MarkdownEditingController _controller;
  late final AppLifecycleListener _lifecycle;
  final FileService _fileService = FileService();

  final ScrollController _scroll = ScrollController();
  final FocusNode _editorFocus = FocusNode(debugLabel: 'editor');
  final FocusNode _surfaceFocus = FocusNode(debugLabel: 'surface');
  final FocusNode _searchFocus = FocusNode(debugLabel: 'search');
  final TextEditingController _search = TextEditingController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  String? _loadedId;
  String _lastText = '';
  String? _pendingDelete;
  String? _lastShownError;
  bool _suppress = false;
  bool _preview = false;
  bool _uiVisible = true;
  bool _typewriterScheduled = false;
  double _viewportHeight = 0;
  double _textWidth = 0;
  EdgeInsets _contentPadding = EdgeInsets.zero;
  Brightness _platformBrightness = Brightness.light;

  @override
  void initState() {
    super.initState();
    _library = context.read<DocumentLibrary>();
    _settings = context.read<SettingsController>();
    _platformBrightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;

    final initial = _library.current;
    _controller = MarkdownEditingController(text: initial?.markdown ?? '');
    _controller.selection = const TextSelection.collapsed(offset: 0);
    _loadedId = initial?.id;
    _lastText = _controller.text;
    _applyAppearance();

    _controller.addListener(_onEditorChanged);
    _search.addListener(_onSearchChanged);
    _library.addListener(_onLibraryChanged);
    _settings.addListener(_onSettingsChanged);

    _lifecycle = AppLifecycleListener(onStateChange: _onLifecycleChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _editorFocus.requestFocus();
      if (_scroll.hasClients) {
        _scroll.jumpTo(0);
      }
      if (_settings.typewriter) {
        _scheduleTypewriter();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final brightness = MediaQuery.platformBrightnessOf(context);
    if (brightness != _platformBrightness) {
      _platformBrightness = brightness;
      _applyAppearance();
    }
  }

  @override
  void dispose() {
    _library.removeListener(_onLibraryChanged);
    _settings.removeListener(_onSettingsChanged);
    _controller.removeListener(_onEditorChanged);
    _search.removeListener(_onSearchChanged);
    _lifecycle.dispose();
    _library.flush();
    _controller.dispose();
    _search.dispose();
    _scroll.dispose();
    _editorFocus.dispose();
    _surfaceFocus.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  PeroPalette get _currentPalette {
    switch (_settings.theme) {
      case ThemePreference.light:
        return PeroPalette.light;
      case ThemePreference.dark:
        return PeroPalette.dark;
      case ThemePreference.auto:
        return PeroPalette.forBrightness(_platformBrightness);
    }
  }

  void _applyAppearance() {
    _controller.updateAppearance(
      font: _settings.font,
      fontSize: _settings.fontSize,
      focusMode: _settings.focusMode,
      palette: _currentPalette,
    );
  }

  void _onSettingsChanged() {
    if (!mounted) {
      return;
    }
    _applyAppearance();
    _scheduleTypewriter();
    setState(() {});
  }

  void _onLibraryChanged() {
    if (!mounted) {
      return;
    }
    final error = _library.lastError;
    if (error == null) {
      _lastShownError = null;
    } else if (error != _lastShownError) {
      _lastShownError = error;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _toast(error);
        }
      });
    }
    _syncDocument();
    setState(() {});
  }

  void _syncDocument() {
    final document = _library.current;
    if (document == null) {
      return;
    }
    if (_loadedId == document.id && _lastText == document.markdown) {
      return;
    }
    _loadedId = document.id;
    _suppress = true;
    _controller.value = TextEditingValue(
      text: document.markdown,
      selection: const TextSelection.collapsed(offset: 0),
    );
    _suppress = false;
    _lastText = document.markdown;
    if (_preview) {
      _preview = false;
    }
    if (_scroll.hasClients) {
      _scroll.jumpTo(0);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _editorFocus.requestFocus();
      if (_scroll.hasClients) {
        _scroll.jumpTo(0);
      }
      if (_settings.typewriter) {
        _scheduleTypewriter();
      }
    });
  }

  void _onEditorChanged() {
    final text = _controller.text;
    if (!_suppress && text != _lastText) {
      _lastText = text;
      _library.updateText(text);
      if (_uiVisible) {
        setState(() => _uiVisible = false);
      }
    }
    _scheduleTypewriter();
  }

  void _onSearchChanged() {
    _library.setQuery(_search.text);
  }

  void _onLifecycleChanged(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _library.flush();
    }
  }

  void _scheduleTypewriter() {
    if (!_settings.typewriter || _preview || _typewriterScheduled) {
      return;
    }
    _typewriterScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _typewriterScheduled = false;
      if (!mounted || !_settings.typewriter || _preview) {
        return;
      }
      _centerCaret();
    });
  }

  void _centerCaret() {
    if (!_scroll.hasClients || _textWidth <= 0 || _viewportHeight <= 0) {
      return;
    }
    final selection = _controller.selection;
    if (!selection.isValid) {
      return;
    }
    final text = _controller.text;
    final caret = selection.extentOffset.clamp(0, text.length);
    final painter = TextPainter(
      text: TextSpan(text: text, style: _controller.baseStyle),
      textDirection: TextDirection.ltr,
      maxLines: null,
    )..layout(maxWidth: _textWidth);
    final caretOffset = painter.getOffsetForCaret(
      TextPosition(offset: caret),
      Rect.zero,
    );
    final lineHeight = painter.preferredLineHeight;
    painter.dispose();

    final target = _contentPadding.top +
        caretOffset.dy +
        lineHeight / 2 -
        _viewportHeight / 2;
    final max = _scroll.position.maxScrollExtent;
    final clamped = target.clamp(0.0, max).toDouble();
    if ((_scroll.offset - clamped).abs() < 1) {
      return;
    }
    _scroll.animateTo(
      clamped,
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOutCubic,
    );
  }

  void _showUi() {
    if (!_uiVisible && mounted) {
      setState(() => _uiVisible = true);
    }
  }

  void _togglePreview() {
    setState(() => _preview = !_preview);
    if (_preview) {
      _surfaceFocus.requestFocus();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        _editorFocus.requestFocus();
        _scheduleTypewriter();
      });
    }
  }

  void _handleBack() {
    if (_preview) {
      _togglePreview();
      return;
    }
    if (_scaffoldKey.currentState?.isDrawerOpen == true) {
      _scaffoldKey.currentState?.closeDrawer();
      return;
    }
    if (_pendingDelete != null) {
      setState(() => _pendingDelete = null);
      return;
    }
    if (_searchFocus.hasFocus) {
      _searchFocus.unfocus();
      _editorFocus.requestFocus();
      return;
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      SystemNavigator.pop();
      return;
    }
    _showUi();
  }

  bool get _canPop {
    return !_preview &&
        _pendingDelete == null &&
        !_searchFocus.hasFocus &&
        _scaffoldKey.currentState?.isDrawerOpen != true;
  }

  void _handleEscape() {
    if (_preview) {
      _togglePreview();
      return;
    }
    if (_scaffoldKey.currentState?.isDrawerOpen == true) {
      _scaffoldKey.currentState?.closeDrawer();
      return;
    }
    _editorFocus.requestFocus();
  }

  void _focusSearch() {
    final narrow = MediaQuery.sizeOf(context).width < 760;
    if (narrow) {
      _scaffoldKey.currentState?.openDrawer();
    } else if (!_settings.sidebar) {
      _settings.setSidebar(true);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _searchFocus.requestFocus();
        _search.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _search.text.length,
        );
      }
    });
  }

  void _newDocument() {
    if (_pendingDelete != null) {
      setState(() => _pendingDelete = null);
    }
    _library.createDocument();
    _scaffoldKey.currentState?.closeDrawer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _editorFocus.requestFocus();
      }
    });
  }

  void _openDocument(String id, {required bool inDrawer}) {
    if (_pendingDelete != null) {
      setState(() => _pendingDelete = null);
    }
    _library.open(id);
    if (inDrawer) {
      Navigator.of(context).pop();
    }
  }

  void _deleteDocument(String id) {
    if (_pendingDelete != id) {
      setState(() => _pendingDelete = id);
      return;
    }
    _library.deleteDocument(id);
    setState(() => _pendingDelete = null);
  }

  void _wrapSelection(String marker) {
    if (_preview || !_editorFocus.hasFocus) {
      return;
    }
    final value = _controller.value;
    final selection = value.selection;
    if (!selection.isValid) {
      return;
    }
    final start = math.min(selection.start, selection.end);
    final end = math.max(selection.start, selection.end);
    final text = value.text;
    final replacement = '$marker${text.substring(start, end)}$marker';
    _controller.value = TextEditingValue(
      text: text.replaceRange(start, end, replacement),
      selection: TextSelection(
        baseOffset: start + marker.length,
        extentOffset: end + marker.length,
      ),
    );
    _editorFocus.requestFocus();
  }

  void _toggleBold() => _wrapSelection('**');

  void _toggleItalic() => _wrapSelection('*');

  Map<ShortcutActivator, VoidCallback> _shortcuts() {
    return <ShortcutActivator, VoidCallback>{
      const SingleActivator(LogicalKeyboardKey.keyB, control: true):
          _toggleBold,
      const SingleActivator(LogicalKeyboardKey.keyB, meta: true): _toggleBold,
      const SingleActivator(LogicalKeyboardKey.keyI, control: true):
          _toggleItalic,
      const SingleActivator(LogicalKeyboardKey.keyI, meta: true):
          _toggleItalic,
      const SingleActivator(LogicalKeyboardKey.keyE, control: true):
          _togglePreview,
      const SingleActivator(LogicalKeyboardKey.keyE, meta: true):
          _togglePreview,
      const SingleActivator(LogicalKeyboardKey.keyN, control: true):
          _newDocument,
      const SingleActivator(LogicalKeyboardKey.keyN, meta: true): _newDocument,
      const SingleActivator(LogicalKeyboardKey.keyF, control: true):
          _focusSearch,
      const SingleActivator(LogicalKeyboardKey.keyF, meta: true): _focusSearch,
      const SingleActivator(LogicalKeyboardKey.escape): _handleEscape,
    };
  }

  Future<void> _copyMarkdown() async {
    await Clipboard.setData(ClipboardData(text: _controller.text));
    if (mounted) {
      _toast('Markdown скопирован');
    }
  }

  Future<void> _copyHtml() async {
    final html = markdownToStandaloneHtml(
      _controller.text,
      title: _library.current?.displayTitle ?? 'Перо',
    );
    await Clipboard.setData(ClipboardData(text: html));
    if (mounted) {
      _toast('HTML скопирован');
    }
  }

  Future<void> _importMarkdown() async {
    try {
      final opened = await _fileService.openMarkdown();
      if (opened == null) {
        return;
      }
      _library.importMarkdown(
        opened.text,
        filePath: opened.path,
        fallbackTitle: _baseName(opened.name),
      );
      if (mounted) {
        _toast('Документ импортирован');
      }
    } catch (error) {
      if (mounted) {
        _toast('Не удалось открыть файл: $error');
      }
    }
  }

  void _openCloud() {
    showDialog<void>(
      context: context,
      builder: (context) => const CloudSyncDialog(),
    );
  }

  Future<void> _importBackup() async {
    try {
      final opened = await _fileService.openBackup();
      if (opened == null) {
        return;
      }
      final backup = LegacyBackup.parse(opened.text);
      final imported = _library.importDocuments(backup.documents);
      _applyLegacySettings(backup.settings);
      if (mounted) {
        _toast(
          imported == 0
              ? 'Все документы из копии уже есть в библиотеке'
              : 'Импортировано документов: $imported',
        );
      }
    } catch (error) {
      if (mounted) {
        _toast('Не удалось импортировать резервную копию: $error');
      }
    }
  }

  void _applyLegacySettings(LegacySettings legacy) {
    if (legacy.isEmpty) {
      return;
    }
    if (legacy.font != null) {
      for (final font in EditorFont.values) {
        if (font.name == legacy.font) {
          _settings.setFont(font);
        }
      }
    }
    if (legacy.focus != null) {
      for (final mode in FocusMode.values) {
        if (mode.name == legacy.focus) {
          _settings.setFocusMode(mode);
        }
      }
    }
    if (legacy.theme != null) {
      for (final theme in ThemePreference.values) {
        if (theme.name == legacy.theme) {
          _settings.setTheme(theme);
        }
      }
    }
    if (legacy.fontSize != null) {
      _settings.setFontSize(legacy.fontSize!);
    }
    if (legacy.typewriter != null) {
      _settings.setTypewriter(legacy.typewriter!);
    }
    if (legacy.sidebar != null) {
      _settings.setSidebar(legacy.sidebar!);
    }
  }

  Future<void> _exportMarkdown() async {
    try {
      final saved = await _fileService.saveMarkdown(
        title: _library.current?.displayTitle ?? 'Без названия',
        content: _controller.text,
      );
      if (mounted && saved) {
        _toast('Markdown сохранён');
      }
    } catch (error) {
      if (mounted) {
        _toast('Не удалось сохранить файл: $error');
      }
    }
  }

  Future<void> _exportHtml() async {
    try {
      final html = markdownToStandaloneHtml(
        _controller.text,
        title: _library.current?.displayTitle ?? 'Перо',
      );
      final saved = await _fileService.saveHtml(
        title: _library.current?.displayTitle ?? 'Без названия',
        content: html,
      );
      if (mounted && saved) {
        _toast('HTML сохранён');
      }
    } catch (error) {
      if (mounted) {
        _toast('Не удалось сохранить файл: $error');
      }
    }
  }

  String? _baseName(String? name) {
    if (name == null) {
      return null;
    }
    final dot = name.lastIndexOf('.');
    return dot > 0 ? name.substring(0, dot) : name;
  }

  void _toast(String message) {
    if (!mounted) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(milliseconds: 1600),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<PeroPalette>()!;
    return Focus(
      focusNode: _surfaceFocus,
      child: CallbackShortcuts(
        bindings: _shortcuts(),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 760;
            return PopScope(
              canPop: _canPop,
              onPopInvokedWithResult: (didPop, result) {
                if (!didPop) {
                  _handleBack();
                }
              },
              child: Scaffold(
                key: _scaffoldKey,
                backgroundColor: palette.bg,
                drawer: narrow
                    ? Drawer(
                        width: math.min(320, constraints.maxWidth * 0.86),
                        child: SafeArea(
                          child: _sidebar(context, inDrawer: true),
                        ),
                      )
                    : null,
                body: SafeArea(
                  child: MouseRegion(
                    onHover: (_) => _showUi(),
                    child: Listener(
                      onPointerDown: (_) => _showUi(),
                      behavior: HitTestBehavior.translucent,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (!narrow && _settings.sidebar)
                            _sidebar(context, inDrawer: false),
                          Expanded(child: _main(context, narrow)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _main(BuildContext context, bool narrow) {
    return Column(
      children: [
        _fade(_topBar(context, narrow), _uiVisible || _preview),
        Expanded(
          child: _preview ? _previewPane(context) : _editorPane(context),
        ),
        _bottomBar(context),
      ],
    );
  }

  Widget _fade(Widget child, bool visible) {
    return AnimatedOpacity(
      opacity: visible ? 1 : 0,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
      child: IgnorePointer(ignoring: !visible, child: child),
    );
  }

  Widget _topBar(BuildContext context, bool narrow) {
    final palette = Theme.of(context).extension<PeroPalette>()!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Row(
        children: [
          _iconButton(
            icon: narrow
                ? Icons.menu
                : (_settings.sidebar ? Icons.menu_open : Icons.menu),
            tooltip: narrow ? 'Документы' : 'Показать или скрыть документы',
            onPressed: narrow
                ? () => _scaffoldKey.currentState?.openDrawer()
                : () => _settings.setSidebar(!_settings.sidebar),
          ),
          Expanded(
            child: Center(
              child: Text(
                _library.current?.displayTitle ?? 'Перо',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: kSansFamily,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: palette.ui,
                ),
              ),
            ),
          ),
          _iconButton(
            icon: Icons.add,
            tooltip: 'Новый документ (Ctrl+N)',
            onPressed: _newDocument,
          ),
          _iconButton(
            icon: _preview ? Icons.edit_outlined : Icons.visibility_outlined,
            tooltip: _preview
                ? 'Вернуться к редактору (Ctrl+E)'
                : 'Предпросмотр (Ctrl+E)',
            color: _preview ? palette.accent : null,
            onPressed: _togglePreview,
          ),
          PopupMenuButton<String>(
            tooltip: 'Ещё',
            icon: const Icon(Icons.more_vert, size: 18),
            iconSize: 18,
            onSelected: (value) {
              switch (value) {
                case 'guide':
                  _library.openMarkdownGuide();
                case 'cloud':
                  _openCloud();
                case 'import':
                  _importMarkdown();
                case 'import_backup':
                  _importBackup();
                case 'export_md':
                  _exportMarkdown();
                case 'export_html':
                  _exportHtml();
                case 'copy_md':
                  _copyMarkdown();
                case 'copy_html':
                  _copyHtml();
              }
            },
            itemBuilder: (context) => const <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: 'guide',
                child: Text('Гайд по Markdown'),
              ),
              PopupMenuDivider(),
              PopupMenuItem<String>(
                value: 'cloud',
                child: Text('Облако (WebDAV)…'),
              ),
              PopupMenuDivider(),
              PopupMenuItem<String>(
                value: 'import',
                child: Text('Импорт Markdown…'),
              ),
              PopupMenuItem<String>(
                value: 'import_backup',
                child: Text('Импорт резервной копии (JSON)…'),
              ),
              PopupMenuItem<String>(
                value: 'export_md',
                child: Text('Экспорт Markdown…'),
              ),
              PopupMenuItem<String>(
                value: 'export_html',
                child: Text('Экспорт HTML…'),
              ),
              PopupMenuDivider(),
              PopupMenuItem<String>(
                value: 'copy_md',
                child: Text('Копировать Markdown'),
              ),
              PopupMenuItem<String>(
                value: 'copy_html',
                child: Text('Копировать HTML'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _editorPane(BuildContext context) {
    final palette = Theme.of(context).extension<PeroPalette>()!;
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewport = constraints.maxHeight;
        final width = math.min(
          constraints.maxWidth,
          _settings.columnWidth.editorWidth,
        );
        final horizontal = constraints.maxWidth < 600 ? 18.0 : 28.0;
        final typewriter = _settings.typewriter;
        final top = typewriter
            ? viewport * 0.5
            : math.max(48.0, viewport * 0.12);
        final bottom = typewriter
            ? viewport * 0.5
            : math.max(160.0, viewport * 0.55);
        final viewportChanged = _viewportHeight != viewport;
        _viewportHeight = viewport;
        _contentPadding = EdgeInsets.fromLTRB(horizontal, top, horizontal, bottom);
        _textWidth = math.max(1.0, width - horizontal * 2);
        if (viewportChanged && typewriter && !_preview) {
          _scheduleTypewriter();
        }
        final style = _controller.baseStyle;

        return Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: width,
            height: viewport,
            child: Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (_) {
                if (!_editorFocus.hasFocus) {
                  _editorFocus.requestFocus();
                }
                _showUi();
              },
              child: SingleChildScrollView(
                controller: _scroll,
                padding: _contentPadding,
                child: TextField(
                  controller: _controller,
                  focusNode: _editorFocus,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  autofocus: true,
                  cursorColor: palette.accent,
                  cursorWidth: 2,
                  style: style,
                  strutStyle: StrutStyle(
                    fontFamily: style.fontFamily,
                    fontSize: style.fontSize,
                    height: style.height,
                    forceStrutHeight: true,
                  ),
                  decoration: InputDecoration(
                    isCollapsed: true,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    hintText: 'Начните писать…',
                    hintStyle: style.copyWith(color: palette.dim),
                  ),
                  inputFormatters: const <TextInputFormatter>[
                    ListContinuationFormatter(),
                  ],
                  onTap: _showUi,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _previewPane(BuildContext context) {
    final palette = Theme.of(context).extension<PeroPalette>()!;
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontal = constraints.maxWidth < 600 ? 18.0 : 28.0;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            horizontal,
            math.max(64.0, constraints.maxHeight * 0.10),
            horizontal,
            math.max(160.0, constraints.maxHeight * 0.30),
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: _settings.columnWidth.previewWidth,
              ),
              child: MarkdownPreview(
                markdown: _controller.text,
                baseStyle: _controller.baseStyle,
                palette: palette,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _bottomBar(BuildContext context) {
    final palette = Theme.of(context).extension<PeroPalette>()!;
    final narrow = MediaQuery.sizeOf(context).width < 760;

    if (narrow) {
      return _compactBottomBar(context, palette);
    }

    final controls = <Widget>[
      _barLabel('Фокус', palette),
      _toolButton(
        'Выкл',
        selected: _settings.focusMode == FocusMode.off,
        onTap: () => _settings.setFocusMode(FocusMode.off),
      ),
      _toolButton(
        'Предложение',
        selected: _settings.focusMode == FocusMode.sentence,
        onTap: () => _settings.setFocusMode(FocusMode.sentence),
      ),
      _toolButton(
        'Абзац',
        selected: _settings.focusMode == FocusMode.paragraph,
        onTap: () => _settings.setFocusMode(FocusMode.paragraph),
      ),
      _separator(palette),
      _toolButton(
        'Печатная машинка',
        selected: _settings.typewriter,
        onTap: _toggleTypewriter,
      ),
      _separator(palette),
      _fontMenu(palette),
      _toolButton(
        'A−',
        compact: true,
        onTap: () => _settings.setFontSize(_settings.fontSize - 1),
      ),
      _toolButton(
        'A+',
        compact: true,
        onTap: () => _settings.setFontSize(_settings.fontSize + 1),
      ),
      _toolButton(
        'Тема: ${_settings.theme.label}',
        onTap: _settings.cycleTheme,
      ),
      _separator(palette),
      _toolButton(
        'Колонка: ${_settings.columnWidth.label}',
        onTap: _settings.cycleColumnWidth,
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: palette.line)),
      ),
      padding: const EdgeInsets.fromLTRB(8, 3, 8, 3),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: controls),
            ),
          ),
          const SizedBox(width: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 300),
            child: _StatsView(controller: _controller),
          ),
        ],
      ),
    );
  }

  Widget _compactBottomBar(BuildContext context, PeroPalette palette) {
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: palette.line)),
      ),
      padding: const EdgeInsets.fromLTRB(4, 2, 4, 2),
      child: Row(
        children: [
          _iconButton(
            icon: _focusIcon,
            tooltip: 'Фокус: ${_settings.focusMode.label}',
            color: _settings.focusMode == FocusMode.off
                ? null
                : palette.accent,
            onPressed: _cycleFocus,
          ),
          _iconButton(
            icon: Icons.vertical_align_center,
            tooltip: 'Печатная машинка',
            color: _settings.typewriter ? palette.accent : null,
            onPressed: _toggleTypewriter,
          ),
          const SizedBox(width: 4),
          _iconButton(
            icon: Icons.text_decrease,
            tooltip: 'Меньше шрифт',
            onPressed: () => _settings.setFontSize(_settings.fontSize - 1),
          ),
          _iconButton(
            icon: Icons.text_increase,
            tooltip: 'Больше шрифт',
            onPressed: () => _settings.setFontSize(_settings.fontSize + 1),
          ),
          PopupMenuButton<String>(
            tooltip: 'Оформление',
            icon: const Icon(Icons.tune, size: 18),
            iconSize: 18,
            onSelected: (value) {
              if (value.startsWith('font:')) {
                final name = value.substring(5);
                for (final font in EditorFont.values) {
                  if (font.name == name) {
                    _settings.setFont(font);
                  }
                }
              } else if (value.startsWith('theme:')) {
                final name = value.substring(6);
                for (final theme in ThemePreference.values) {
                  if (theme.name == name) {
                    _settings.setTheme(theme);
                  }
                }
              }
            },
            itemBuilder: (context) => <PopupMenuEntry<String>>[
              for (final font in EditorFont.values)
                CheckedPopupMenuItem<String>(
                  value: 'font:${font.name}',
                  checked: _settings.font == font,
                  child: Text(font.label),
                ),
              const PopupMenuDivider(),
              for (final theme in ThemePreference.values)
                CheckedPopupMenuItem<String>(
                  value: 'theme:${theme.name}',
                  checked: _settings.theme == theme,
                  child: Text('Тема: ${theme.label}'),
                ),
            ],
          ),
          const Spacer(),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 96),
            child: _StatsView(controller: _controller, compact: true),
          ),
        ],
      ),
    );
  }

  IconData get _focusIcon {
    switch (_settings.focusMode) {
      case FocusMode.off:
        return Icons.center_focus_weak;
      case FocusMode.sentence:
        return Icons.short_text;
      case FocusMode.paragraph:
        return Icons.subject;
    }
  }

  void _cycleFocus() {
    final next = switch (_settings.focusMode) {
      FocusMode.off => FocusMode.sentence,
      FocusMode.sentence => FocusMode.paragraph,
      FocusMode.paragraph => FocusMode.off,
    };
    _settings.setFocusMode(next);
  }

  void _toggleTypewriter() {
    _settings.setTypewriter(!_settings.typewriter);
    if (_settings.typewriter) {
      _scheduleTypewriter();
    }
  }

  Widget _sidebar(BuildContext context, {required bool inDrawer}) {
    final palette = Theme.of(context).extension<PeroPalette>()!;
    final documents = <PeroDocument>[
      ..._library.filteredDocuments,
    ]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    return Container(
      width: inDrawer ? null : 250,
      decoration: inDrawer
          ? null
          : BoxDecoration(
              color: palette.side,
              border: Border(right: BorderSide(color: palette.line)),
            ),
      color: inDrawer ? palette.side : null,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 6, 6),
            child: Row(
              children: [
                Text(
                  'Документы',
                  style: TextStyle(
                    fontFamily: kSansFamily,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: palette.ui,
                  ),
                ),
                const Spacer(),
                _iconButton(
                  icon: Icons.help_outline,
                  tooltip: 'Гайд по Markdown',
                  onPressed: () {
                    _library.openMarkdownGuide();
                    if (inDrawer) {
                      Navigator.of(context).pop();
                    }
                  },
                ),
                _iconButton(
                  icon: Icons.add,
                  tooltip: 'Новый документ (Ctrl+N)',
                  onPressed: _newDocument,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: TextField(
              controller: _search,
              focusNode: _searchFocus,
              style: TextStyle(
                fontFamily: kSansFamily,
                fontSize: 12.5,
                color: palette.fg,
              ),
              decoration: InputDecoration(
                hintText: 'Поиск',
                isDense: true,
                filled: true,
                fillColor: palette.bg,
                prefixIcon: Icon(Icons.search, size: 16, color: palette.ui),
                prefixIconConstraints:
                    const BoxConstraints(minWidth: 30, minHeight: 30),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Очистить',
                        icon: Icon(Icons.close, size: 14, color: palette.ui),
                        onPressed: _search.clear,
                      ),
                suffixIconConstraints:
                    const BoxConstraints(minWidth: 28, minHeight: 28),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: palette.line),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: palette.accent),
                ),
                hintStyle: TextStyle(
                  fontFamily: kSansFamily,
                  fontSize: 12.5,
                  color: palette.ui,
                ),
              ),
            ),
          ),
          Expanded(
            child: MouseRegion(
              onExit: (_) {
                if (_pendingDelete != null) {
                  setState(() => _pendingDelete = null);
                }
              },
              child: documents.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          _library.query.isEmpty
                              ? 'Нет документов'
                              : 'Ничего не найдено',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: kSansFamily,
                            fontSize: 12,
                            color: palette.ui,
                          ),
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                      itemCount: documents.length,
                      itemBuilder: (context, index) {
                        final document = documents[index];
                        return _DocumentTile(
                          document: document,
                          selected: document.id == _library.current?.id,
                          pendingDelete: _pendingDelete == document.id,
                          onTap: () => _openDocument(
                            document.id,
                            inDrawer: inDrawer,
                          ),
                          onDelete: () => _deleteDocument(document.id),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _barLabel(String text, PeroPalette palette) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: kSansFamily,
          fontSize: 12,
          color: palette.ui,
        ),
      ),
    );
  }

  Widget _separator(PeroPalette palette) {
    return Container(
      width: 1,
      height: 16,
      color: palette.line,
      margin: const EdgeInsets.symmetric(horizontal: 4),
    );
  }

  Widget _toolButton(
    String label, {
    required VoidCallback onTap,
    bool selected = false,
    bool compact = false,
  }) {
    final palette = Theme.of(context).extension<PeroPalette>()!;
    return Tooltip(
      message: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          hoverColor: palette.line.withValues(alpha: 0.6),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 6 : 8,
              vertical: 5,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: selected ? palette.accent : Colors.transparent,
              ),
              color: selected
                  ? palette.accent.withValues(alpha: 0.08)
                  : Colors.transparent,
            ),
            child: Text(
              label,
              style: TextStyle(
                fontFamily: kSansFamily,
                fontSize: 12,
                color: selected ? palette.accent : palette.ui,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _fontMenu(PeroPalette palette) {
    return PopupMenuButton<EditorFont>(
      tooltip: 'Шрифт',
      initialValue: _settings.font,
      onSelected: _settings.setFont,
      itemBuilder: (context) => <PopupMenuEntry<EditorFont>>[
        for (final font in EditorFont.values)
          PopupMenuItem<EditorFont>(
            value: font,
            child: Text(font.label),
          ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _settings.font.label,
              style: TextStyle(
                fontFamily: kSansFamily,
                fontSize: 12,
                color: palette.ui,
              ),
            ),
            const SizedBox(width: 3),
            Icon(Icons.expand_more, size: 14, color: palette.ui),
          ],
        ),
      ),
    );
  }

  Widget _iconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    Color? color,
  }) {
    return IconButton(
      icon: Icon(icon, size: 18),
      tooltip: tooltip,
      color: color,
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.all(8),
      constraints: const BoxConstraints.tightFor(width: 34, height: 34),
    );
  }
}

class _StatsView extends StatelessWidget {
  const _StatsView({required this.controller, this.compact = false});

  final MarkdownEditingController controller;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<PeroPalette>()!;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final text = controller.text;
        final selection = controller.selection;
        final hasSelection = selection.isValid && !selection.isCollapsed;
        final source = hasSelection
            ? text.substring(selection.start, selection.end)
            : text;
        final stats = WordStatistics.fromText(source);
        final label = compact
            ? '${stats.words} сл.'
            : stats.describe(selected: hasSelection);
        return Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.right,
          style: TextStyle(
            fontFamily: kSansFamily,
            fontSize: 12,
            color: palette.ui,
          ),
        );
      },
    );
  }
}

class _DocumentTile extends StatefulWidget {
  const _DocumentTile({
    required this.document,
    required this.selected,
    required this.pendingDelete,
    required this.onTap,
    required this.onDelete,
  });

  final PeroDocument document;
  final bool selected;
  final bool pendingDelete;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  State<_DocumentTile> createState() => _DocumentTileState();
}

class _DocumentTileState extends State<_DocumentTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<PeroPalette>()!;
    final showDelete =
        _hover || widget.selected || widget.pendingDelete;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 5, 4, 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            color: widget.selected
                ? palette.line
                : _hover
                    ? palette.line.withValues(alpha: 0.55)
                    : Colors.transparent,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.document.displayTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: kSansFamily,
                    fontSize: 13,
                    color: widget.selected ? palette.fg : palette.ui,
                  ),
                ),
              ),
              if (showDelete)
                Tooltip(
                  message: widget.pendingDelete
                      ? 'Подтвердить удаление'
                      : 'Удалить',
                  child: InkWell(
                    onTap: widget.onDelete,
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      child: Text(
                        widget.pendingDelete ? 'Удалить?' : '×',
                        style: TextStyle(
                          fontFamily: kSansFamily,
                          fontSize: 12,
                          color: widget.pendingDelete
                              ? palette.accent
                              : palette.ui,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
