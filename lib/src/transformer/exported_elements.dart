// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of js.transformer.export_transformer;

abstract class ExportedElement<P extends ExportedElement, E extends Element> {
  final P parent;
  final E element;

  ExportedElement(this.parent, this.element);

  writeJsInline(StringSink sink) {}
  writeJS(StringSink sink) {}
  writeDartInline(StringSink sink) {}
  writeDart(StringSink sink) {}

  String get name => element.name;

  Iterable<String> get path => new List.from(parent.path)..add(element.name);
}

class ExportedLibrary extends ExportedElement<ExportedLibrary, LibraryElement> {
  final String name;
  final Map<String, ExportedElement> children = <String, ExportedElement>{};

  ExportedLibrary(this.name, ExportedLibrary parent, LibraryElement element)
      : super(parent, element);

  Iterable<String> get path => parent == null
      ? ['dart', name]
      : (new List.from(parent.path)..add(name));

  writeJsInline(StringSink sink) {
    sink.write('  _export_${path.join('_')}(lib);\n');
  }

  writeJS(StringSink sink) {
    var libPath = path.join('_');
    sink.write('''
function _export_${libPath}(parent) {
  var lib = parent.${name} = {};
''');

    // invoke children's export functions
    for (var child in children.values) {
      child.writeJsInline(sink);
    }
    sink.write('}\n\n');

    // define children's export functions
    for (var child in children.values) {
      child.writeJS(sink);
    }
  }

  writeDartInline(StringSink sink) {
    sink.write('  _export_${path.join('_')}(lib);\n');
  }

  writeDart(StringSink sink) {
    var libPath = path.join('_');

    sink.write('''
_export_${libPath}(js.JsObject parent) {
  var lib = parent['${name}'];
''');

    for (var child in children.values) {
      child.writeDartInline(sink);
    }

    sink.write('}\n\n');

    for (var child in children.values) {
      child.writeDart(sink);
    }
  }

  writeDartImport(StringSink sink, Resolver resolver, AssetId from) {
    if (element != null) {
      var prefix = path.join('_');
      Uri importUri = resolver.getImportUri(element, from: from);
      sink.write("import '$importUri' as $prefix;\n");
    }
    for (var child in children.values.where((c) => c is ExportedLibrary)) {
      child.writeDartImport(sink, resolver, from);
    }
  }

  String toString() => "library $name";
}

class ExportedClass extends ExportedElement<ExportedLibrary, ClassElement> {
  final Map<String, ExportedElement> children = <String, ExportedElement>{};

  ExportedClass(ExportedLibrary parent, ClassElement element)
      : super(parent, element);

  writeJsInline(StringSink sink) {
    sink.write('  _export_${path.join('_')}(lib);\n');
  }

  writeJS(StringSink sink) {
    var classPath = path.join('_');
    sink.write('''
function _export_$classPath(parent) {
  var constructor = parent.$name = function ${name}Js() {
    if (constructor.hasOwnProperty('_new')) {
      return constructor._new();
    } else {
      throw "not allowed";
    }
  };
  constructor.prototype = Object.create(dart.Object.prototype);
  constructor.prototype.constructor = constructor;
  constructor._wrapDartObject = function(dartObject) {
    var o = Object.create(constructor.prototype);
    o['_dartObject'] = dartObject;
    return o;
  };
} 
''');
  }

  writeDartInline(StringSink sink) {
    sink.write('  _export_${path.join('_')}(lib);\n');
  }

  writeDart(StringSink sink) {
    var classPath = path.join('_');
    var prefix = parent.path.join('_');
    sink.write('''
_export_$classPath(js.JsObject parent) {
  var constructor = parent['$name'];
  js.registerJsConstructorForType($prefix.$name, '''
      '''constructor['_wrapDartObject']);
  var prototype = constructor['prototype'];
''');

    for (var child in children.values) {
      child.writeDartInline(sink);
    }
    sink.write('}\n\n');

    for (var child in children.values) {
      child.writeDart(sink);
    }
  }
}

class ExportedConstructor
    extends ExportedElement<ExportedClass, ConstructorElement> {

  ExportedConstructor(ExportedClass parent, ConstructorElement element)
      : super(parent, element);

  writeDartInline(StringSink sink) {
    var constructorName = name == '' ? '_new' : name;
    var prefix = parent.parent.path.join('_');

    var requiredParameters = element.parameters
        .where((p) => p.parameterKind == ParameterKind.REQUIRED)
        .map((p) => p.name);
    var positionalParameters = element.parameters
        .where((p) => p.parameterKind == ParameterKind.POSITIONAL)
        .map((p) => p.name);
    var namedParameters = element.parameters
        .where((p) => p.parameterKind == ParameterKind.NAMED)
        .map((p) => p.name);

    assert(positionalParameters.isEmpty || namedParameters.isEmpty);

    var dartNamedParameters = namedParameters.map((name) =>
        "${name}: _getOptionalArg(__js_named_parameters_map__, '${name}')");
    var dartParameters = concat([
            requiredParameters,
            positionalParameters,
            dartNamedParameters])
        .join(', ');

    var jsParameters = requiredParameters.join(', ');
    if (positionalParameters.isNotEmpty) {
      jsParameters += ', [' + positionalParameters.join(', ') + ']';
    } else if (namedParameters.isNotEmpty) {
      jsParameters += ', [__js_named_parameters_map__]';
    }

    sink.write('''
  constructor['$constructorName'] = ($jsParameters) => 
      new $prefix.${parent.name}($dartParameters);
''');
  }
}

class ExportedMethod extends ExportedElement<ExportedClass, MethodElement> {

  ExportedMethod(ExportedClass parent, MethodElement element)
      : super(parent, element);

  writeDartInline(StringSink sink) {
    var requiredParameters = element.parameters
        .where((p) => p.parameterKind == ParameterKind.REQUIRED)
        .map((p) => p.name);
    var positionalParameters = element.parameters
        .where((p) => p.parameterKind == ParameterKind.POSITIONAL)
        .map((p) => p.name);
    var namedParameters = element.parameters
        .where((p) => p.parameterKind == ParameterKind.NAMED)
        .map((p) => p.name);

    assert(positionalParameters.isEmpty || namedParameters.isEmpty);

    var dartNamedParameters = namedParameters.map((name) =>
        "${name}: _getOptionalArg(__js_named_parameters_map__, '${name}')");
    var dartParameters = concat([
            requiredParameters,
            positionalParameters,
            dartNamedParameters])
        .join(', ');

    var jsParameters =
        concat([['__js_this_ref__'], requiredParameters]).join(', ');
    if (positionalParameters.isNotEmpty) {
      jsParameters += ', [' + positionalParameters.join(', ') + ']';
    } else if (namedParameters.isNotEmpty) {
      jsParameters += ', [__js_named_parameters_map__]';
    }

    sink.write('''
  // method $name
  prototype['$name'] = new js.JsFunction.withThis(($jsParameters) {
   return  __js_this_ref__.$name($dartParameters);
  });
''');
  }
}

class ExportedField extends ExportedElement<ExportedClass, FieldElement> {

  ExportedField(ExportedClass parent, FieldElement element)
      : super(parent, element);

  writeDartInline(StringSink sink) {
    sink.write('''
  // field $name
  _obj.callMethod('defineProperty', [prototype, '$name',
      new js.JsObject.jsify({
        'get': new js.JsFunction.withThis((o) => o.$name)''');
    if (element.setter != null) {
      sink.write(''',
        'set': new js.JsFunction.withThis((o, v) => o.$name = v)''');
    }
    sink.write('})]);');
  }
}

class ExportedTopLevelVariable
    extends ExportedElement<ExportedLibrary, TopLevelVariableElement> {

  ExportedTopLevelVariable(ExportedLibrary parent,
      TopLevelVariableElement element)
      : super(parent, element);

  writeDartInline(StringSink sink) {
    var prefix = parent.path.join('_');
    sink.write('''
  // field $name
  _obj.callMethod('defineProperty', [lib, '$name',
      new js.JsObject.jsify({
        'get': () => $prefix.$name''');
    if (element.setter != null) {
      sink.write(''',
        'set': (v) => $prefix.$name = v''');
    }
    sink.write('})]);');
  }
}

class ExportedFunction
    extends ExportedElement<ExportedLibrary, FunctionElement> {

  ExportedFunction(ExportedLibrary parent, FunctionElement element)
      : super(parent, element);

  writeJS(StringSink sink) {}

  writeDartInline(StringSink sink) {
    var prefix = parent.path.join('_');

    var requiredParameters = element.parameters
        .where((p) => p.parameterKind == ParameterKind.REQUIRED)
        .map((p) => p.name);
    var positionalParameters = element.parameters
        .where((p) => p.parameterKind == ParameterKind.POSITIONAL)
        .map((p) => p.name);
    var namedParameters = element.parameters
        .where((p) => p.parameterKind == ParameterKind.NAMED)
        .map((p) => p.name);

    assert(positionalParameters.isEmpty || namedParameters.isEmpty);

    var dartNamedParameters = namedParameters.map((name) =>
        "${name}: _getOptionalArg(__js_named_parameters_map__, '${name}')");
    var dartParameters = concat([
            requiredParameters,
            positionalParameters,
            dartNamedParameters])
        .join(', ');

    var jsParameters = requiredParameters.join(', ');
    if (positionalParameters.isNotEmpty) {
      jsParameters += ', [' + positionalParameters.join(', ') + ']';
    } else if (namedParameters.isNotEmpty) {
      jsParameters += ', [__js_named_parameters_map__]';
    }

    sink.write('''
  // function $name
  lib['$name'] = ($jsParameters) => $prefix.$name($dartParameters);
''');
  }
}
