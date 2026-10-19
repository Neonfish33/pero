import 'package:flutter_test/flutter_test.dart';
import 'package:pero/editor/word_statistics.dart';

void main() {
  test('counts words and characters', () {
    final stats = WordStatistics.fromText('Привет, мир! 123');
    expect(stats.words, 3);
    expect(stats.characters, 16);
    expect(stats.minutes, 1);
  });

  test('handles an empty text', () {
    final stats = WordStatistics.fromText('');
    expect(stats.words, 0);
    expect(stats.characters, 0);
    expect(stats.minutes, 0);
    expect(stats.describe(), '0 сл. · 0 зн. · ~0 мин');
  });

  test('counts grapheme clusters instead of UTF-16 units', () {
    final stats = WordStatistics.fromText('👋😀');
    expect(stats.characters, 2);
  });

  test('estimates reading time', () {
    final text = List<String>.filled(400, 'слово').join(' ');
    final stats = WordStatistics.fromText(text);
    expect(stats.words, 400);
    expect(stats.minutes, 3);
  });
}
