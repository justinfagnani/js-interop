library js.test.transformer.utils;
import 'package:code_transformers/resolver.dart';

// The list of types below is derived from:
//   * types we use via our smoke queries, including HtmlElement and
//     types from `_typeHandlers` (deserialize.dart)
//   * types that are used internally by the resolver (see
//   _initializeFrom in resolver.dart).
// TODO: probably going to need all implentations of List and Map in dart:*
// and all transferrable native objects supported by dart:js
final mockSdkSources = {
  'dart:core': '''
      library dart.core;
      class Object {}
      class Function {}
      class StackTrace {}
      class Symbol {}
      class Type {}
      class Expando<T> {}

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

      void print(String s);
      ''',
  'dart:html': '''
      library dart.html;
      class HtmlElement {}
      ''',
  'dart:js': '''
      class JsObject {}
      JsObject context;
      '''
};
