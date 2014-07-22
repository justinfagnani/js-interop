library js.test.transformer.visitor_test;

import 'dart:io';
import 'package:unittest/unittest.dart';

//import 'package:js_experimental/js.dart';
import 'package:js_experimental/src/transformer/visitor.dart';
import 'utils.dart';
import 'package:analyzer/src/generated/engine.dart';
import 'package:analyzer/src/generated/element.dart';
import 'package:code_transformers/resolver.dart' show MockDartSdk;
import 'package:analyzer/src/generated/source.dart';
import 'package:analyzer/src/string_source.dart';

main() {

  group('JsVisitor', () {
    InternalAnalysisContext _context;
    LibraryElement testLib;
    LibraryElement jsLib;

    setUp(() {
      _context = AnalysisEngine.instance.createAnalysisContext();
      var sdk = new MockDartSdk(mockSdkSources, reportMissing: false);
      var options = new AnalysisOptionsImpl();
      _context.analysisOptions = options;
      sdk.context.analysisOptions = options;
      var testResolver = new TestUriResolver(testSources);
      _context.sourceFactory = new SourceFactory([sdk.resolver, testResolver]);
      var testSource = testResolver
          .resolveAbsolute(Uri.parse('package:test/test.dart'));
      _context.parseCompilationUnit(testSource);
      var jsSource = testResolver
          .resolveAbsolute(Uri.parse('package:js_experimental/js.dart'));

      testLib = _context.computeLibraryElement(testSource);
      jsLib = _context.getLibraryElement(jsSource);
    });

    test('finds JSInterfaces', () {
      var visitor = new JsVisitor(jsLib, testLib)
          ..visitLibraryElement(testLib);
      expect(visitor.jsInterfaces, new Set.from([
          testLib.getType('Context'),
          testLib.getType('JsFoo'),
          testLib.getType('JsBar')]));
    });

    test('finds exported classes', () {
      var visitor = new JsVisitor(jsLib, testLib)
          ..visitLibraryElement(testLib);
      expect(visitor.exportedElements, contains(testLib.getType('ExportMe')));
    });

    test('does not export non-exported classes', () {
      var visitor = new JsVisitor(jsLib, testLib)
          ..visitLibraryElement(testLib);
      expect(visitor.exportedElements, isNot(contains(testLib.getType('Context'))));
      expect(visitor.exportedElements, isNot(contains(testLib.getType('DoNotExport'))));
    });
  });
}

final Map testSources = {
  'package:js_experimental/js.dart': new File('../../lib/js.dart').readAsStringSync(),
  'package:test/test.dart': r'''
      library js.transformer_test;
      
      import 'dart:html';
      import 'package:js_experimental/js.dart';
      import 'dart:js' as js;
      
      
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
      '''
};

class TestUriResolver extends UriResolver {
  final Map<String, String> sources;

  TestUriResolver(this.sources);

  Source resolveAbsolute(Uri uri) {
    var name = uri.toString();
    var contents = sources[name];
    return new StringSource(contents, name);
  }

  Source fromEncoding(UriKind kind, Uri uri) =>
      throw new UnsupportedError('fromEncoding is not supported');

  Uri restoreAbsolute(Source source) =>
      throw new UnsupportedError('restoreAbsolute is not supported');
}