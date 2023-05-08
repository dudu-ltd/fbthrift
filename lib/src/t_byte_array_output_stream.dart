// Copyright (c) 2023- All souce code authors. All rights reserved.
//
// This source code is licensed under Apache 2.0 License.

part of fbthrift;

/// An output stream that can be used to write bytes.
class TByteArrayOutputStream extends ByteArrayOutputStream {
  TByteArrayOutputStream([int initialSize = 32]) : super(initialSize);

  /// Returns the contents of this output stream as a [Int8List].
  Int8List get() {
    return buf;
  }

  /// Returns the contents of this output stream as a [Uint8List].
  int len() => count;
}
