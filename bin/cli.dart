import 'dart:io';
import 'dart:math';

import 'package:cli/grammar.dart';
import 'package:cli/grammar.lr.dart';
import 'package:cli/lexer.dart';
import 'package:cli/tree.ast.dart';
import 'package:cli/tree.parser.dart';

class RuntimeException implements Exception {
  String message;
  RuntimeException(this.message);
}

const builtinIdentifiers = {'pi': 3.14, 'e': 2.718281828};
final builtinFunctions = {
  'sqrt': (List<double> args) => sqrt(args.first),
  'cos': (List<double> args) => cos(args.first),
  'sin': (List<double> args) => sin(args.first),
  'abs': (List<double> args) => args.first < 0 ? -args.first : args.first,
};

final Map<String, Context> contexts = {'global': Context()};
final Map<String, double Function(List<double>)> registedFunctions = {};

class Context {
  final Map<String, double> identifiers = {};
}

dynamic eval(ASTNode node, Context context) {
  switch (node) {
    case BinaryExpr expr:
      {
        try {
          final left = eval(expr.left, context) as double;
          final right = eval(expr.right, context) as double;

          final value = switch (expr.operator) {
            BinaryExprOperator.add => left + right,
            BinaryExprOperator.subtract => left - right,
            BinaryExprOperator.multiply => left * right,
            BinaryExprOperator.divide => left / right,
          };

          return value;
        } catch (_) {
          throw RuntimeException(
              'Failed to evaluate binary expression, either identifier didn\'t exist or tried to add two incompatible types.');
        }
      }

    case Assignment assignment:
      {
        switch (assignment.expr) {
          case Lambda lambda:
            {
              contexts[assignment.ident.name] = Context();
              final ctx = contexts[assignment.ident.name];
              for (final parameter in lambda.parameters) {
                ctx!.identifiers[parameter.name] = 0;
              }

              registedFunctions[assignment.ident.name] = (final list) {
                if (list.length < lambda.parameters.length ||
                    list.length > lambda.parameters.length) {
                  throw RuntimeException(
                      'Tried too call functions with incorrect number of arguments');
                }

                int i = 0;
                for (final p in lambda.parameters) {
                  ctx!.identifiers[p.name] = list[i++];
                }

                return eval(lambda.body, ctx!);
              };

              return '<Function \'${assignment.ident.name}\'>';
            }

          default:
            {
              context.identifiers[assignment.ident.name] =
                  eval(assignment.expr, context);

              return '<Identifier \'${assignment.ident.name}\'>';
            }
        }
      }

    case Call call:
      {
        List<double> evaluated = [];
        for (final argument in call.arguments) {
          evaluated.add(eval(argument, context) as double);
        }

        if (builtinFunctions.containsKey(call.ident.name)) {
          if (evaluated.length > 1) {
            throw RuntimeException(
                'Tried to call function \'${call.ident.name}\' with ${evaluated.length} arguments.');
          }

          return builtinFunctions[call.ident.name]!(evaluated);
        } else if (registedFunctions.containsKey(call.ident.name)) {
          return registedFunctions[call.ident.name]!(evaluated);
        }

        throw RuntimeException('Unknown Function \'${call.ident.name}\'');
      }

    case Identifier ident:
      {
        if (builtinIdentifiers.containsKey(ident.name)) {
          return builtinIdentifiers[ident.name]!;
        } else if (builtinFunctions.containsKey(ident.name)) {
          return '<Builtin-Function \'${ident.name}\'>';
        }

        if (context.identifiers.containsKey(ident.name)) {
          return context.identifiers[ident.name]!;
        } else if (registedFunctions.containsKey(ident.name)) {
          return '<Function \'${ident.name}\'>';
        }

        throw RuntimeException('Unknown Identifier \'${ident.name}\'');
      }

    case UnaryMinus unary:
      return -(eval(unary.operand, context) as double);

    case Number number:
      return number.value;
  }

  return 0.0;
}

void main() {
  final grammar = GrammarLR.fromRules([
    GrammarRule('Stmt', ['Expr']),
    GrammarRule('Stmt', ['Assignment']),
    GrammarRule('Expr', ['Term']),
    GrammarRule('Expr', ['Expr', '+', 'Term']),
    GrammarRule('Expr', ['Expr', '-', 'Term']),
    GrammarRule('Term', ['Factor']),
    GrammarRule('Term', ['Term', '*', 'Factor']),
    GrammarRule('Term', ['Term', '/', 'Factor']),
    GrammarRule('Factor', ['Number']),
    GrammarRule('Factor', ['Identifier']),
    GrammarRule('Factor', ['-', 'Factor']),
    GrammarRule('Factor', ['(', 'Expr', ')']),
    GrammarRule('Factor', ['Call']),
    GrammarRule('Call', ['Identifier', '(', 'Args', ')']),
    GrammarRule('Args', []),
    GrammarRule('Args', ['Expr']),
    GrammarRule('Args', ['Expr', ',', 'Args']),
    GrammarRule('Assignment', ['Identifier', '=', 'Expr']),
    GrammarRule('Assignment', ['Identifier', '=', 'Lambda']),
    GrammarRule('Lambda', ['|', 'Params', '|', '=>', 'Expr']),
    GrammarRule('Params', []),
    GrammarRule('Params', ['Identifier']),
    GrammarRule('Params', ['Identifier', ',', 'Params'])
  ]);

  print('Compiling grammar...');
  final sw = Stopwatch()..start();
  grammar.compile();
  sw.stop();

  print(
      'Grammar compilation for ${grammar.states.length} states took ${sw.elapsedMilliseconds}ms.');

  final Map<TokenType, String> transformer = {
    TokenType.plus: '+',
    TokenType.minus: '-',
    TokenType.comma: ',',
    TokenType.equals: '=',
    TokenType.divide: '/',
    TokenType.multiply: '*',
    TokenType.openParen: '(',
    TokenType.closeParen: ')',
    TokenType.whitespace: ' ',
    TokenType.bar: '|',
    TokenType.lambda: '=>',
    TokenType.number: 'Number',
    TokenType.identifier: 'Identifier',
    TokenType.endOfTokens: Grammar.endOfInput
  };

  var mode = 'eval';
  final parser = Parser(grammar)..skip([TokenType.whitespace]);

  while (true) {
    stdout.write('> ');
    final input = stdin.readLineSync()?.trimLeft();
    if (input == null) break;
    if (input.isEmpty) continue;

    if (input == 'q') break;
    if (input == 'help') {
      print('LR-REPL Learning Project');
      print('Supported Operations:');
      print('\t  Variables:   x = 5 * 5');
      print('\t  Functions:   x = |a, b| => a * b');
      print('\t      Calls:   sqrt(x)');
      print('\tExpressions:   1 + sqrt(2) * (3 + 4) / 5 -(-x(6, 7))\n');

      print('Commands:');
      print('\t help: shows this message');
      print('\t   q: quits the aplication');
      print('\tmode: sets the preview mode (\'ast\' or \'eval\')');
      continue;
    }
    if (input.startsWith('mode')) {
      final parts = input.split(' ');
      if (parts.length != 2) {
        print('Invalid command mode <ast|eval>');
        continue;
      }

      final wanted = parts[1];
      if (wanted == 'eval' || wanted == 'ast') {
        mode = wanted;
      } else {
        print('Invalid command mode <ast|eval>');
        continue;
      }

      continue;
    }

    final lexer = Lexer(input);
    try {
      final tree = parser.parse(lexer.getTokens().toList(), transformer);
      final ast = AST.from(tree);

      if (mode == 'eval') print(eval(ast.root, contexts['global']!));
      if (mode == 'ast') print(ast);
    } on ParsingException catch (e) {
      print(e.message);
    } on LexerException catch (e) {
      print(e.message);
    } on RuntimeException catch (e) {
      print(e.message);
    } catch (e) {
      print(e);
      break;
    }
  }
}
