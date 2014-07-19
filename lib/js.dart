// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library js;

import 'dart:js';
export 'dart:js' show JsObject;

/**
 * Marks a library, variable, class, funciton or method declaration for export
 * to JavaScript. All children of the declaration are also exported, unless they
 * are marked with [DoNotExport].
 */
class Export {
final String as;
const Export({this.as});
}

/**
 * Overrides an [Export] annotation on a higher-level declaration to not export
 * the target declaration or its children.
 */
class NoExport {
const NoExport();
}

/**
 * The underlying dart:js global context. This is intended to be used by
 * generated code, so consider it semi-private.
 */
JsObject get jsContext => context;


/**
 * The base class of Dart interfaces for JavaScript objects.
 */
class JsInterface {}

/**
 * A metadata annotation to specify the JavaScript constructor associated with
 * a [JsInterface].
 */
class JsConstructor {
  final String constructor;
  const JsConstructor(this.constructor);
}

class JsGlobal {
  const JsGlobal();
}


Expando<JsInterface> _wrappers = new Expando<JsInterface>();

JsInterface getWrapper(JsObject o, JsInterface newWrapper(JsObject o)) {
  var wrapper = _wrappers[o];
  if (wrapper == null) {
    wrapper = _wrappers[o] = newWrapper(o);
  }
  return wrapper;
}
