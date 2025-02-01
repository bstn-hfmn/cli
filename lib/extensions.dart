extension ListExtensions<T> on List<T> {
  void replaceFirstSequence(List<T> sequence, T value, {bool reverse = false}) {
    bool equal = false;
    int inSequenceIndex = reverse ? sequence.length - 1 : 0;
    int inSourceStartIndex = -1, inSourceEndIndex = -1;

    int i = reverse ? (length - 1) : 0;
    for (; reverse ? i > -1 : i < length; reverse ? i -= 1 : i += 1) {
      if (this[i] == sequence[inSequenceIndex]) {
        inSequenceIndex = reverse ? inSequenceIndex - 1 : inSequenceIndex + 1;

        if (inSourceStartIndex == -1) inSourceStartIndex = i;
      } else {
        inSequenceIndex = reverse ? sequence.length - 1 : 0;
        inSourceStartIndex = -1;
        inSourceEndIndex = -1;
      }

      equal =
          reverse ? inSequenceIndex == -1 : inSequenceIndex >= sequence.length;
      if (equal) {
        inSourceEndIndex = reverse ? i - 1 : i + 1;
        break;
      }
    }

    if (equal) {
      final start = (reverse ? inSourceEndIndex + 1 : inSourceStartIndex);
      final end = (reverse ? inSourceStartIndex : inSourceEndIndex) + 1;

      insert(start, value);
      removeRange(start + 1, reverse ? end + 1 : end);
    }
  }
}

extension IterableExtensions<T> on Iterable<T> {
  bool equals(Iterable<T> other) {
    if (length != other.length) return false;

    bool equals = true;
    for (int i = 0; i < length; i++) {
      if (elementAt(i) != other.elementAt(i)) {
        equals = false;
        break;
      }
    }

    return equals;
  }

  Iterable<T> distinct() {
    return toSet();
  }
}

extension GetMapValueExtension<K, V> on Map<K, V> {
  V? get(K key) {
    if (containsKey(key)) {
      return this[key];
    } else {
      return null;
    }
  }
}

extension StringExtensions on String {
  bool isDigit() {
    return RegExp(r'\d').hasMatch(this);
  }

  bool isLatinAlphabetical() {
    return RegExp(r'[A-Za-z]').hasMatch(this);
  }
}
