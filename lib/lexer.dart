import 'package:cli/extensions.dart';

class LexerException implements Exception {
  String message;
  LexerException(this.message);
}

enum TokenType {
  bar,
  number,
  equals,
  plus,
  minus,
  comma,
  divide,
  multiply,
  openParen,
  closeParen,
  identifier,
  whitespace,
  endOfTokens,
  lambda
}

class Token {
  final String value;
  final TokenType type;

  const Token(this.type, this.value);

  const Token.number({this.type = TokenType.number, required this.value});
  const Token.identifier(
      {this.type = TokenType.identifier, required this.value});

  @override
  String toString() {
    return 'Token('
        '${type.name}, $value)';
  }
}

class Lexer {
  String input;

  late int _inInputPointer;
  late List<Token> _tokens;

  Lexer(this.input) {
    _tokens = List.empty(growable: true);
    _inInputPointer = 0;
  }

  bool _isOnEndOfInput({num? pointer}) =>
      (pointer ?? _inInputPointer) >= input.length;

  void reset() {
    _tokens.clear();
    _inInputPointer = 0;
  }

  Token _lexDigit() {
    bool hadDot = false;
    var value = input[_inInputPointer];

    while (!_isOnEndOfInput(pointer: _inInputPointer + 1)) {
      final next = input[_inInputPointer + 1];
      if (!(next.isDigit() || (next == '.' && !hadDot))) break;
      if (next == '.') {
        hadDot = true;
      }

      _inInputPointer++;
      value += next;
    }

    return Token(TokenType.number, value);
  }

  Token _rangeByPredicate(TokenType type, bool Function(String a) predicate) {
    var value = input[_inInputPointer];

    while (!_isOnEndOfInput(pointer: _inInputPointer + 1)) {
      final next = input[_inInputPointer + 1];
      if (!predicate(next)) break;

      _inInputPointer++;
      value += next;
    }

    return Token(type, value);
  }

  String peek() {
    if (_isOnEndOfInput(pointer: _inInputPointer + 1)) {
      return '\$';
    }

    return input[_inInputPointer + 1];
  }

  Token consume(TokenType type, List<String> values) {
    var value = '';
    for (final val in values) {
      if (!_isOnEndOfInput(pointer: _inInputPointer)) {
        if (input[_inInputPointer] != val) {
          throw LexerException(
              'Tried too consume wrong token [$runtimeType.consume]');
        }

        value += val;
        ++_inInputPointer;
      } else {
        throw LexerException(
            'Tried too consume too many values [$runtimeType.consume]');
      }
    }

    --_inInputPointer;
    return Token(type, value);
  }

  Token getNextToken() {
    if (_isOnEndOfInput()) {
      return Token(TokenType.endOfTokens, '\$');
    }

    var current = input[_inInputPointer];
    Token token = switch (current) {
      '(' => Token(TokenType.openParen, current),
      ')' => Token(TokenType.closeParen, current),
      '|' => Token(TokenType.bar, current),
      '+' => Token(TokenType.plus, current),
      '-' => Token(TokenType.minus, current),
      '/' => Token(TokenType.divide, current),
      '*' => Token(TokenType.multiply, current),
      ',' => Token(TokenType.comma, current),
      ' ' => Token(TokenType.whitespace, current),
      _ when current == '=' && peek() == '>' =>
        consume(TokenType.lambda, ['=', '>']),
      '=' => Token(TokenType.equals, current),
      _ when current.isDigit() => _lexDigit(),
      _ when current.isLatinAlphabetical() => _rangeByPredicate(
          TokenType.identifier, (s) => s.isLatinAlphabetical() || s.isDigit()),
      _ => throw LexerException(
          "Unexpected Token in [$runtimeType.getNextToken]: $current")
    };

    _tokens.add(token);
    _inInputPointer++;

    return token;
  }

  Iterable<Token> getTokens() sync* {
    if (_isOnEndOfInput()) {
      yield Token(TokenType.endOfTokens, '\$');
    }

    late Token tok;
    while ((tok = getNextToken()).type != TokenType.endOfTokens) {
      yield tok;
    }
  }

  Stream<Token> getTokenStream() async* {
    yield* Stream.fromIterable(getTokens());
  }
}
