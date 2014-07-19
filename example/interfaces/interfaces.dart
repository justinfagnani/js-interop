library js.example.interfaces;

import 'dart:html';
import 'package:js_experimental/js.dart';

@JsGlobal()
abstract class Context extends JsInterface {

  factory Context() => new JsInterface();

  Context._create();

  Foo aFoo;
}

@JsConstructor('Foo')
abstract class Foo extends JsInterface {

  factory Foo(String name) {}

  String name;

}

main() {
  var context = new Context();
  var foo = context.aFoo;
  print('foo: $foo ${foo.runtimeType} ${foo.name}');
}
