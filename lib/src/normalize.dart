import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';

class NormalizedNode {
  NormalizedNode(this.kind, {this.label, List<NormalizedNode>? children})
    : children = children ?? const [];

  final String kind;
  final String? label;
  final List<NormalizedNode> children;
}

typedef ComparableDeclaration = ({AstNode node, int startLine, int endLine});

class FileParse {
  FileParse({required this.declarations, required this.errors});

  final List<ComparableDeclaration> declarations;
  final List<String> errors;
}

/// Parses [source] and extracts the declarations dry4dart compares.
FileParse parseDartSource(String source, String path) {
  final result = parseString(
    content: source,
    path: path,
    throwIfDiagnostics: false,
  );
  final lineInfo = result.lineInfo;
  final declarations = <ComparableDeclaration>[];
  for (final node in _extractComparableDeclarations(result.unit)) {
    declarations.add((
      node: node,
      startLine: lineInfo.getLocation(node.offset).lineNumber,
      endLine: lineInfo.getLocation(node.end).lineNumber,
    ));
  }
  final errors = result.errors.map((e) => e.message).toList();
  return FileParse(declarations: declarations, errors: errors);
}

Iterable<AstNode> _extractComparableDeclarations(CompilationUnit unit) sync* {
  for (final decl in unit.declarations) {
    if (decl is FunctionDeclaration) {
      yield decl;
    } else if (decl is TopLevelVariableDeclaration) {
      yield decl;
    } else if (decl is ClassDeclaration ||
        decl is MixinDeclaration ||
        decl is ExtensionDeclaration ||
        decl is EnumDeclaration ||
        decl is ExtensionTypeDeclaration) {
      yield* _classLikeMembers(decl);
    }
  }
}

Iterable<AstNode> _classLikeMembers(CompilationUnitMember decl) sync* {
  final members = _membersOf(decl);
  for (final member in members) {
    if (member is MethodDeclaration ||
        member is ConstructorDeclaration ||
        member is PrimaryConstructorBody ||
        member is FieldDeclaration) {
      yield member;
    }
  }
}

List<ClassMember> _membersOf(CompilationUnitMember decl) {
  if (decl is ClassDeclaration) return decl.body.members;
  if (decl is MixinDeclaration) return decl.body.members;
  if (decl is ExtensionDeclaration) return decl.body.members;
  if (decl is EnumDeclaration) return decl.body.members;
  if (decl is ExtensionTypeDeclaration) return decl.body.members;
  return const [];
}

NormalizedNode normalize(AstNode node) => _Normalizer().visit(node);

class _Normalizer {
  NormalizedNode visit(AstNode node) {
    if (node is FunctionDeclaration) {
      return NormalizedNode(
        'function-decl',
        children: [
          if (node.returnType != null) visit(node.returnType!),
          visit(node.functionExpression),
        ],
      );
    }
    if (node is MethodDeclaration) {
      final children = <NormalizedNode>[];
      if (node.returnType != null) children.add(visit(node.returnType!));
      if (node.parameters != null) children.add(visit(node.parameters!));
      children.add(visit(node.body));
      return NormalizedNode('method-decl', children: children);
    }
    if (node is ConstructorDeclaration) {
      final children = <NormalizedNode>[visit(node.parameters)];
      for (final init in node.initializers) {
        children.add(visit(init));
      }
      children.add(visit(node.body));
      return NormalizedNode('constructor-decl', children: children);
    }
    if (node is PrimaryConstructorBody) {
      // Mirror the constructor-decl shape so a primary constructor body
      // compares against an equivalent classic constructor.
      final children = <NormalizedNode>[];
      final declaration = node.declaration;
      if (declaration != null) {
        children.add(visit(declaration.formalParameters));
      }
      for (final init in node.initializers) {
        children.add(visit(init));
      }
      children.add(visit(node.body));
      return NormalizedNode('constructor-decl', children: children);
    }
    if (node is TopLevelVariableDeclaration) {
      return NormalizedNode('top-var-decl', children: [visit(node.variables)]);
    }
    if (node is FieldDeclaration) {
      return NormalizedNode('field-decl', children: [visit(node.fields)]);
    }
    if (node is VariableDeclarationList) {
      final children = <NormalizedNode>[];
      if (node.type != null) children.add(visit(node.type!));
      for (final v in node.variables) {
        children.add(_variableDecl(v));
      }
      return NormalizedNode('var-list', children: children);
    }
    if (node is FunctionExpression) {
      final children = <NormalizedNode>[];
      if (node.parameters != null) children.add(visit(node.parameters!));
      children.add(visit(node.body));
      return NormalizedNode('function-expr', children: children);
    }
    if (node is BlockFunctionBody) {
      return NormalizedNode('block-body', children: [visit(node.block)]);
    }
    if (node is ExpressionFunctionBody) {
      return NormalizedNode('expr-body', children: [visit(node.expression)]);
    }
    if (node is EmptyFunctionBody) {
      return NormalizedNode('empty-body');
    }
    if (node is FormalParameterList) {
      return NormalizedNode(
        'params',
        children: node.parameters.map(_formalParameter).toList(),
      );
    }

    if (node is Block) {
      return NormalizedNode(
        'block',
        children: node.statements.map(visit).toList(),
      );
    }
    if (node is ExpressionStatement) {
      return NormalizedNode('expr-stmt', children: [visit(node.expression)]);
    }
    if (node is ReturnStatement) {
      final children = <NormalizedNode>[];
      if (node.expression != null) children.add(visit(node.expression!));
      return NormalizedNode('return', children: children);
    }
    if (node is IfStatement) {
      final children = <NormalizedNode>[
        visit(node.expression),
        visit(node.thenStatement),
      ];
      if (node.elseStatement != null) children.add(visit(node.elseStatement!));
      return NormalizedNode('if', children: children);
    }
    if (node is ForStatement) {
      return NormalizedNode(
        'for',
        children: [visit(node.forLoopParts), visit(node.body)],
      );
    }
    if (node is WhileStatement) {
      return NormalizedNode(
        'while',
        children: [visit(node.condition), visit(node.body)],
      );
    }
    if (node is DoStatement) {
      return NormalizedNode(
        'do-while',
        children: [visit(node.body), visit(node.condition)],
      );
    }
    if (node is VariableDeclarationStatement) {
      return NormalizedNode('var-decl-stmt', children: [visit(node.variables)]);
    }
    if (node is BreakStatement) return NormalizedNode('break');
    if (node is ContinueStatement) return NormalizedNode('continue');
    if (node is YieldStatement) {
      return NormalizedNode(
        node.star != null ? 'yield-star' : 'yield',
        children: [visit(node.expression)],
      );
    }
    if (node is SwitchStatement) {
      final children = <NormalizedNode>[visit(node.expression)];
      for (final m in node.members) {
        children.add(visit(m));
      }
      return NormalizedNode('switch', children: children);
    }
    if (node is SwitchCase) {
      final children = <NormalizedNode>[visit(node.expression)];
      for (final s in node.statements) {
        children.add(visit(s));
      }
      return NormalizedNode('switch-case', children: children);
    }
    if (node is SwitchDefault) {
      return NormalizedNode(
        'switch-default',
        children: node.statements.map(visit).toList(),
      );
    }
    if (node is TryStatement) {
      final children = <NormalizedNode>[visit(node.body)];
      for (final c in node.catchClauses) {
        children.add(visit(c));
      }
      if (node.finallyBlock != null) children.add(visit(node.finallyBlock!));
      return NormalizedNode('try', children: children);
    }
    if (node is CatchClause) {
      final children = <NormalizedNode>[];
      if (node.exceptionType != null) children.add(visit(node.exceptionType!));
      children.add(visit(node.body));
      return NormalizedNode('catch', children: children);
    }

    if (node is BinaryExpression) {
      return NormalizedNode(
        'binary',
        label: node.operator.lexeme,
        children: [visit(node.leftOperand), visit(node.rightOperand)],
      );
    }
    if (node is PrefixExpression) {
      return NormalizedNode(
        'prefix',
        label: node.operator.lexeme,
        children: [visit(node.operand)],
      );
    }
    if (node is PostfixExpression) {
      return NormalizedNode(
        'postfix',
        label: node.operator.lexeme,
        children: [visit(node.operand)],
      );
    }
    if (node is AssignmentExpression) {
      return NormalizedNode(
        'assign',
        label: node.operator.lexeme,
        children: [visit(node.leftHandSide), visit(node.rightHandSide)],
      );
    }
    if (node is ConditionalExpression) {
      return NormalizedNode(
        'conditional',
        children: [
          visit(node.condition),
          visit(node.thenExpression),
          visit(node.elseExpression),
        ],
      );
    }
    if (node is MethodInvocation) {
      final receiver = node.target;
      return NormalizedNode(
        'method-call',
        label: node.methodName.name,
        children: [
          receiver != null ? visit(receiver) : NormalizedNode('no-target'),
          visit(node.argumentList),
        ],
      );
    }
    if (node is FunctionExpressionInvocation) {
      return NormalizedNode(
        'fn-call',
        children: [visit(node.function), visit(node.argumentList)],
      );
    }
    if (node is InstanceCreationExpression) {
      return NormalizedNode(
        'new',
        label: _constructorLabel(node.constructorName),
        children: [visit(node.argumentList)],
      );
    }
    if (node is PropertyAccess) {
      final receiver = node.target;
      return NormalizedNode(
        'property',
        label: node.propertyName.name,
        children: [
          receiver != null ? visit(receiver) : NormalizedNode('no-target'),
        ],
      );
    }
    if (node is PrefixedIdentifier) {
      return NormalizedNode(
        'property',
        label: node.identifier.name,
        children: [NormalizedNode('ref')],
      );
    }
    if (node is IndexExpression) {
      return NormalizedNode(
        'index',
        children: [visit(node.realTarget), visit(node.index)],
      );
    }
    if (node is CascadeExpression) {
      final children = <NormalizedNode>[visit(node.target)];
      for (final s in node.cascadeSections) {
        children.add(visit(s));
      }
      return NormalizedNode('cascade', children: children);
    }
    if (node is AwaitExpression) {
      return NormalizedNode('await', children: [visit(node.expression)]);
    }
    if (node is ThrowExpression) {
      return NormalizedNode('throw', children: [visit(node.expression)]);
    }
    if (node is ArgumentList) {
      return NormalizedNode(
        'args',
        children: node.arguments.map(visit).toList(),
      );
    }
    if (node is NamedArgument) {
      return NormalizedNode(
        'named-arg',
        label: node.name.lexeme,
        children: [visit(node.argumentExpression)],
      );
    }
    if (node is RecordLiteralNamedField) {
      return NormalizedNode(
        'named-arg',
        label: node.name.lexeme,
        children: [visit(node.fieldExpression)],
      );
    }
    if (node is ParenthesizedExpression) {
      return visit(node.expression);
    }
    if (node is ListLiteral) {
      return NormalizedNode(
        'list-lit',
        children: node.elements.map(visit).toList(),
      );
    }
    if (node is SetOrMapLiteral) {
      final isMap = node.elements.any((e) => e is MapLiteralEntry);
      return NormalizedNode(
        isMap ? 'map-lit' : 'set-lit',
        children: node.elements.map(visit).toList(),
      );
    }
    if (node is MapLiteralEntry) {
      return NormalizedNode(
        'map-entry',
        children: [visit(node.key), visit(node.value)],
      );
    }
    if (node is RecordLiteral) {
      return NormalizedNode(
        'record-lit',
        children: node.fields.map(visit).toList(),
      );
    }
    if (node is StringInterpolation) {
      // Preserve the interpolated expressions, drop the literal text segments.
      final exprs = <NormalizedNode>[];
      for (final el in node.elements) {
        if (el is InterpolationExpression) {
          exprs.add(visit(el.expression));
        }
      }
      return NormalizedNode('string-interp', children: exprs);
    }
    if (node is BooleanLiteral ||
        node is IntegerLiteral ||
        node is DoubleLiteral ||
        node is StringLiteral ||
        node is NullLiteral ||
        node is SymbolLiteral) {
      return NormalizedNode('literal');
    }
    if (node is ThisExpression) return NormalizedNode('this');
    if (node is SuperExpression) return NormalizedNode('super');
    if (node is SimpleIdentifier) return NormalizedNode('ref');

    if (node is NamedType) {
      final children = <NormalizedNode>[];
      final typeArgs = node.typeArguments;
      if (typeArgs != null) {
        for (final t in typeArgs.arguments) {
          children.add(visit(t));
        }
      }
      return NormalizedNode(
        'type',
        label: _namedTypeLabel(node),
        children: children,
      );
    }

    return _generic(node);
  }

  NormalizedNode _variableDecl(VariableDeclaration v) {
    final children = <NormalizedNode>[];
    if (v.initializer != null) children.add(visit(v.initializer!));
    return NormalizedNode('var-init', children: children);
  }

  NormalizedNode _formalParameter(FormalParameter p) {
    final children = <NormalizedNode>[];
    if (p.type != null) children.add(visit(p.type!));
    final suffix = p.functionTypedSuffix;
    if (suffix != null) children.add(visit(suffix.formalParameters));
    final param = NormalizedNode('param', children: children);
    final isDelimited = p.isNamed || p.isOptionalPositional;
    if (!isDelimited) return param;
    // Analyzer versions before 13 wrapped every parameter declared inside
    // `{}` or `[]` in a separate DefaultFormalParameter node, whether or not
    // it had a default value. Keep that shape so fingerprints stay stable.
    final defaultClause = p.defaultClause;
    return NormalizedNode(
      'param',
      children: [param, if (defaultClause != null) visit(defaultClause.value)],
    );
  }

  String _constructorLabel(ConstructorName name) {
    final buf = StringBuffer(_namedTypeLabel(name.type));
    final named = name.name;
    if (named != null) {
      buf
        ..write('.')
        ..write(named.name);
    }
    return buf.toString();
  }

  String _namedTypeLabel(NamedType type) => type.name.lexeme;

  NormalizedNode _generic(AstNode node) {
    final children = <NormalizedNode>[];
    for (final entity in node.childEntities) {
      if (entity is AstNode) {
        children.add(visit(entity));
      }
    }
    var name = node.runtimeType.toString();
    if (name.endsWith('Impl')) {
      name = name.substring(0, name.length - 4);
    }
    return NormalizedNode(name, children: children);
  }
}
