// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library js.transformer.export_transformer;


import 'dart:async';

import 'package:analyzer/analyzer.dart' show CompilationUnit, Directive,
    ImportDirective, LibraryDirective, ParameterKind, PartDirective,
    PartOfDirective, parseCompilationUnit;
import 'package:analyzer/src/generated/element.dart' show ClassElement, ConstructorElement, Element, ElementKind, FieldElement, FunctionElement, LibraryElement, MethodElement, PropertyAccessorElement, RecursiveElementVisitor, TopLevelVariableElement, VariableElement;
import 'package:analyzer/src/generated/scanner.dart' show TokenType, Keyword;
import 'package:barback/barback.dart' show Asset, AssetId, BarbackSettings, Transform, Transformer, TransformerGroup;
import 'package:code_transformers/resolver.dart' show dartSdkDirectory,
    isPossibleDartEntry, Resolver, Resolvers, ResolverTransformer;
import 'package:logging/logging.dart' show Logger;
import 'package:path/path.dart' as pathlib show basename;
import 'package:quiver/iterables.dart' show concat;
import 'package:source_maps/refactor.dart' show TextEditTransaction;

part 'exported_elements.dart';
part 'exports.dart';
part 'export_finder.dart';

final _logger = new Logger('js.transformer.export_transformer');

class ExportTransformer extends Transformer with ResolverTransformer {

  @override
  final Resolvers resolvers;

  ExportTransformer(this.resolvers);

//  Future<bool> isPrimary(Asset input) => isPossibleDartEntry(input);

  @override
  Future applyResolver(Transform transform, Resolver resolver) {
    var input = transform.primaryInput;
    var exportId = input.id.changeExtension('_exports.dart');
    var exportFinder = new ExportFinder(resolver, exportId);

    for (LibraryElement library in resolver.libraries) {
      library.accept(exportFinder);
    }

    // generate the Dart export code
    var dartBuffer = new StringBuffer();
    exportFinder.exports.writeDart(dartBuffer);
    var generatedDart = dartBuffer.toString();
    var dartAsset = new Asset.fromString(exportId, generatedDart);
    transform.addOutput(dartAsset);

    // generate the JS export code
    var jsBuffer = new StringBuffer();
    exportFinder.exports.writeJS(jsBuffer);
    var generatedJS = jsBuffer.toString();
    var jsExportId = input.id.changeExtension('_exports.js');
    var jsAsset = new Asset.fromString(jsExportId, generatedJS);
    transform.addOutput(jsAsset);

    // TODO: move out of apply

    // Export Edits

    // start edit of the entry point
    LibraryElement entryLibrary = resolver.getLibrary(input.id);
    var edit = resolver.createTextEditTransaction(entryLibrary);

    // import the generated exports library
    var exportLibFile = pathlib.basename(exportId.path);
    _addImport(edit, entryLibrary.unit, exportLibFile, '_exports');

    // add a call to _export() to main()
    var main = entryLibrary.entryPoint;
    var mainBodyBeginToken = main.node.functionExpression.body.beginToken;
    if (mainBodyBeginToken.type == TokenType.OPEN_CURLY_BRACKET) {
      var exportCallInsertionPosition = mainBodyBeginToken.end;
      edit.edit(exportCallInsertionPosition, exportCallInsertionPosition,
          '\n  _exports.export();\n');
    } else {
      // TODO: support short function mains
      throw 'short function syntax not support for main()';
    }

    // write the transformed entry point
    var printer = edit.commit();
    printer.build(input.id.path);
    var newEntryPoint = new Asset.fromString(input.id, printer.text);
    transform.addOutput(newEntryPoint);

    return new Future.value();
  }

}

List<String> _getEntryPoints(BarbackSettings settings) {
  var value = settings.configuration['entry_points'];
  if (value == null) return null;
  var entryPoints = <String>[];
  if (value is List) {
    entryPoints.addAll(value);
  } else if (value is String) {
    entryPoints = [value];
  } else {
    print('Invalid value for "entry_points" for the package:js transformer.');
  }
  return entryPoints;
}

/// Injects an import into the list of imports in the file.
void _addImport(TextEditTransaction transaction, CompilationUnit unit,
  String uri, String prefix) {
var libDirective;
for (var directive in unit.directives) {
  if (directive is ImportDirective) {
    transaction.edit(directive.keyword.offset, directive.keyword.offset,
        'import \'$uri\' as $prefix;\n');
    return;
  } else if (directive is LibraryDirective) {
    libDirective = directive;
  }
}

// No imports, add after the library directive if there was one.
if (libDirective != null) {
  transaction.edit(libDirective.endToken.offset + 2,
      libDirective.endToken.offset + 2,
      'import \'$uri\' as $prefix;\n');
}
}