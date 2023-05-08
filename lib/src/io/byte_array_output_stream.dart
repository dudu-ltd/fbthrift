// Copyright (c) 2023- All souce code authors. All rights reserved.
//
// This source code is licensed under Apache 2.0 License.

// ignore_for_file: non_constant_identifier_names

import 'dart:typed_data';

import './index.dart';

/// An output stream that can be used to write bytes.
class ByteArrayOutputStream extends OutputStream {
  late Int8List buf;
  int count = 0;
  late int _size;
  ByteArrayOutputStream([int size = 32]) {
    _size = size;
    if (size < 0) {
      throw ArgumentError("Negative initial size: $_size");
    }
    buf = Int8List(_size);
  }

  void _ensureCapacity(int minCapacity) {
    if (minCapacity - buf.length > 0) {
      _grow(minCapacity);
    }
  }

  static final int MAX_ARRAY_SIZE = 0x7fffffff - 8;

  void _grow(int minCapacity) {
    int oldCapacity = buf.length;
    int newCapacity = oldCapacity << 1;
    if (newCapacity - minCapacity < 0) {
      newCapacity = minCapacity;
    }
    if (newCapacity - MAX_ARRAY_SIZE > 0) {
      newCapacity = _hugeCapacity(minCapacity);
    }
  }

  static int _hugeCapacity(int minCapacity) {
    if (minCapacity < 0) {
      throw ArgumentError("Negative minCapacity: $minCapacity");
    }
    return minCapacity > MAX_ARRAY_SIZE ? 0x7fffffff : MAX_ARRAY_SIZE;
  }

  @override
  void close() {}

  @override
  void write(int b) {
    _ensureCapacity(count + 1);
    buf[count] = b;
    count += 1;
  }

  @override
  void writeAll(List<int> bs, [int off = 0, int? len]) {
    len ??= bs.length;
    if ((off < 0) ||
        (off > bs.length) ||
        (len < 0) ||
        ((off + len) - bs.length > 0)) {
      throw ArgumentError("Index out of bounds");
    }
    _ensureCapacity(count + len);
    buf.setRange(count, count + len, bs, off);
    count += len;
  }

  void writeTo(OutputStream out) {
    out.writeAll(buf, 0, count);
  }

  void reset() {
    buf = Int8List(_size);
    count = 0;
  }

  Int8List toByteArray() {
    return Int8List.fromList(buf.sublist(0, count));
  }

  int size() {
    return count;
  }
}
