// Copyright (c) 2023- All souce code authors. All rights reserved.
//
// This source code is licensed under Apache 2.0 License.

part of fbthrift;

/// This is the most commonly used base transport.
/// It takes an InputStream and an OutputStream and uses those to perform all transport operations.
///  This allows for compatibility with all the nice constructs Dart already has to provide a variety of types of streams.
class TIOStreamTransport extends TTransport {
  List<int?>? _inputBuffer;
  List<Int8List>? outputBuffer;
  Iterator<int?>? _readIterator;

  TIOStreamTransport();

  set inputBuffer(List<int?>? inputBuffer) {
    _inputBuffer = inputBuffer;
    _readIterator = _inputBuffer?.iterator;
  }

  List<int?>? get inputBuffer => _inputBuffer;

  @override
  bool get isOpen => true;

  @override
  Future open() async {}

  @override
  Future close() async {}

  /// Reads from the underlying input stream if not null.
  @override
  int read(Int8List? buffer, int? offset, int? length) {
    offset ??= 0;
    length ??= 0;
    if (buffer == null) {
      throw ArgumentError.notNull("buffer");
    }

    if (offset + length > buffer.length) {
      throw ArgumentError("The range exceeds the buffer length");
    }

    if (_readIterator == null || length <= 0) {
      return 0;
    }

    int i = 0;
    while (i < length && (_readIterator?.moveNext() ?? false)) {
      buffer[offset + i] = (_readIterator?.current ?? 0);
      i++;
    }

    // cleanup iterator when we've reached the end
    if (_readIterator?.current == null) {
      _readIterator = null;
    }

    return i;
  }

  /// Writes to the underlying output stream if not null.
  @override
  void write(Int8List buffer, int offset, int length) {
    if (outputBuffer == null) {
      throw TTransportError(
          TTransportErrorType.NOT_OPEN, "Cannot write to null buffer");
    }

    if (offset + length > buffer.length) {
      throw ArgumentError("The range exceeds the buffer length");
    }

    outputBuffer?.add(buffer.sublist(offset, offset + length));
  }

  @override
  Future flush() {
    return Future.value();
  }
}
