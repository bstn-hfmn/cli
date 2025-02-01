import 'package:cli/extensions.dart';
import 'package:cli/grammar.dart';
import 'package:cli/lexer.dart';
import 'package:cli/tree.ast.dart';
import 'package:cli/tree.dart';
import 'package:cli/utilities.dart';

class ParseTreeNode extends Node {
  String name;
  String? value;

  ParseTreeNode(this.name, {this.value});

  @override
  String toString() =>
      '$name ${value != null && value!.isDigit() ? '($value)' : ''}';
}

class ParseTree extends Tree<ParseTreeNode> {
  ParseTree(super.root);
}

class Parser {
  final GrammarProcessor grammar;

  final List<TokenType> _skip = [];

  Parser(this.grammar);

  void skip(List<TokenType> values) => _skip.addAll(values);

  ParseTree parse(List<Token> tokens, Map<TokenType, String> transformer) {
    if (grammar.isNotCompiled) grammar.compile();
    final states = Stack<int>()..push(0);
    final nodes = Stack<ParseTreeNode>();
    final evaluated = <String>[];

    final iterator = tokens.iterator;
    if (!iterator.moveNext()) return ParseTree(ParseTreeNode('Empty'));

    Token current = iterator.current;
    void next() {
      current = iterator.moveNext()
          ? iterator.current
          : Token(TokenType.endOfTokens, Grammar.endOfInput);
    }

    while (_skip.contains(current.type)) {
      next();
    }

    bool wasInAccept = false;
    bool hasFurtherActions = false;
    do {
      if (_skip.contains(current.type)) {
        next();
        continue;
      }

      final lookahead = transformer[current.type]!;
      hasFurtherActions =
          grammar.tables.actions.containsKey((states.head, lookahead));
      if (!hasFurtherActions) break;

      final action = grammar.tables.actions[(states.head, lookahead)]!;
      switch (action) {
        case Shift shift:
          {
            nodes.push(ParseTreeNode(lookahead, value: current.value));

            evaluated.add(lookahead);
            states.push(shift.toState);
            next();
          }
          break;

        case Reduction reduction:
          {
            states.popMany(reduction.rule.products.length);
            hasFurtherActions = grammar.tables.gotos
                .containsKey((states.head, reduction.rule.symbol));
            if (!hasFurtherActions) break;

            states.push(
                grammar.tables.gotos[(states.head, reduction.rule.symbol)]!);

            if (reduction.rule.products.isNotEmpty) {
              evaluated.replaceFirstSequence(
                  reduction.rule.products, reduction.rule.symbol,
                  reverse: true);
            } else {
              evaluated.add(reduction.rule.symbol);
            }

            final node = ParseTreeNode(reduction.rule.symbol);
            node.children.addAll(nodes
                .popMany(reduction.rule.products.length)
                .toList()
                .reversed);

            nodes.push(node);
          }
          break;
        case Accept _:
          {
            hasFurtherActions = false;
            wasInAccept = true;
          }
          break;
      }
    } while (hasFurtherActions);

    if (!wasInAccept) {
      final expected = grammar.states[states.head].kernel
          .map((k) => k.symbolAfterDot ?? k.lookaheads.first)
          .toSet()
          .join('  ');

      throw ParsingException(
          'Unexpected Token [$runtimeType.parse]:\n \'${current.type.name}\', expected: [$expected]');
    }

    return ParseTree(nodes.first);
  }
}
