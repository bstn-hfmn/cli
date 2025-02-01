import 'package:cli/tree.dart';
import 'package:cli/tree.parser.dart';

class ParsingException implements Exception {
  String message;
  ParsingException(this.message);
}

class ASTNode extends Node {
  ASTNode({List<ASTNode>? children}) : super(children: children);
}

class Number extends ASTNode {
  final double value;
  Number(this.value);

  @override
  String toString() => 'Number ($value)';
}

class Identifier extends ASTNode {
  final String name;
  Identifier(this.name);

  @override
  String toString() => 'Identifier ($name)';
}

enum BinaryExprOperator { add, subtract, multiply, divide }

class BinaryExpr extends ASTNode {
  final ASTNode left;
  final ASTNode right;
  final BinaryExprOperator operator;

  BinaryExpr(this.left, this.operator, this.right)
      : super(children: [left, right]);

  @override
  String toString() => 'Binary Expression (${operator.name})';
}

class UnaryMinus extends ASTNode {
  final ASTNode operand;
  UnaryMinus(this.operand) : super(children: [operand]);

  @override
  String toString() => 'Unary (-)';
}

class Assignment extends ASTNode {
  final Identifier ident;
  final ASTNode expr;

  Assignment(this.ident, this.expr) : super(children: [ident, expr]);

  @override
  String toString() => 'Assignment';
}

class Call extends ASTNode {
  final Identifier ident;
  final List<ASTNode> arguments;

  Call(this.ident, this.arguments) : super(children: [...arguments]);

  @override
  String toString() => 'Call (${ident.name})';
}

class Lambda extends ASTNode {
  final List<Identifier> parameters;
  final ASTNode body;

  Lambda(this.parameters, this.body) : super(children: [body]);

  @override
  String toString() =>
      'Lambda${parameters.isEmpty ? '' : '(${parameters.map((p) => p.name).join(', ')})'}';
}

class AST extends Tree<ASTNode> {
  AST(super.root);
  AST.from(ParseTree tree) : super(AST._transform(tree.root));

  static List<T> _transformMany<T extends ASTNode>(ParseTreeNode node) {
    bool isNoArgument = node.children.isEmpty;
    if (isNoArgument) return [];

    bool isSingleArgument = node.children.length == 1;
    bool isMultipleArguments = node.children.length == 3;

    if (isSingleArgument) {
      return [_transform(node.children.first as ParseTreeNode) as T];
    }
    if (!isMultipleArguments) return [];

    final arg = _transform(node.children.first as ParseTreeNode) as T;
    final args = _transformMany<T>(node.children.last as ParseTreeNode);

    return [arg, ...args];
  }

  static ASTNode _transform(ParseTreeNode node) {
    final children = node.children.cast<ParseTreeNode>();
    switch (node.name) {
      case 'Stmt':
        {
          if (node.children.isNotEmpty) {
            return _transform(children.first);
          }
        }
        break;

      case 'Assignment':
        {
          bool isValidAssignment = node.children.length == 3;
          if (!isValidAssignment) break;

          final ident = _transform(children.first);
          return Assignment(ident as Identifier, _transform(children.last));
        }

      case 'Lambda':
        {
          final params = children[1];
          final expr = _transform(children.last);

          bool isLambdaWithoutArguments = params.children.isEmpty;
          if (isLambdaWithoutArguments) return Lambda([], expr);

          return Lambda(_transformMany<Identifier>(params), expr);
        }

      case 'Call':
        {
          bool isCallWithArguments = children[2].children.isNotEmpty;
          bool isCallWithoutArguments = children[2].children.isEmpty;

          final ident = _transform(children.first) as Identifier;

          if (isCallWithoutArguments) return Call(ident, []);
          if (!isCallWithArguments) break;

          return Call(ident, _transformMany(children[2]));
        }

      case 'Term':
      case 'Expr':
        {
          bool isBinaryExprNode = children.length == 3;
          bool isImmediateReduction = children.length == 1;

          if (isImmediateReduction) {
            return _transform(children.first);
          }

          if (isBinaryExprNode) {
            final left = _transform(children.first);
            final right = _transform(children.last);

            final operator = switch ((children[1]).value!) {
              '+' => BinaryExprOperator.add,
              '-' => BinaryExprOperator.subtract,
              '*' => BinaryExprOperator.multiply,
              '/' => BinaryExprOperator.divide,
              _ =>
                throw ParsingException("Unexpected operator in ${node.name}."),
            };

            return BinaryExpr(left, operator, right);
          }
        }
        break;

      case 'Factor':
        {
          bool isImmediateNumber = children.length == 1;
          if (isImmediateNumber) {
            return _transform(children.first);
          }

          bool isUnaryFactor = children.length == 2;
          if (isUnaryFactor) {
            return UnaryMinus(_transform(children[1]));
          }

          bool isParenthesizedExpression = children.length == 3;
          if (isParenthesizedExpression) {
            return _transform(children[1]);
          }
        }
        break;

      case 'Number':
        return Number(double.parse(node.value!));
      case 'Identifier':
        return Identifier(node.value!);
    }

    throw ParsingException('Unexpected node in AST: ${node.toString()}.');
  }
}
