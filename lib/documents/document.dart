import 'dart:math';

import '../editor/markdown_parser.dart';

const String kWelcomeMarkdown = '''# Перо

Тихий редактор для текста. Markdown, фокус и ничего лишнего.

## Что умеет

- Режим фокуса: подсвечивает текущее предложение или абзац
- Печатная машинка: строка с курсором всегда по центру
- Три шрифта, светлая и тёмная темы
- Предпросмотр: Ctrl + E
- **Жирный** и *курсив*: Ctrl + B и Ctrl + I
- Списки продолжаются сами, когда вы нажимаете Enter

> Всё хранится локально и сохраняется автоматически. Экспорт — кнопкой или через меню.

Начните писать здесь. Включите режим фокуса внизу и посмотрите, как гаснет всё лишнее.

Не знакомы с Markdown? Откройте «Гайд по Markdown» в меню (⋮) или нажмите знак вопроса в списке документов.
''';

const String kMarkdownGuide = '''# Гайд по Markdown

Markdown — это способ оформлять текст обычными символами. Никаких кнопок и панелей: вы просто пишете, а Перо подсвечивает разметку.

## Заголовки

Решётка в начале строки делает заголовок. Чем больше решёток, тем меньше уровень.

# Заголовок первого уровня
## Заголовок второго уровня
### Заголовок третьего уровня

## Жирный и курсив

Оберните текст двумя звёздочками для **жирного** и одной для *курсива*.

**жирный текст**
*курсив*
`код в строке`

Горячие клавиши: Ctrl + B и Ctrl + I. Выделите слово и нажмите сочетание. В Windows используется Ctrl, на macOS — ⌘.

## Списки

Маркированный список начинается с дефиса, звёздочки или плюса:

- первый пункт
- второй пункт
- третий пункт

Нумерованный список начинается с числа и точки:

1. первый шаг
2. второй шаг
3. третий шаг

Когда вы нажимаете Enter в списке, следующий пункт появляется сам. Пустой пункт завершает список.

## Цитаты

Поставьте `>` в начале строки:

> Это цитата.
> Она может занимать несколько строк.

## Код

Три обратные кавычки открывают блок кода:

```dart
void main() {
  print('Привет, Перо!');
}
```

## Ссылки

Ссылка записывается в квадратных и круглых скобках:

[текст ссылки](https://example.com)

## Линия-разделитель

Три дефиса на отдельной строке:

---

## Что ещё умеет Перо

- Ctrl + E — предпросмотр.
- «Фокус» подсвечивает текущее предложение или абзац.
- «Печатная машинка» держит строку с курсором по центру.
- Текст сохраняется автоматически. Для копии используйте «Экспорт Markdown» в меню.
- Шрифт, размер, тему и ширину колонки можно менять внизу.

Пишите спокойно. Разметка нужна только там, где она помогает.
''';

const String kMarkdownGuideId = 'pero-markdown-guide';

class PeroDocument {
  const PeroDocument({
    required this.id,
    required this.title,
    required this.markdown,
    required this.createdAt,
    required this.updatedAt,
    required this.revision,
    this.filePath,
  });

  final String id;
  final String title;
  final String markdown;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? filePath;
  final int revision;

  String get displayTitle => title.trim().isEmpty ? 'Без названия' : title;

  factory PeroDocument.create({
    String markdown = '',
    String? filePath,
    String? title,
  }) {
    final now = DateTime.now();
    return PeroDocument(
      id: _newId(),
      title: title ?? deriveTitle(markdown),
      markdown: markdown,
      createdAt: now,
      updatedAt: now,
      filePath: filePath,
      revision: 0,
    );
  }

  PeroDocument copyWith({
    String? title,
    String? markdown,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? filePath,
    int? revision,
  }) {
    return PeroDocument(
      id: id,
      title: title ?? this.title,
      markdown: markdown ?? this.markdown,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      filePath: filePath ?? this.filePath,
      revision: revision ?? this.revision,
    );
  }

  static final Random _random = Random();

  static String _newId() {
    final time = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final random = _random.nextInt(0xFFFFFFFF).toRadixString(36);
    return '$time-$random';
  }
}
