import 'dart:math' as math;

import 'package:characters/characters.dart';

class WordStatistics {
  const WordStatistics({
    required this.words,
    required this.characters,
    required this.minutes,
  });

  final int words;
  final int characters;
  final int minutes;

  static final RegExp _wordPattern = RegExp(
    r"[\p{L}\p{N}][\p{L}\p{N}’'-]*",
    unicode: true,
  );

  factory WordStatistics.fromText(String text) {
    final words = _wordPattern.allMatches(text).length;
    final minutes = words == 0 ? 0 : math.max(1, (words / 180).ceil());
    return WordStatistics(
      words: words,
      characters: text.characters.length,
      minutes: minutes,
    );
  }

  String describe({bool selected = false}) {
    final prefix = selected ? 'Выделено: ' : '';
    return '$prefix$words сл. · $characters зн. · ~$minutes мин';
  }
}
