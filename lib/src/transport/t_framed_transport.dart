/// Licensed to the Apache Software Foundation (ASF) under one
/// or more contributor license agreements. See the NOTICE file
/// distributed with this work for additional information
/// regarding copyright ownership. The ASF licenses this file
/// to you under the Apache License, Version 2.0 (the
/// "License"); you may not use this file except in compliance
/// with the License. You may obtain a copy of the License at
///
/// http://www.apache.org/licenses/LICENSE-2.0
///
/// Unless required by applicable law or agreed to in writing,
/// software distributed under the License is distributed on an
/// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
/// KIND, either express or implied. See the License for the
/// specific language governing permissions and limitations
/// under the License.

// ignore_for_file: constant_identifier_names

part of fbthrift;

/// Framed [TTransport].
///
/// Adapted from the Java Framed transport.
class TFramedTransport extends TTransport {
  static const int DEFAULT_MAX_LENGTH = 0x7FFFFFFF;
  int maxLength_ = 0;
  late TTransport transport_;

  late TByteArrayOutputStream writeBuffer_;
  TMemoryInputTransport? readBuffer_ = TMemoryInputTransport(Int8List(0));

  TFramedTransport(TTransport transport, [int maxLength = DEFAULT_MAX_LENGTH]) {
    transport_ = transport;
    maxLength_ = maxLength;
    writeBuffer_ = TByteArrayOutputStream(1024);
    transport_.inFrame = true;
  }

  @override
  Future open() => transport_.open();

  @override
  bool get isOpen => transport_.isOpen;

  @override
  Future close() => transport_.close();

  @override
  int read(Int8List buffer, int offset, int length) {
    int got = readBuffer_?.read(buffer, offset, length) ?? 0;
    if (got > 0) {
      return got;
    }

    // Read another frame of data
    readFrame();
    return readBuffer_?.read(buffer, offset, length) ?? 0;
  }

  @override
  Int8List? getBuffer() => readBuffer_?.getBuffer();

  @override
  int getBufferPosition() => readBuffer_?.getBufferPosition() ?? 0;

  @override
  int getBytesRemainingInBuffer() =>
      readBuffer_?.getBytesRemainingInBuffer() ?? 0;

  @override
  void consumeBuffer(int len) => readBuffer_?.consumeBuffer(len);

  final Int8List i32buf = Int8List(4);

  Future readFrame() async {
    transport_.readAll(i32buf, 0, 4);
    int size = decodeWord(i32buf, 0);

    if (size < 0) {
      throw TTransportError(TTransportErrorType.NEGATIVE_SIZE,
          "Read a negative frame size $size");
    }

    if (size > maxLength_) {
      throw TTransportError(TTransportErrorType.UNKNOWN,
          "Frame size $size larger than max length $maxLength_");
    }

    final Int8List buff = Int8List(size);
    transport_.readAll(buff, 0, size);
    readBuffer_?.reset(buf: buff);
  }

  @override
  void write(Int8List buffer, int offset, int length) {
    writeBuffer_.writeAll(buffer, offset, length);
  }

  @override
  Future flush([bool oneway = false]) {
    final Int8List buff = writeBuffer_.buf;
    final int size = writeBuffer_.len();
    writeBuffer_.reset();

    encodeWord(size, i32buf, 0);
    transport_.write(i32buf, 0, 4);
    transport_.write(buff, 0, size);
    return transport_.flush(oneway);
  }

  /// Decode a big-endian 32-bit integer from an [Int8List].
  static int decodeWord(final Int8List buf, [int off = 0]) {
    return ((buf[0 + off] & 0xff) << 24) |
        ((buf[1 + off] & 0xff) << 16) |
        ((buf[2 + off] & 0xff) << 8) |
        ((buf[3 + off] & 0xff));
  }

  /// Decode a big-endian 16-bit integer from an [Int8List].
  static int decodeShort(final Int8List buf, int off) {
    return (((buf[0 + off] & 0xff) << 8) | ((buf[1 + off] & 0xff)));
  }

  /// Encode a big-endian 32-bit integer into an [Int8List].
  static void encodeWord(final int n, final Int8List buf, [int off = 0]) {
    buf[0 + off] = ((n >> 24) & 0xff);
    buf[1 + off] = ((n >> 16) & 0xff);
    buf[2 + off] = ((n >> 8) & 0xff);
    buf[3 + off] = ((n) & 0xff);
  }

  /// Encode a big-endian 16-bit integer into an [Int8List].
  static void encodeShort(final int value, final Int8List buf) {
    buf[0] = (0xff & (value >> 8)).toSigned(8);
    buf[1] = (0xff & (value)).toSigned(8);
  }
}

/// Factory for framed [TTransport]s.
class TFramedTransportFactory extends TTransportFactory {
  late int maxLength_;

  TFramedTransportFactory(
      [int maxLength = TFramedTransport.DEFAULT_MAX_LENGTH]) {
    maxLength_ = maxLength;
  }

  @override
  // ignore: avoid_renaming_method_parameters
  Future<TTransport> getTransport(TTransport base) {
    return Future.value(TFramedTransport(base, maxLength_));
  }
}
