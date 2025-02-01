mixin HashedEquatable {
  int? _cachedHash;

  int get hash;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HashedEquatable &&
          other.runtimeType == runtimeType &&
          other.hashCode == hashCode;

  @override
  int get hashCode => _cachedHash ??= hash;
}

class Stack<T> extends Iterable<T> {
  final _buffer = <T>[];
  void push(T value) => _buffer.add(value);

  T get head => _buffer.last;
  T pop() => this._buffer.removeLast();

  Iterable<T> popMany(int amount) {
    final List<T> items = List.empty(growable: true);
    for (int i = 0; i < amount; i++) {
      items.add(_buffer.removeLast());
    }

    return items;
  }

  @override
  Iterator<T> get iterator => _buffer.iterator;

  @override
  String toString() => _buffer.toString();
}
