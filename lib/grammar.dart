import 'dart:collection';
import 'package:cli/grammar.lr.dart';
import 'package:cli/utilities.dart';
import 'package:collection/collection.dart';

sealed class Action {
  final GrammarRule rule;
  const Action(this.rule);
}

class Reduction extends Action {
  const Reduction(super.rule);

  @override
  String toString() => 'reduce($rule)';
}

class Shift extends Action {
  final int toState;
  const Shift(super.rule, this.toState);

  @override
  String toString() => 'shift($toState)';
}

class Accept extends Action {
  const Accept(super.rule);

  @override
  String toString() => 'accept';
}

mixin GrammarProcessor {
  List<GrammarParsingState>? _cachedStates;
  List<GrammarParsingState> get states => _cachedStates ??=
      throw Exception("You need to compile the grammar first.");

  GrammarParsingTables? _cachedTables;
  GrammarParsingTables get tables => _cachedTables ??=
      throw Exception("You need to compile the grammar first.");

  bool get isCompiled => _cachedStates != null && _cachedTables != null;
  bool get isNotCompiled => !isCompiled;

  GrammarParsingTables table();
  List<GrammarParsingState> automaton();

  void compile() {
    if (isCompiled) return;

    _cachedStates ??= automaton();
    _cachedTables ??= table();
  }
}

class GrammarParsingTables {
  final Map<(int state, String symbol), int> gotos;
  final Map<(int state, String lookahead), Action> actions;

  const GrammarParsingTables({this.gotos = const {}, this.actions = const {}});

  bool get isNotEmpty => !isEmpty;
  bool get isEmpty => gotos.isEmpty && actions.isEmpty;
}

class GrammarRule with HashedEquatable {
  late String symbol;
  late List<String> products;

  GrammarRule(this.symbol, this.products);

  @override
  String toString() =>
      '$symbol -> ${products.isEmpty ? 'ε' : products.join(' ')}';

  @override
  int get hash => Object.hashAll([symbol, ...products]);
}

class StatefulGrammarRule with HashedEquatable {
  final int dot;
  final GrammarRule rule;
  final Set<String> lookaheads;

  bool get isOnEndOfRule => dot >= rule.products.length;
  String? get symbolAfterDot => isOnEndOfRule ? null : rule.products[dot];
  String get symbol => rule.symbol;
  List<String> get products => rule.products;

  StatefulGrammarRule(this.rule, {this.dot = 0, this.lookaheads = const {}});

  @override
  String toString() => '${rule.symbol} -> '
      '${rule.products.isEmpty ? 'ε' : rule.products.indexed.map((e) => e.$1 == dot ? '●${e.$2}' : e.$2).join(' ')}'
      '${(rule.products.isNotEmpty && isOnEndOfRule) ? ('●, ${lookaheads.join('/')}') : (', ${lookaheads.join('/')}')}';

  @override
  int get hash => Object.hashAll([rule, dot, ...lookaheads]);
}

class GrammarParsingState with HashedEquatable {
  final List<StatefulGrammarRule> kernel;
  GrammarParsingState(this.kernel);

  @override
  String toString() => kernel.join('\n');

  @override
  int get hash => Object.hashAll(
      kernel.map((r) => r.hashCode).sorted((a, b) => a.compareTo(b)));
}

enum GrammarSymbolType { terminal, nonTerminal }

abstract class Grammar {
  static const String start = 'S\'';
  static const String epsilon = 'ε';
  static const String endOfInput = '\$';

  List<GrammarRule> get rules => _rules;
  late final List<GrammarRule> _rules = List.empty(growable: true);

  final Map<int, Set<String>> _symbolListToFirstSet = {};
  final Map<String, GrammarSymbolType> _symbolToType = {};
  final Map<String, Iterable<GrammarRule>> _symbolToRules = {};

  Grammar();
  Grammar.fromRules(List<GrammarRule> rules) {
    _rules.addAll(rules);
  }

  factory Grammar.lr({List<GrammarRule>? rules}) =>
      rules != null ? GrammarLR.fromRules(rules) : GrammarLR();

  void augument() =>
      _rules.insert(0, GrammarRule(Grammar.start, [_rules.first.symbol]));

  void addProductionRules(List<GrammarRule> rules) => _rules.addAll(rules);
  void addProductionRule(String symbol, List<String> products) =>
      addProductionRules([GrammarRule(symbol, products)]);

  Set<String> getFirstSetOf(String symbol) {
    if (isTerminal(symbol)) return {symbol};

    var set = <String>{};
    final associated = getRulesBySymbol(symbol);
    for (final rule in associated) {
      set = set.union(getFirstSet(rule.products));
    }

    return set;
  }

  Set<String> getFirstSet(List<String> symbols) {
    if (symbols.isEmpty) return {};
    if (isTerminal(symbols.first)) return {symbols.first};

    final hash = Object.hashAll(symbols);
    if (_symbolListToFirstSet.containsKey(hash)) {
      return _symbolListToFirstSet[hash]!;
    }

    var set = <String>{};
    bool allSymbolsCanProduceEpsilon = true;
    for (final symbol in symbols) {
      if (isTerminal(symbol)) {
        set.add(symbol);
        allSymbolsCanProduceEpsilon = false;
        break;
      }

      var associated = getRulesBySymbol(symbol);
      bool canRuleProductEpsilon = false;

      for (final rule in associated) {
        if (rule.products.first == symbol) continue;
        final ruleFirstSet = getFirstSet(rule.products);
        set =
            set.union(ruleFirstSet.where((s) => s != Grammar.epsilon).toSet());

        bool canPartialRuleProductEpsilon =
            ruleFirstSet.any((s) => s == Grammar.epsilon);
        if (canPartialRuleProductEpsilon) {
          canRuleProductEpsilon = true;
        }
      }

      if (!canRuleProductEpsilon) {
        allSymbolsCanProduceEpsilon = false;
        break;
      }
    }

    if (allSymbolsCanProduceEpsilon) set.add(Grammar.epsilon);

    _symbolListToFirstSet[hash] = set;
    return _symbolListToFirstSet[hash]!;
  }

  Set<String> getFollowSet(String symbol) {
    var set = <String>{};
    if (isTerminal(symbol)) return {};
    if (rules.first.symbol == symbol) set.add('\$');

    final associated = rules.where((r) => r.products.contains(symbol));
    for (final rule in associated) {
      final indexInRule = rule.products.indexOf(symbol);

      bool isSameRule = symbol == rule.symbol;
      bool isRuleExhausted = indexInRule + 1 >= rule.products.length;
      if (isRuleExhausted) {
        if (isSameRule) continue;
        set = set.union(getFollowSet(rule.symbol));
      } else {
        final nextSymbol = rule.products[indexInRule + 1];
        final firstSetOfNextSymbol = getFirstSetOf(nextSymbol);
        if (firstSetOfNextSymbol.contains(Grammar.epsilon)) {
          if (isSameRule) continue;
          set = set.union(getFollowSet(rule.symbol));
        }

        set = set.union(
            firstSetOfNextSymbol.where((s) => s != Grammar.epsilon).toSet());
      }
    }

    return set;
  }

  Iterable<GrammarRule> getRulesBySymbol(String symbol) {
    return _symbolToRules.putIfAbsent(
        symbol, () => rules.where((r) => r.symbol == symbol));
  }

  bool isSymbolOfType(String symbol, GrammarSymbolType type) {
    return _symbolToType.putIfAbsent(
            symbol,
            () => _rules.any((r) => r.symbol == symbol)
                ? GrammarSymbolType.nonTerminal
                : GrammarSymbolType.terminal) ==
        type;
  }

  bool isTerminal(String symbol) =>
      isSymbolOfType(symbol, GrammarSymbolType.terminal);

  bool isNonTerminal(String symbol) =>
      isSymbolOfType(symbol, GrammarSymbolType.nonTerminal);

  @override
  String toString() => rules
      .map((r) =>
          '${r.symbol} -> ${r.products.map((p) => isTerminal(p) ? '\'$p\'' : p).join(' ')}')
      .join('\n');
}
