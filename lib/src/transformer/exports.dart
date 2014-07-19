// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of js.transformer.export_transformer;

class Exports {
  final Resolver resolver;
  final AssetId exportId;
  final libraries = <String, ExportedLibrary>{};
  final classes = <String, ExportedClass>{};

  Exports(this.resolver, this.exportId);

  ExportedLibrary addLibrary(LibraryElement element) {
    String libraryName = element.name;
    // The analyzer is adding '.dart' to library names, so we remove it.
    if (libraryName.endsWith('.dart')) {
      libraryName =
          libraryName.substring(0, libraryName.length - '.dart'.length);
    }
    var parts = libraryName.split('.');
    if (parts.length > 1) {
      var leafName = parts.last;
      var parent = null;
      for (var name in parts.sublist(0, parts.length - 1)) {
        parent = libraries.putIfAbsent(name,
            () => new ExportedLibrary(name, parent, null));
      }
      return parent.children.putIfAbsent(leafName,
          () => new ExportedLibrary(leafName, parent, element));
    } else {
      return libraries.putIfAbsent(libraryName,
          () => new ExportedLibrary(libraryName, null, element));
    }
  }

  ExportedClass addClass(ClassElement element) {
    if (classes.containsKey(element.name)) {
      return classes[element.name];
    }
    var libraryELement = element.library;
    var exportedLibrary = addLibrary(libraryELement);
    return exportedLibrary.children.putIfAbsent(element.name,
        () => new ExportedClass(exportedLibrary, element));
  }

  ExportedConstructor addConstructor(ConstructorElement element) {
    var exportedClass = addClass(element.enclosingElement);
    return exportedClass.children.putIfAbsent(element.name,
        () => new ExportedConstructor(exportedClass, element));
  }

  ExportedMethod addMethod(MethodElement element) {
    var exportedClass = addClass(element.enclosingElement);
    return exportedClass.children.putIfAbsent(element.name,
      () => new ExportedMethod(exportedClass, element));
  }

  ExportedTopLevelVariable addTopLevelVariable(
      TopLevelVariableElement element) {
    var exportedLibrary = addLibrary(element.library);
    return exportedLibrary.children.putIfAbsent(element.name,
      () => new ExportedTopLevelVariable(exportedLibrary, element));
  }

  ExportedFunction addFunction(FunctionElement element) {
    var exportedLibrary = addLibrary(element.library);
    return exportedLibrary.children.putIfAbsent(element.name,
      () => new ExportedFunction(exportedLibrary, element));
  }

  ExportedField addField(FieldElement element) {
    var exportedClass = addClass(element.enclosingElement);
    return exportedClass.children.putIfAbsent(element.name,
      () => new ExportedField(exportedClass, element));
  }

  writeJS(StringSink sink) {
    sink.write('''
window.dart = window.dart || {};
window.dart.Object = function DartObject() {
  throw "not allowed";
};
window.dart.Object._wrapDartObject = function(dartObject) {
  var o = Object.create(window.dart.Object.prototype);
  o['_dartObject'] = dartObject;
  return o;
};
''');
    for (var library in libraries.values) {
      var libPath = library.path.join('_');
      sink.write('_export_${libPath}(dart);\n');
    }

    for (var library in libraries.values) {
      library.writeJS(sink);
    }

  }

  writeDart(StringSink sink) {
    sink.write('''
library js_exports;

import 'dart:js' as js;

''');

    for (var library in libraries.values) {
      library.writeDartImport(sink, resolver, exportId);
    }

    sink.write('''

final _obj = js.context['Object'];
final _dartNs = js.context['dart'];

Object _getOptionalArg(Map<String, Object> args, String name) =>
  args == null ? null : args[name];

void export() {
  var lib = _dartNs;
''');

    for (var library in libraries.values) {
      library.writeDartInline(sink);
    }

    sink.write('}\n');

    for (var library in libraries.values) {
      var prefix = library.path.join('_');
      library.writeDart(sink);
    }
  }

}
