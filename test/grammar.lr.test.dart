import 'dart:convert';
import 'dart:io';

import 'package:cli/grammar.dart';
import 'package:cli/grammar.lr.dart';
import 'package:test/test.dart';

Future<List<dynamic>> readSampleStates(String filePath) async {
  var input = await File(filePath).readAsString();
  var map = jsonDecode(input) as Map<String, dynamic>;
  return map['states'];
}

Future<List<dynamic>> readSampleTable(String filePath) async {
  var input = await File(filePath).readAsString();
  var map = jsonDecode(input) as Map<String, dynamic>;
  return map['table'];
}

void main() {
  final simple = GrammarLR.fromRules([
    GrammarRule('Expr', ['Term']),
    GrammarRule('Expr', ['Term', '+', 'Term']),
    GrammarRule('Expr', ['Term', '-', 'Term']),
    GrammarRule('Term', ['Factor']),
    GrammarRule('Term', ['Factor', '*', 'Factor']),
    GrammarRule('Term', ['Factor', '/', 'Factor']),
    GrammarRule('Factor', ['Number']),
    GrammarRule('Factor', ['-', 'Factor']),
    GrammarRule('Factor', ['(', 'Expr', ')'])
  ]);
  simple.compile();

  test('construction of automaton', () async {
    final indexable = simple.states.toList();
    expect(simple.states.length, equals(80));

    final sampleStates = await readSampleStates('./test/automaton.simple.json');

    expect(sampleStates.length, equals(simple.states.length));
    for (int i = 0; i < simple.states.length; i++) {
      final Set<StatefulGrammarRule> parsed = {};

      for (int j = 0; j < indexable[i].kernel.length; j++) {
        final sampleRule = List<String>.from(sampleStates[i][j]['rule']);
        final sampleRuleSymbol = sampleRule.first;
        final sampleRuleProducts = [...sampleRule.skip(1)];

        final rule = StatefulGrammarRule(
            GrammarRule(sampleRuleSymbol, sampleRuleProducts),
            dot: sampleStates[i][j]['dot'],
            lookaheads: {sampleStates[i][j]['lookahead']});

        parsed.add(rule);
      }

      expect(indexable[i].kernel, unorderedEquals(parsed));
    }
  });

  test('construction of parsing table', () async {
    final sampleTable = await readSampleTable('./test/automaton.simple.json');

    for (int i = 0; i < sampleTable.length; i++) {
      final stateIndex = int.parse(sampleTable[i]['State']);
      final gotoActions = <(String, String)>[
        ('Expr', sampleTable[i]['Expr']),
        ('Term', sampleTable[i]['Term']),
        ('Factor', sampleTable[i]['Factor']),
      ]
          .where((g) => g.$2.isNotEmpty)
          .map((g) => (g.$1, int.parse(g.$2)))
          .toList();

      final lookaheadActions = <(String, String)>[
        ('+', sampleTable[i]['+']),
        ('-', sampleTable[i]['-']),
        ('*', sampleTable[i]['*']),
        ('/', sampleTable[i]['/']),
        ('Number', sampleTable[i]['Number']),
        ('(', sampleTable[i]['(']),
        (')', sampleTable[i][')']),
        ('\$', sampleTable[i]['\$'])
      ].where((a) => a.$2.isNotEmpty);

      for (final goto in gotoActions) {
        expect(simple.tables.gotos[(stateIndex, goto.$1)], equals(goto.$2));
      }

      for (final action in lookaheadActions) {
        expect(simple.tables.actions[(stateIndex, action.$1)].toString(),
            equals(action.$2));
      }
    }
  });
}
