// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/**
 * This test needs to be run though the package:js transformer.
 */
@Export()
library js.transformer_test;

import 'dart:js' as js;

import 'package:js_experimental/js.dart';
import 'package:unittest/unittest.dart';
import 'package:unittest/html_enhanced_config.dart';

@JsConstructor('JsThing')
abstract class JsThing extends JsInterface {

  String get x;
}

@Export()
class ExportMe {
  static String staticField = 'a';
  static bool staticMethod() => false;

  String field = "field";

  int method() => 42;

  bool get getter => true;

  int _property = 0;
  int get property => _property;
  void set property(v) { _property = v; }

  String _privateMethod() => "privateMethod";

  String _privateField = "privateField";

  String optionalArgs(a, [b, c]) => "$a $b $c";

  String namedArgs(a, {b, c})  => "$a $b $c";

  @NoExport()
  dartOnly() => false;

  bool operator ==(o) => super==(o);
}

@NoExport()
class DoNotExport {
  String field;
  int method() => 0;
  bool get getter => false;
}

String topLevelField = "aardvark";

String topLevelMethod() => "success";

// This should return a dart.Object since DoNotExport is not exported
@Export()
DoNotExport getDoNotExport() => new DoNotExport();


/**
 * Warning: this test is old, and tests an architecture that added exports to
 * dart:js, rather than to package:js.
 */

@NoExport()
void main() {
  useHtmlEnhancedConfiguration();

  group('ExportTransformer', () {

    var lib = js.context['dart']['js']['transformer_test'];
    var dartObject = js.context['dart']['Object'];

    test('should export this library as dart.js.transformer_test', () {
      expect(lib, isNotNull);
    });

    test('should export class ExportMe', () {
      expect(lib.hasProperty('ExportMe'), isTrue);
    });

    test('should not export class DoNotExport', () {
      expect(lib.hasProperty('DoNotExport'), isFalse);
    });

    // not implemented yet
    test('should export top-level method getDoNotExport', () {
      expect(lib.hasProperty('getDoNotExport'), isTrue);
    });

    test('should export an object from Dart', () {
      var o1 = new ExportMe()..field = 'created in Dart';
      js.context['o1'] = o1;
      var roundTripped = js.context['o1'];
      expect(roundTripped, new isInstanceOf<ExportMe>());
    });

    test('should allow construction from JS', () {
      var o2 = new js.JsObject(lib['ExportMe']);
      js.context['o2'] = o2;
      var roundTripped = js.context['o2'];
      expect(roundTripped, new isInstanceOf<ExportMe>());
    });

    test('should export only public members', () {
      var o2 = new js.JsObject(lib['ExportMe']);
      expect(o2.hasProperty('method'), isTrue);
      expect(o2.hasProperty('field'), isTrue);
      expect(o2.hasProperty('getter'), isTrue);
      expect(o2.hasProperty('namedArgs'), isTrue);
      expect(o2.hasProperty('optionalArgs'), isTrue);
      expect(o2.hasProperty('_privateMethod'), isFalse);
      expect(o2.hasProperty('_privateField'), isFalse);
    });

    test('should not export statics ', () {
      var o2 = new js.JsObject(lib['ExportMe']);
      expect(o2.hasProperty('staticField'), isFalse);
      expect(o2.hasProperty('staticMethod'), isFalse);
    });

    test('should not export @NoExport annotated public members', () {
      var o2 = new js.JsObject(lib['ExportMe']);
      expect(o2.hasProperty('dartOnly'), isFalse);
    });

    test('should invoke an instance method', () {
      var o2 = new js.JsObject(lib['ExportMe']);
      expect(o2.callMethod('method'), 42);
    });

    test('should access a field', () {
      var o2 = new js.JsObject(lib['ExportMe']);
      expect(o2['field'], 'field');
    });

    test('should access getter', () {
      var o2 = new js.JsObject(lib['ExportMe']);
      expect(o2['getter'], true);
    });

    test('should access getter / setter', () {
      var o2 = new js.JsObject(lib['ExportMe']);
      o2['property'] = 2014;
      expect(o2['property'], 2014);
    });

    test('should invoke an instance method with optional parameters', () {
      var o2 = new js.JsObject(lib['ExportMe']);
      expect(o2.callMethod('optionalArgs', [1]), '1 null null');
      expect(o2.callMethod('optionalArgs', [1, 2]), '1 2 null');
      expect(o2.callMethod('optionalArgs', [1, 2, 3]), '1 2 3');
    });

    test('should invoke an instance method with named parameters', () {
      var o2 = new js.JsObject(lib['ExportMe']);
      expect(o2.callMethod('namedArgs', [1]), '1 null null');
      expect(o2.callMethod('namedArgs', [1, new js.JsObject.jsify({'b': 2})]),
          '1 2 null');
      expect(o2.callMethod('namedArgs', [1, new js.JsObject.jsify({'c': 3})]),
          '1 null 3');
      expect(o2.callMethod('namedArgs',
          [1, new js.JsObject.jsify({'b': 2, 'c': 3})]), '1 2 3');
    });

    test('should invoke top-level function', () {
      expect(lib.callMethod('topLevelMethod'), 'success');
    });

    test('should access top-level field', () {
      expect(lib['topLevelField'], 'aardvark');
      lib['topLevelField'] = 'baboon';
      expect(lib['topLevelField'], 'baboon');
    });

    test('should create proper prototype chains', () {
      var o2 = new js.JsObject(lib['ExportMe']);
      expect(o2.instanceof(dartObject), isTrue);
      expect(o2.instanceof(lib['ExportMe']), isTrue);
    });

  });
}
