class Node {
  List<Node> children = [];
  Node({List<Node>? children}) {
    this.children = children ?? [];
  }

  @override
  String toString() => 'Node (${children.length} children)';
}

abstract class Tree<T extends Node> {
  final T root;
  const Tree(this.root);

  String stringify(
    Node node, {
    bool isLastNode = false,
    List<bool> previousLastNodes = const [],
  }) {
    String result = '';
    final prefix =
        previousLastNodes.map((isLast) => isLast ? ' ' : '¦ ').join() +
            (isLastNode ? '`- ' : '|- ');

    result += '$prefix${node.toString()}\n';
    result += node.children.indexed.map((child) {
      final (int index, Node value) = child;
      final isLastChild = index == node.children.length - 1;
      return stringify(
        value,
        isLastNode: isLastChild,
        previousLastNodes: [
          ...previousLastNodes,
          previousLastNodes.isEmpty ? true : isLastNode
        ],
      );
    }).join();

    return result;
  }

  @override
  String toString() => stringify(root);
}
