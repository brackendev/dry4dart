import 'package:dry4dart/src/normalize.dart';
import 'package:test/test.dart';

import '_helpers.dart';

void main() {
  group('normalize', () {
    test('drops local variable and parameter names', () {
      final left = normalizeSingle('''
int alpha(int xs) {
  final ys = xs + 1;
  return ys;
}
''');
      final right = normalizeSingle('''
int beta(int items) {
  final kept = items + 1;
  return kept;
}
''');
      expect(_renderKinds(left), equals(_renderKinds(right)));
      expect(_renderLabels(left), equals(_renderLabels(right)));
    });

    test('preserves operator labels', () {
      final plus = normalizeSingle('''
int plus(int x) => x + 1;
''');
      final minus = normalizeSingle('''
int minus(int x) => x - 1;
''');
      expect(_renderLabels(plus), isNot(equals(_renderLabels(minus))));
    });

    test('preserves method-call targets', () {
      final whereCall = normalizeSingle('''
Iterable<int> a(Iterable<int> xs) => xs.where(isOdd);
''');
      final mapCall = normalizeSingle('''
Iterable<int> b(Iterable<int> xs) => xs.map(toInt);
''');
      expect(_renderLabels(whereCall), isNot(equals(_renderLabels(mapCall))));
    });

    test('list and map literals are distinguished', () {
      final listLit = normalizeSingle('''
List<int> a() => [1, 2, 3];
''');
      final mapLit = normalizeSingle('''
Map<String, int> b() => {'a': 1, 'b': 2};
''');
      expect(_renderKinds(listLit), isNot(equals(_renderKinds(mapLit))));
    });

    test('default parameter values keep the pre-analyzer-13 nested shape', () {
      final left = normalizeSingle('''
int f({int a = 1}) => a;
''');
      final right = normalizeSingle('''
int g({int count = 42}) => count;
''');
      expect(_renderLabels(left), equals(_renderLabels(right)));
      expect(
        _renderKinds(left),
        equals(
          'function-decl[type,function-expr[params[param[param[type],'
          'literal]],expr-body[ref]]]',
        ),
      );
    });

    test('named and optional parameters without defaults are still nested', () {
      final named = normalizeSingle('''
void f({required int a, int? b}) {}
''');
      final positional = normalizeSingle('''
void g([int? a, int? b]) {}
''');
      final required = normalizeSingle('''
void h(int a, int? b) {}
''');
      const nested = 'params[param[param[type]],param[param[type]]]';
      expect(_renderKinds(named), contains(nested));
      expect(_renderKinds(positional), contains(nested));
      expect(
        _renderKinds(required),
        contains('params[param[type],param[type]]'),
      );
    });

    test('field and super formal parameters inside braces are nested', () {
      final constructor = normalizeSingle('''
class Box {
  const Box({super.key, required this.width, this.height = 2});
}
''');
      expect(constructor.kind, equals('constructor-decl'));
      expect(
        _renderKinds(constructor),
        startsWith(
          'constructor-decl[params[param[param],param[param],'
          'param[param,literal]]',
        ),
      );
    });

    test('function-typed parameters keep the return type and parameters', () {
      final left = normalizeSingle('''
void f(void cb(int x)) => run(cb);
''');
      final right = normalizeSingle('''
void g(void handler(int y)) => run(handler);
''');
      expect(_renderLabels(left), equals(_renderLabels(right)));
      expect(
        _renderKinds(left),
        equals(
          'function-decl[type,function-expr[params[param[type,params['
          'param[type]]]],expr-body[method-call[no-target,args[ref]]]]]',
        ),
      );
    });

    test('named arguments preserve the argument name and drop the value', () {
      final one = normalizeSingle('''
void f() => g(x: 1);
''');
      final two = normalizeSingle('''
void h() => g(x: 2);
''');
      final other = normalizeSingle('''
void k() => g(y: 1);
''');
      expect(_renderLabels(one), equals(_renderLabels(two)));
      expect(_renderLabels(one), isNot(equals(_renderLabels(other))));
      expect(_renderKinds(one), contains('args[named-arg[literal]]'));
    });

    test('record literal named fields normalize as named arguments', () {
      final record = normalizeSingle('''
Object f() => (1, y: 2);
''');
      expect(
        _renderLabels(record),
        contains('record-lit|[literal|,named-arg|y[literal|]]'),
      );
    });

    test('labeled break and continue ignore the label name', () {
      final outer = normalizeSingle('''
void f() {
  outer:
  for (var i = 0; i < 3; i++) {
    for (var j = 0; j < 3; j++) {
      if (j == 1) continue outer;
      if (i == 2) break outer;
    }
  }
}
''');
      final loop = normalizeSingle('''
void g() {
  loop:
  for (var a = 0; a < 3; a++) {
    for (var b = 0; b < 3; b++) {
      if (b == 1) continue loop;
      if (a == 2) break loop;
    }
  }
}
''');
      expect(_renderLabels(outer), equals(_renderLabels(loop)));
      expect(_renderKinds(outer), contains('if[binary[ref,literal],continue]'));
      expect(_renderKinds(outer), contains('if[binary[ref,literal],break]'));
    });
  });

  group('parseDartSource', () {
    test('extension type members are comparable declarations', () {
      final declarations = parseDeclarations('''
extension type Id(int value) {
  int next() => value + 1;
}
''');
      expect(declarations, hasLength(1));
      expect(normalize(declarations.single.node).kind, equals('method-decl'));
    });

    test('enum members are comparable declarations', () {
      final declarations = parseDeclarations('''
enum Level {
  low,
  high;

  bool get isHigh => this == high;
}
''');
      expect(declarations, hasLength(1));
      expect(normalize(declarations.single.node).kind, equals('method-decl'));
    });

    test('class-like declarations with empty bodies yield nothing', () {
      final declarations = parseDeclarations('''
mixin M;
enum E;
class C;
''');
      expect(declarations, isEmpty);
    });

    test(
      'a header-only primary constructor is not a comparable declaration',
      () {
        final declarations = parseDeclarations(
          'class Pt(final int x, final int y);\n',
        );
        expect(declarations, isEmpty);
      },
    );

    test('a primary constructor body matches the equivalent constructor', () {
      final primary = normalizeSingle('''
class Point(final int x, final int y) {
  this : assert(x >= 0) {
    print(x);
  }
}
''');
      final classic = normalizeSingle('''
class Point {
  Point(int x, int y) : assert(x >= 0) {
    print(x);
  }
}
''');
      expect(primary.kind, equals('constructor-decl'));
      expect(_renderLabels(primary), equals(_renderLabels(classic)));
    });
  });
}

String _renderKinds(NormalizedNode node) {
  final buf = StringBuffer()..write(node.kind);
  if (node.children.isNotEmpty) {
    buf.write('[');
    for (var i = 0; i < node.children.length; i++) {
      if (i > 0) buf.write(',');
      buf.write(_renderKinds(node.children[i]));
    }
    buf.write(']');
  }
  return buf.toString();
}

String _renderLabels(NormalizedNode node) {
  final buf = StringBuffer()
    ..write(node.kind)
    ..write('|')
    ..write(node.label ?? '');
  if (node.children.isNotEmpty) {
    buf.write('[');
    for (var i = 0; i < node.children.length; i++) {
      if (i > 0) buf.write(',');
      buf.write(_renderLabels(node.children[i]));
    }
    buf.write(']');
  }
  return buf.toString();
}
