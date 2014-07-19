// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library js.transformer.typed_interface_finder;

import 'package:analyzer/src/generated/element.dart';
import 'package:logging/logging.dart';

final _logger = new Logger('js.transformer.interface_transformer');

class TypedInterfaceFinder extends RecursiveElementVisitor {
  final ClassElement exportClass;
  final ClassElement noExportClass;
  final ClassElement jsInterfaceClass;
  final Set<ClassElement> jsInterfaces = new Set<ClassElement>();

  final LibraryElement entryLibrary;

  TypedInterfaceFinder(this.entryLibrary, this.jsInterfaceClass,
      this.exportClass, this.noExportClass);

  bool get importsJsInterfaces => jsInterfaceClass != null;

  @override
  @override
  visitLibraryElement(LibraryElement element) {
    // We don't visit other libraries, since this transformer runs on each
    // library separately. We also only run on libraries that have
    // JsInterface available.
    if (element == entryLibrary && importsJsInterfaces) {
      super.visitLibraryElement(element);
    }
  }

  bool isJsInterface(ClassElement e) {
    if (e.isPrivate) return false;
    bool isJsInterface = false;

    if (e.allSupertypes.contains(jsInterfaceClass.type)) {
      isJsInterface = true;
    }

    if (isJsInterface) {
      for (var m in e.metadata) {
        if (m.element.kind == ElementKind.CONSTRUCTOR) {
          if (m.element.enclosingElement == exportClass) {
            _logger.warning('@Export() on a JsInterface');
          } else if (m.element.enclosingElement == noExportClass) {
            _logger.warning('@NoExport() on a JsInterface');
          }
        }
      }
    }

    return isJsInterface;
  }

  @override
  visitClassElement(ClassElement element) {
    if (isJsInterface(element)) {
      jsInterfaces.add(element);
    }
    super.visitClassElement(element);
  }

}
