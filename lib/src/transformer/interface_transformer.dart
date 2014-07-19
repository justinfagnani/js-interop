// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library js.transformer.interface_transformer;

import 'dart:async';

import 'package:analyzer/analyzer.dart' show Annotation, CompilationUnit, Directive, ImportDirective, LibraryDirective, ParameterKind, PartDirective, PartOfDirective, parseCompilationUnit, StringLiteral;
import 'package:analyzer/src/generated/element.dart' show ClassElement,
    ConstructorElement, Element, ElementKind, FieldElement, FunctionElement,
    LibraryElement, MethodElement, PropertyAccessorElement,
    RecursiveElementVisitor;
import 'package:barback/barback.dart' show Asset, AssetId, BarbackSettings,
    Transform, Transformer, TransformerGroup;
import 'package:code_transformers/resolver.dart' show dartSdkDirectory,
    isPossibleDartEntry, Resolver, Resolvers, ResolverTransformer;
import 'package:logging/logging.dart' show Logger;
import 'package:source_maps/refactor.dart';

import 'typed_interface_finder.dart';

final _logger = new Logger('js.transformer.interface_transformer');

class InterfaceTransformer extends Transformer with ResolverTransformer {
  @override
  final Resolvers resolvers;

  InterfaceTransformer(this.resolvers);

  @override
  Future<bool> isPrimary(AssetId id) => new Future.value(id.extension == '.dart');

  Future<bool> shouldApplyResolver(Asset asset) {
    return asset.readAsString().then((contents) {
      var cu = parseCompilationUnit(contents, suppressErrors: true);
      var isPart = cu.directives.any((Directive d) => d is PartOfDirective);
      return !isPart;
    });
  }

  @override
  applyResolver(Transform transform, Resolver resolver) {
    var library = resolver.getLibrary(transform.primaryInput.id);
    var transaction = resolver.createTextEditTransaction(library);
    return new _InterfaceTransformer(transform, resolver, library, transaction)
        .apply();
  }
}

class _InterfaceTransformer {
  final Transform transform;
  final ClassElement jsInterfaceClass;
  final ClassElement jsGlobalClass;
  final ClassElement jsConstructorClass;
  final ClassElement exportClass;
  final ClassElement noExportClass;
  final LibraryElement library;
  final TextEditTransaction transaction;
  final StringBuffer implBuffer;

  _InterfaceTransformer(
      this.transform,
      Resolver resolver,
      this.library,
      this.transaction)
      : jsInterfaceClass = resolver.getType('js.JsInterface'),
        jsGlobalClass = resolver.getType('js.JsGlobal'),
        jsConstructorClass = resolver.getType('js.JsConstructor'),
        exportClass = resolver.getType('js.Export'),
        noExportClass = resolver.getType('js.NoExport'),
        implBuffer =  new StringBuffer();

  Future apply() {
    var input = transform.primaryInput;

    return transform.readInputAsString(input.id).then((inputSource) {

      var interfaceFinder = new TypedInterfaceFinder(library, jsInterfaceClass,
          exportClass, noExportClass);
      library.accept(interfaceFinder);
      interfaceFinder.jsInterfaces.forEach(generateClass);

      int endOfFile = inputSource.length - 1;
      transaction.edit(endOfFile, endOfFile, implBuffer.toString());
      var printer = transaction.commit();
      printer.build(input.id.path);
      var newLibrary = new Asset.fromString(input.id, printer.text);
      transform.addOutput(newLibrary);
    });
  }

  void generateClass(ClassElement interface) {
    final interfaceName = interface.name;
    final implName = '${interfaceName}Impl';
    final bool isGlobal = _isGlobalInterface(interface);
    final factoryConstructor = _getFactoryConstructor(interface);
    final bool hasFactory = factoryConstructor != null;
    final String jsConstructor = _getJsConstructor(interface);

    if (hasFactory) {
      // if there's a factory there must be a generative ctor named _create
      final createConstructor = _getCreateConstructor(interface);
      if (createConstructor == null) {
        _logger.severe("When a factory constructor is defined, a "
            "generative constructor named _create must be defined as well");
      }

      // replace the factory constructor
      var body = factoryConstructor.node.body;
      var begin = body.offset;
      var end = body.end;

      if (isGlobal) {
        transaction.edit(begin, end, '=> new $implName._wrap(jsContext);');
      } else {
        // factory parameters
        var parameterList = factoryConstructor.parameters
            .map((p) => p.displayName)
            .join(', ');
        transaction.edit(begin, end, '=> new $implName._($parameterList);');
      }
    }

    if (isGlobal && !hasFactory) {
      _logger.severe("global objects must have factory constructors");
    }


    // add impl class
    implBuffer.write('''
    
    class $implName extends $interfaceName {
      final JsObject _obj;
    
      static $implName wrap(JsObject o) => new $implName._wrap(o);
    
      $implName._wrap(this._obj) : super${ hasFactory ? '._create' : ''}();
    
    ''');

    if (hasFactory && !isGlobal) {
      implBuffer.writeln('static final _ctor = jsContext["$jsConstructor"];');
      // parameters
      var parameterList = factoryConstructor.parameters
          .map((p) => '${p.type.displayName} ${p.displayName}')
          .join(', ');

      var jsParameterList = factoryConstructor.parameters
          .map((p) {
            var type = p.type;
            if (type.isSubtypeOf(jsInterfaceClass.type)) {
              return '${p.displayName}._obj';
            } else {
              return p.displayName;
            }
          })
          .join(', ');

      String newCall = 'new JsObject(_ctor, [$jsParameterList])';
      implBuffer.writeln('  $implName._($parameterList) : _obj = $newCall, super._create();');
    }

    for (PropertyAccessorElement a in interface.accessors) {
      if ((a.isAbstract || a.variable != null) && !a.isStatic) {
        if (a.isGetter) {
          _generateGetter(a);
        }
        if (a.isSetter) {
          _generateSetter(a);
        }
      }
    }

    for (MethodElement a in interface.methods) {
      _generateMethod(a, interfaceName);
    }

    implBuffer.write('}');
  }

  void _generateMethod(MethodElement a, String interfaceName) {
    var name = a.displayName;
    if (!a.isStatic && name != interfaceName) {
      var returnType = a.returnType;

      var parameterList = new StringBuffer();
      var jsParameterList = new StringBuffer();

      // parameters
      for (var p in a.parameters) {
        var type = p.type;
        parameterList.write('${type.displayName} ${p.displayName}');
        if (type.isSubtypeOf(jsInterfaceClass.type)) {
          // unwrap
          jsParameterList.write('${p.displayName}._obj');
        } else {
          jsParameterList.write('${p.displayName}');
        }
      }

      if (returnType.isSubtypeOf(jsInterfaceClass.type)) {
        var returnTypeImplName = '${returnType}Impl';
        implBuffer.writeln('  ${a.returnType} $name($parameterList) => getWrapper(_obj.callMethod("$name", [$jsParameterList]) as JsObject, $returnTypeImplName._wrap) as $returnTypeImplName;');
      } else {
        implBuffer.writeln('  ${a.returnType} $name($parameterList) => _obj.callMethod("$name", [$jsParameterList]);');
      }
    }
  }

  void _generateSetter(PropertyAccessorElement a) {
    var name = a.displayName;
    var type = a.parameters[0].type;
    if (type.isSubtypeOf(jsInterfaceClass.type)) {
      implBuffer.writeln('  void set $name(${a.parameters[0].type} v) => _obj["$name"] = v._obj;');
    } else {
      implBuffer.writeln('  void set $name(${a.parameters[0].type} v) { _obj["$name"] = v; }');
    }
  }

  void _generateGetter(PropertyAccessorElement a) {
    var name = a.displayName;
    var type = a.type.returnType;
    var typeImplName = '${type}Impl';
    if (type.isSubtypeOf(jsInterfaceClass.type)) {
      implBuffer.writeln('  $type get $name => getWrapper(_obj["$name"], $typeImplName.wrap) as $type;');
    } else {
      // TODO: verify that $type is a primitive, List, JsObject or native object
      implBuffer.writeln('  $type get $name => _obj["$name"] as $type;');
    }
  }

  bool _isGlobalInterface(ClassElement interface) {
    for (var m in interface.metadata) {
      var e = m.element;
      if (e is ConstructorElement && e.type.returnType == jsGlobalClass.type) {
        return true;
      }
    }
    return false;
  }

  _getFactoryConstructor(ClassElement interface) => interface.constructors
      .firstWhere((c) => c.name == '' && c.isFactory, orElse: () => null);

  _getCreateConstructor(ClassElement interface) => interface.constructors
      .firstWhere((c) => c.name == '_create' && !c.isFactory,
      orElse: () => null);

  _getJsConstructor(ClassElement interface) {
    var node = interface.node;
    for (Annotation a in node.metadata) {
      var e = a.element;
      if (e is ConstructorElement && e.type.returnType == jsConstructorClass.type) {
        return (a.arguments.arguments[0] as StringLiteral).stringValue;
      }
    }
    return null;
  }

}
