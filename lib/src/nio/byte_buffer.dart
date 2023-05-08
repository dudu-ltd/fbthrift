// Copyright (c) 2023- All souce code authors. All rights reserved.
//
// This source code is licensed under Apache 2.0 License.

// ignore_for_file: non_constant_identifier_names

import 'dart:math';
import 'dart:typed_data';

abstract class Spliterator {
  static final int ORDERED = 0x00000010;

  static final int DISTINCT = 0x00000001;

  static final int SORTED = 0x00000004;

  static final int SIZED = 0x00000040;

  static final int NONNULL = 0x00000100;

  static final int IMMUTABLE = 0x00000400;

  static final int CONCURRENT = 0x00001000;

  static final int SUBSIZED = 0x00004000;
}

abstract class Buffer {
  static final int SPLITERATOR_CHARACTERISTICS =
      Spliterator.SIZED | Spliterator.SUBSIZED | Spliterator.ORDERED;

  int _mark = -1;
  int _position = 0;
  int _limit = 0;
  int _capacity = 0;

  int address = 0;

  Buffer(int mark, int pos, int lim, int cap) {
    if (cap < 0) throw ArgumentError("Negative capacity: $cap");
    _capacity = cap;
    limit = lim;
    position = pos;
    if (mark >= 0) {
      if (mark > pos) throw ArgumentError("mark > position: ($mark > $pos)");
      _mark = mark;
    }
  }

  get capacity => _capacity;

  int get position => _position;

  set position(int newPosition) {
    if (newPosition > _limit || newPosition < 0) {
      throw ArgumentError("Bad position: $newPosition");
    }
    _position = newPosition;
    if (_mark > newPosition) _mark = -1;
  }

  int get limit => _limit;

  set limit(int newLimit) {
    if ((newLimit > _capacity) || (newLimit < 0)) {
      throw ArgumentError("Bad limit: $newLimit");
    }
    _limit = newLimit;
    if (_position > newLimit) _position = newLimit;
    if (_mark > newLimit) _mark = -1;
  }

  Buffer mark() {
    _mark = _position;
    return this;
  }

  Buffer reset() {
    int m = _mark;
    if (m < 0) throw StateError("Mark not set");
    _position = m;
    return this;
  }

  Buffer clear() {
    _position = 0;
    _limit = _capacity;
    _mark = -1;
    return this;
  }

  Buffer flip() {
    _limit = _position;
    _position = 0;
    _mark = -1;
    return this;
  }

  Buffer rewind() {
    _position = 0;
    _mark = -1;
    return this;
  }

  int remaining() => _limit - _position;

  bool hasRemaining() => _position < _limit;

  bool get readOnly;

  bool hasArray();

  dynamic array();

  int arrayOffset();

  bool isDirect();

  int nextGetIndex([int? nb]) {
    if (nb == null) {
      if (_position >= _limit) throw StateError("Buffer underflow");
      return _position++;
    } else {
      if (_limit - _position < nb) throw StateError("Buffer underflow");
      int p = _position;
      _position += nb;
      return p;
    }
  }

  int nextPutIndex([int? nb]) {
    if (nb == null) {
      if (_position >= _limit) throw StateError("Buffer overflow");
      return _position++;
    } else {
      if (_limit - _position < nb) throw StateError("Buffer overflow");
      int p = _position;
      _position += nb;
      return p;
    }
  }

  int checkIndex(int? i, [int? nb]) {
    i ??= 0;
    if (nb == null) {
      if (i < 0 || i >= _limit) throw RangeError("Index out of bounds: $i");
    } else {
      if ((i < 0) || (i + nb > _limit)) {
        throw RangeError("Index out of bounds: $i");
      }
    }
    return i;
  }

  int get markValue => _mark;

  void truncate() {
    _mark = -1;
    _position = 0;
    _limit = 0;
    _capacity = 0;
  }

  void discardMark() => _mark = -1;

  static void checkBounds(int? off, int? len, int? size) {
    off ??= 0;
    len ??= 0;
    size ??= 0;
    if ((off | len | (off + len) | (size - (off + len))) < 0) {
      throw RangeError("off: $off, len: $len, size: $size");
    }
  }
}

abstract class ByteBuffer extends Buffer implements Comparable<ByteBuffer> {
  final Int8List hb;
  final int offset;
  final bool isReadOnly;

  ByteBuffer(
    int mark,
    int pos,
    int lim,
    int cap,
    this.hb,
    int? offset,
  )   : offset = offset ?? 0,
        isReadOnly = false,
        super(mark, pos, lim, cap);

  static ByteBuffer wrap(Int8List array, [int? offset, int? length]) {
    try {
      return HeapByteBuffer(array, offset ?? 0, length ?? array.length);
    } catch (e) {
      throw ArgumentError(e);
    }
  }

  ByteBuffer slice();
  ByteBuffer duplicate();
  ByteBuffer asReadOnlyBuffer();
  ByteBuffer put({required int b, int index});
  int get({int length, int offset, Int8List dst});

  ByteBuffer putSrc(ByteBuffer src) {
    if (src == this) throw ArgumentError();
    if (isReadOnly) throw StateError("Read only buffer");
    int n = src.remaining();
    if (n > remaining()) throw StateError("Buffer overflow");
    for (var i = 0; i < n; i++) {
      put(b: src.get());
    }
    return this;
  }

  ByteBuffer putByte(Int8List src, [int? offset, int? length]) {
    offset ??= 0;
    length ??= src.length;
    Buffer.checkBounds(offset, length, src.length);
    if (length > remaining()) throw StateError("Buffer overflow");
    int end = offset + length;
    for (int i = offset; i < end; i++) {
      put(b: src[i]);
    }
    return this;
  }

  @override
  bool hasArray() => !isReadOnly;

  @override
  Int8List array() {
    // if (hb == null) throw StateError("No backing array");
    if (isReadOnly) throw StateError("Read only buffer");
    return hb;
  }

  @override
  int arrayOffset() {
    // if (hb == null) throw StateError("No backing array");
    if (isReadOnly) throw StateError("Read only buffer");
    return offset;
  }

  ByteBuffer compact();

  @override
  bool isDirect();

  @override
  String toString() {
    StringBuffer sb = StringBuffer();
    sb.write(runtimeType);
    sb.write('[pos=');
    sb.write('$position');
    sb.write(' lim=');
    sb.write('$limit');
    sb.write(' cap=');
    sb.write('$capacity');
    sb.write(']');
    return sb.toString();
  }

  @override
  int get hashCode {
    int h = 1;
    int p = position;
    for (int i = limit - 1; i >= p; i--) {
      h = 31 * h + get(length: i);
    }
    return h;
  }

  @override
  bool operator ==(Object other) {
    if (hashCode == other.hashCode) return true;
    if (other is! ByteBuffer) return false;
    ByteBuffer that = other;
    if (remaining() != that.remaining()) return false;
    int p = position;
    for (int i = limit - 1, j = that.limit - 1; i >= p; i--, j--) {
      if (get(length: i) != that.get(length: j)) return false;
    }
    return true;
  }

  @override
  int compareTo(ByteBuffer that) {
    int n = position + min(remaining(), that.remaining());
    for (int i = position, j = position; i < n; i++, j++) {
      int cmp = get(length: i).compareTo(that.get(length: j));
      if (cmp != 0) return cmp;
    }
    return remaining() - that.remaining();
  }

  bool bigEndian = true;
  bool nativeByteOrder = (Endian.host == Endian.big);

  Endian order([Endian? endian]) {
    if (endian == null) return bigEndian ? Endian.big : Endian.little;
    bigEndian = (endian == Endian.big);
    nativeByteOrder = (bigEndian == (Endian.host == Endian.big));
    return endian;
  }

  int getInt([int index]);
  ByteBuffer putInt(int value, [int index]);

  double getDouble([int index]);
  ByteBuffer putDouble(double value, [int index]);

  static ByteBuffer allocate(int capacity) {
    if (capacity < 0) throw ArgumentError("Negative capacity: $capacity");
    return HeapByteBuffer.byCapAndLim(capacity, capacity);
  }
}

class HeapByteBuffer extends ByteBuffer {
  HeapByteBuffer(Int8List buf, int off, int len)
      : super(-1, off, off + len, buf.length, buf, 0);

  HeapByteBuffer.full(
      Int8List buf, int mark, int pos, int lim, int cap, int off)
      : super(mark, pos, lim, cap, buf, off);

  HeapByteBuffer.byCapAndLim(int cap, int lim)
      : super(-1, 0, lim, cap, Int8List(cap), 0);

  int ix(int i) => i + offset;

  @override
  int get({int? length, int? offset, Int8List? dst}) {
    if (dst == null && offset == null && length == null) {
      return hb[ix(nextGetIndex())];
    }
    if (dst == null && offset == null) {
      return hb[ix(checkIndex(length))];
    }
    offset ??= 0;
    Buffer.checkBounds(offset, length, dst?.length);
    if (length! > remaining()) throw StateError("Buffer underflow");
    dst?.setRange(offset, offset + length, hb, _position);
    position = position + length;
    return length;
  }

  @override
  bool isDirect() => false;

  @override
  bool get readOnly => false;

  @override
  ByteBuffer asReadOnlyBuffer() {
    return HeapByteBuffer(hb, offset, capacity)
      ..position = position
      ..limit = limit
      ..markValue;
  }

  @override
  ByteBuffer compact() {
    hb.setRange(0, remaining(), hb, ix(position));
    position = remaining();
    limit = capacity;
    discardMark();
    return this;
  }

  @override
  ByteBuffer duplicate() {
    return HeapByteBuffer(hb, offset, capacity)
      ..position = position
      ..limit = limit
      ..markValue;
  }

  @override
  ByteBuffer put({int b = 0, int? index}) {
    hb[ix(nextPutIndex(index))] = b;
    return this;
  }

  @override
  ByteBuffer slice() {
    return HeapByteBuffer.full(
        hb, -1, 0, remaining(), remaining(), ix(position));
  }

  @override
  int getInt([int? index]) {
    var off = index == null ? ix(nextGetIndex(4)) : ix(checkIndex(index, 4));
    return ByteData.view(hb.buffer, off).getInt32(0);
  }

  @override
  ByteBuffer putInt(int value, [int? index]) {
    var off = index == null ? ix(nextPutIndex(4)) : ix(checkIndex(index, 4));
    ByteData.view(hb.buffer, off).setInt32(0, value);
    return this;
  }

  @override
  double getDouble([int? index]) {
    var off = index == null ? ix(nextGetIndex(8)) : ix(checkIndex(index, 8));
    return ByteData.view(hb.buffer, off).getFloat64(0);
  }

  @override
  ByteBuffer putDouble(double value, [int? index]) {
    var off = index == null ? ix(nextPutIndex(8)) : ix(checkIndex(index, 8));
    ByteData.view(hb.buffer, off).setFloat64(0, value);
    return this;
  }
}
