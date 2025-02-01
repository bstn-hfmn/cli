import 'package:cli/grammar.dart';
import 'package:cli/grammar.lr.dart';
import 'package:test/test.dart';

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

  test('determine terminals & non-terminals', () {
    expect(simple.isNonTerminal('Expr'), equals(true));
    expect(simple.isNonTerminal('Term'), equals(true));
    expect(simple.isNonTerminal('Factor'), equals(true));
    expect(simple.isNonTerminal('Number'), equals(false));

    expect(simple.isTerminal('Number'), equals(true));
    expect(simple.isTerminal('*'), equals(true));
    expect(simple.isTerminal('/'), equals(true));
    expect(simple.isTerminal('+'), equals(true));
    expect(simple.isTerminal('-'), equals(true));
    expect(simple.isTerminal(')'), equals(true));
    expect(simple.isTerminal('('), equals(true));
    expect(simple.isTerminal('Term'), equals(false));
  });

  test('construction of first sets (simple)', () {
    expect(simple.getFirstSetOf('Expr'), unorderedEquals(['-', 'Number', '(']));
    expect(simple.getFirstSetOf('Term'), unorderedEquals(['-', 'Number', '(']));
    expect(
        simple.getFirstSetOf('Factor'), unorderedEquals(['-', 'Number', '(']));
  });

  test('construction of follow sets (simple)', () {
    expect(simple.getFollowSet('Expr'),
        unorderedEquals([')', Grammar.endOfInput]));
    expect(simple.getFollowSet('Term'),
        unorderedEquals(['+', '-', ')', Grammar.endOfInput]));
    expect(simple.getFollowSet('Factor'),
        unorderedEquals(['+', '-', '*', '/', ')', Grammar.endOfInput]));
  });
}
