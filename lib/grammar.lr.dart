import 'dart:collection';
import 'package:cli/grammar.dart';

class GrammarLR extends Grammar with GrammarProcessor {
  final Map<(int, String), int> transitions = {};

  GrammarLR();
  GrammarLR.fromRules(super.rules) : super.fromRules();

  GrammarParsingState _closure(GrammarParsingState initial) {
    final queue = Queue<StatefulGrammarRule>();
    queue.addAll(initial.kernel);

    final used = <GrammarRule, Set<String>>{};
    while (queue.isNotEmpty) {
      final stateful = queue.removeFirst();
      bool hasNoProductAfterDot = stateful.symbolAfterDot == null;
      bool isProductAfterDotTerminal = stateful.symbolAfterDot != null &&
          isTerminal(stateful.symbolAfterDot!);

      if (hasNoProductAfterDot || isProductAfterDotTerminal) continue;

      final symbolsAfterDot = stateful.products.skip(stateful.dot + 1).toList()
        ..add(stateful.lookaheads.first);

      final lookaheads = getFirstSet(symbolsAfterDot);
      final associated = getRulesBySymbol(stateful.symbolAfterDot!);
      for (final rule in associated) {
        for (final lookahead in lookaheads) {
          if (used.containsKey(rule)) {
            if (!used[rule]!.add(lookahead)) continue;
          } else {
            used[rule] = {lookahead};
          }

          final next =
              StatefulGrammarRule(rule, dot: 0, lookaheads: {lookahead});

          initial.kernel.add(next);
          queue.add(next);
        }
      }
    }

    return initial;
  }

  GrammarParsingState? _goto(GrammarParsingState initial, String toAdvance) {
    final transitioned = initial.kernel
        .where((r) => r.symbolAfterDot == toAdvance)
        .map((r) => StatefulGrammarRule(r.rule,
            dot: r.dot + 1, lookaheads: {...r.lookaheads}))
        .toList();

    return transitioned.isNotEmpty ? GrammarParsingState(transitioned) : null;
  }

  void _addTransition(int index, String symbol, int toState) =>
      transitions[(index, symbol)] = toState;

  @override
  List<GrammarParsingState> automaton() {
    augument();

    final initial = _closure(GrammarParsingState([
      StatefulGrammarRule(rules.first, dot: 0, lookaheads: {Grammar.endOfInput})
    ]));

    final seen = HashSet<String>();
    final states = <GrammarParsingState>[initial];
    final queue = Queue<GrammarParsingState>()..add(initial);

    int index = 0;
    while (queue.isNotEmpty) {
      final state = queue.removeFirst();

      seen.clear();
      for (final rule in state.kernel) {
        if (rule.symbolAfterDot == null) continue;
        if (!seen.add(rule.symbolAfterDot!)) continue;

        final target = _goto(state, rule.symbolAfterDot!)!;
        final inStatesIndex = states.indexOf(target);

        bool didHaveTargetInStates = inStatesIndex != -1;
        if (didHaveTargetInStates) {
          _addTransition(index, rule.symbolAfterDot!, inStatesIndex);
          continue;
        }

        final transitioned = _closure(target);
        states.add(transitioned);
        queue.add(transitioned);

        _addTransition(index, rule.symbolAfterDot!, states.length - 1);
      }

      ++index;
    }

    return states;
  }

  @override
  GrammarParsingTables table() {
    final Map<(int state, String symbol), int> gotos = {};
    final Map<(int state, String lookahead), Action> actions = {};

    for (int i = 0; i < states.length; i++) {
      final state = states[i];

      for (final kernel in state.kernel) {
        if (kernel.isOnEndOfRule) {
          if (kernel.symbol == Grammar.start) {
            actions[(i, Grammar.endOfInput)] = Accept(kernel.rule);
          } else {
            actions[(i, kernel.lookaheads.first)] = Reduction(kernel.rule);
          }
        } else {
          final symbol = kernel.symbolAfterDot!;
          final toStateIndex = transitions[(i, symbol)]!;

          if (isTerminal(symbol)) {
            actions[(i, symbol)] = Shift(kernel.rule, toStateIndex);
          } else {
            gotos[(i, symbol)] = toStateIndex;
          }
        }
      }
    }

    return GrammarParsingTables(actions: actions, gotos: gotos);
  }
}
