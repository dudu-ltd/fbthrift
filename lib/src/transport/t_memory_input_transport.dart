// Copyright (c) 2023- All souce code authors. All rights reserved.
//
// This source code is licensed under Apache 2.0 License.

part of fbthrift;

/// Memory input transport.
class TMemoryInputTransport extends TTransport {
  Int8List? _buf;
  int _pos = 0;
  int _endPos = 0;

  TMemoryInputTransport([this._buf]) {
    reset(buf: _buf);
  }

  void reset({Int8List? buf, int offset = 0, int? length}) {
    _buf = buf;
    _pos = offset;
    _endPos = offset + (length ?? (buf?.length ?? 0));
  }

  @override
  Future<void> close() => Future<void>.value();

  @override
  Future flush() => throw UnimplementedError();

  @override
  bool get isOpen => true;

  @override
  Future<void> open() => Future<void>.value();

  @override
  int read(Int8List buffer, int offset, int length) {
    int bytesRemaining = bytesRemainingInBuffer;
    int amtToRead = (length > bytesRemaining) ? bytesRemaining : length;
    if (amtToRead > 0) {
      buffer.setRange(offset, offset + amtToRead, _buf!, _pos);
      consumeBuffer(amtToRead);
    }
    return amtToRead;
  }

  @override
  Future<void> write(Int8List buffer, int offset, int length) {
    throw Exception("No writing allowed!");
  }

  Int8List get buffer => _buf!;

  int get bufferPosition => _pos;

  int get bytesRemainingInBuffer => _endPos - _pos;

  @override
  void consumeBuffer(int len) {
    _pos += len;
  }
}
