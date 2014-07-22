// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:code_transformers/src/test_harness.dart';
import 'package:code_transformers/resolver.dart';
import 'package:js_experimental/src/transformer/export_transformer.dart';
import 'package:js_experimental/src/transformer/interface_transformer.dart';

/*
 * This is not the real test you're looking for, it's a helper for development.
 */
main() {

  var resolvers = mockResolvers();
  var exportTransformer = new ExportTransformer(resolvers);
  var interfaceTransformer = new InterfaceTransformer(resolvers);

  var jsLibrary = new File('../lib/js.dart').readAsStringSync();

  var testHelper = new TestHelper([[interfaceTransformer], [exportTransformer]], {
    'js_experimental|lib/js.dart': jsLibrary,
    'test|web/test.dart': testDart,
//        'test|web/part.dart': testPart,
    'test|web/test.html': testHtml
  }, null);

  testHelper.run();

  return Future.wait([
    testHelper['test|web/test_exports.dart'],
    testHelper['test|web/test_exports.js'],
    testHelper['test|web/test.dart'],
//        testHelper['test|web/part.dart'],
    ])
  .then((files) {
    int i = 0;
    print("\ntest_exports.dart:");
    print(files[i++]);
    print("\ntest_exports.js:");
    print(files[i++]);
    print("\ntest.dart:");
    print(files[i++]);
//        print("\npart.dart:");
//        print(files[i++]);
  });
}

String testDart = r'''
//@Export()
library js.transformer_test;

import 'dart:html';
import 'dart:js' as js;

import 'package:js_experimental/js.dart';

//part 'part.dart';

@JsGlobal()
abstract class Context extends JsInterface {

  factory Context() {}

  Context._create();

  JsFoo foo; // read a typed JS object from JS

  ExportMe exportMe; // write a exported Dart object to JS

}

@JsConstructor('JsThing')
abstract class JsFoo extends JsInterface {

  factory JsFoo(String name) {}

  JsFoo._create();

  String name;

  int y() => 1;

  JsBar bar;

  JsBar getBar(JsBar b);

}

@JsConstructor('JsThing2')
abstract class JsBar extends JsInterface {

  int y;

}

@Export()
class ExportMe {

  static String staticField = 'a';
  static bool staticMethod() => false;

  String field;

  int method() => 42;

  bool get getter => true;

  String _privateMethod() => "privateMethod";

  String _privateField = "privateField";

  void optionalArgs(a, [b, c]) {
    print("a: $a");
    print("b: $b");
    print("c: $c");
  }

  void namedArgs(a, {b, c}) {
    print("a: $a");
    print("b: $b");
    print("c: $c");
  }

}

@NoExport()
class DoNotExport {
  String field;
  bool get getter => false;
}

String topLevelField = "aardvark";

@Export()
DoNotExport getDoNotExport() => new DoNotExport();

@NoExport
void main() {
  print('hello world');
  print("window: ${js.context['window']}");
  var o1 = new ExportMe()..field = 'created in Dart';
  js.context['o1'] = o1;
}
''';

var testPart = '''
part of js.transformer_test;

@JsConstructor('JsThing2')
abstract class JsBar extends JsInterface {

  factory JsBar() {}

  int y;
}

''';

String testHtml = '''
<!DOCTYPE html>

<html>
  <head>
    <meta charset="utf-8">
    <title>Js interop test</title>
  </head>
  <body>
    <h1>Js interop test</h1>
    
    <script type="application/dart" src="js_interop_test.dart"></script>
    <script src="packages/browser/interop.js"></script>
    <script src="packages/browser/dart.js"></script>
    <script src="js_interop_test.dart.exports.js"></script>
  </body>
</html>
''';


Resolvers mockResolvers() => new Resolvers.fromMock({
    // The list of types below is derived from:
    //   * types we use via our smoke queries, including HtmlElement and
    //     types from `_typeHandlers` (deserialize.dart)
    //   * types that are used internally by the resolver (see
    //   _initializeFrom in resolver.dart).
    'dart:core': '''
        library dart.core;
        class Object {}
        class Function {}
        class StackTrace {}
        class Symbol {}
        class Type {}

        class String extends Object {}
        class bool extends Object {}
        class num extends Object {}
        class int extends num {}
        class double extends num {}
        class DateTime extends Object {}
        class Null extends Object {}

        class Deprecated extends Object {
          final String expires;
          const Deprecated(this.expires);
        }
        const Object deprecated = const Deprecated("next release");
        class _Override { const _Override(); }
        const Object override = const _Override();
        class _Proxy { const _Proxy(); }
        const Object proxy = const _Proxy();

        class List<V> extends Object {}
        class Map<K, V> extends Object {}
        ''',
    'dart:html': '''
        library dart.html;
        class HtmlElement {}
        ''',
  });