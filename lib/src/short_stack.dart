/*
 * Copyright (c) Facebook, Inc. and its affiliates.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 * 
 * Translated from thrift java lang code: ShortStack.java by [CorvusYe](CorvusY@foxmail.com)
 */

part of fbthrift;

class ShortStack {
  late Int16List _vector;
  int _top = -1;

  ShortStack(int size) {
    _vector = Int16List(size);
  }

  int pop() => _vector[_top--].toSigned(16);

  void push(int value) {
    if (_top == _vector.length - 1) {
      _grow();
    }
    _vector[++_top] = value.toSigned(16);
  }

  void _grow() {
    var newVector = Int16List(_vector.length * 2);
    newVector.setRange(0, _vector.length, _vector);
    _vector = newVector;
  }

  int peek() => _vector[_top].toSigned(16);

  void clear() => _top = -1;

  @override
  String toString() {
    StringBuffer sb = StringBuffer();
    sb.write('<ShortStack vector:[');
    for (int i = 0; i < _vector.length; i++) {
      if (i > 0) {
        sb.write(' ');
      }
      if (i == _top) {
        sb.write('>>');
      }

      sb.write(_vector[i]);

      if (i == _top) {
        sb.write('<<');
      }
    }

    sb.write(']>');

    return sb.toString();
  }
}
