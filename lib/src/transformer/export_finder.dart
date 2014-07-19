// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of js.transformer.export_transformer;

class ExportFinder extends RecursiveElementVisitor {
  final ClassElement exportClass;
  final ClassElement noExportClass;
  final Exports exports;
  final Resolver resolver;

  ExportFinder(Resolver resolver, AssetId exportId)
      : resolver = resolver,
        exportClass = resolver.getType('js.Export'),
        noExportClass = resolver.getType('js.NoExport'),
        exports = new Exports(resolver, exportId);

  /*
   * Determines whether an element is exported based on the presence of
   * @Export() and @NoExport() metadata. If an element or an enclosing element
   * has an @Export() annotation, it's exported, unless the element or a closer
   * enclosing element has a @NoExport() annotation
   */
  bool isExported(Element e) {
    if (e.isPrivate) return false;
    bool hasExport = false;
    bool hasNoExport = false;
    for (var m in e.metadata){
      if (m.element.kind == ElementKind.CONSTRUCTOR) {
        if (m.element.enclosingElement == exportClass) {
          if (hasExport) {
            _logger.warning('More than one @Export() on the same declaration');
          }
          if (hasNoExport) {
            _logger.warning(
                '@NoExport() and @Export() on the same declaration');
          }
          hasExport = true;
        } else if (m.element.enclosingElement == noExportClass) {
          if (hasExport) {
            _logger.warning(
                '@NoExport() and @Export() on the same declaration');
          }
          if (hasNoExport) {
            _logger.warning(
                'More than one @NoExport() on the same declaration');
          }
          hasNoExport = true;
        }
      }
    }
    if (hasExport || hasNoExport) return hasExport && !hasNoExport;
    if (e.enclosingElement != null) return isExported(e.enclosingElement);
    return false;
  }

  @override
  visitLibraryElement(LibraryElement element) {
    if (isExported(element)) {
      exports.addLibrary(element);
    }
    super.visitLibraryElement(element);
  }

  @override
  visitTopLevelVariableElement(TopLevelVariableElement element) {
    if (isExported(element)) {
      exports.addTopLevelVariable(element);
    }
    super.visitTopLevelVariableElement(element);
  }

  @override
  visitFunctionElement(FunctionElement element) {
    if (isExported(element) && element.name.isNotEmpty) {
      exports.addFunction(element);
    }
    super.visitFunctionElement(element);
  }

  @override
  visitClassElement(ClassElement element) {
    if (isExported(element)) {
      exports.addClass(element);
    }
    super.visitClassElement(element);
  }

  @override
  visitConstructorElement(ConstructorElement element) {
    if (isExported(element)) {
      exports.addConstructor(element);
    }
    super.visitConstructorElement(element);
  }

  @override
  visitMethodElement(MethodElement element) {
    // TODO: optionally support operators (generate a name)
    // TODO: support static methods
    if (isExported(element) && !element.isOperator && !element.isStatic) {
      exports.addMethod(element);
    }
    super.visitMethodElement(element);
  }

  visitFieldElement(FieldElement element) {
    if (isExported(element) && !element.isStatic) {
      exports.addField(element);
    }
    super.visitFieldElement(element);
  }
}