enum FocusMode { off, sentence, paragraph }

extension FocusModeX on FocusMode {
  String get label {
    switch (this) {
      case FocusMode.off:
        return 'Выкл';
      case FocusMode.sentence:
        return 'Предложение';
      case FocusMode.paragraph:
        return 'Абзац';
    }
  }
}
