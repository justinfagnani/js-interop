// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

var x = 42;

var myArray = ["value1"];

var foreignDoc = (function(){
  var doc = document.implementation.createDocument("", "root", null);
  var element = doc.createElement('element');
  element.setAttribute('id', 'abc');
  doc.documentElement.appendChild(element);
  return doc;
})();
  
function razzle() {
  return x;
}

function Foo(a) {
  this.a = a;
}

Foo.prototype.bar = function() {
  return this.a;
}

function isArray(a) {
  return a instanceof Array;
}

function checkMap(m, key, value) {
  if (m.hasOwnProperty(key))
    return m[key] == value;
  else
    return false;
}

function invokeCallback() {
  return callback();
}

function returnElement(element) {
  return element;
}

function getElementAttribute(element, attr) {
  return element.getAttribute(attr);
}

function addClassAttributes(list) {
  var result = "";
  for (var i=0; i<list.length; i++) {
    result += list[i].getAttribute("class");
  }
  return result;
}

function getNewDivElement() {
  return document.createElement("div");
}

function testJsMap(callback) {
  var result = callback();
  return result['value'];
}

function Bar() {
  return "ret_value";
}
Bar.foo = "property_value";
