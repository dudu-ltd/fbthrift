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

part of fbthrift;

abstract class TTransport {
  /// Queries whether the transport is open.
  /// Returns [true] if the transport is open.
  bool get isOpen;

  /// Marks the end of the a message, if applicable.
  bool inFrame = false;

  /// Opens the transport for reading/writing.
  /// Throws [TTransportError] if the transport could not be opened.
  Future open();

  /// Closes the transport.
  Future close();

  /// Reads up to [length] bytes into [buffer], starting at [offset].
  /// Returns the number of bytes actually read.
  /// Throws [TTransportError] if there was an error reading data
  int read(Int8List buffer, int offset, int length);

  /// Guarantees that all of [length] bytes are actually read off the transport.
  /// Returns the number of bytes actually read, which must be equal to
  /// [length].
  /// Throws [TTransportError] if there was an error reading data
  int readAll(Int8List buffer, int offset, int length) {
    int got = 0;
    int ret = 0;
    while (got < length) {
      ret = read(buffer, offset + got, length - got);
      if (ret <= 0) {
        throw TTransportError(
            TTransportErrorType.UNKNOWN,
            "Cannot read. Remote side has closed. Tried to read $length "
            "bytes, but only got $got bytes.");
      }
      got += ret;
    }
    return got;
  }

  /// Writes up to [len] bytes from the buffer.
  /// Throws [TTransportError] if there was an error writing data
  void write(Int8List buffer, int offset, int length);

  /// Writes the [bytes] to the output.
  /// Throws [TTransportError] if there was an error writing data
  void writeAll(Int8List buffer) async {
    write(buffer, 0, buffer.length);
  }

  /// Flush any pending data out of a transport buffer.
  /// Throws [TTransportError] if there was an error writing out data.
  Future flush([bool oneway = false]);

  /// Returns the number of bytes available in the write buffer.
  int getBytesRemainingInBuffer() {
    return -1;
  }

  /// Returns the bytes list
  Int8List? getBuffer() {
    return null;
  }

  /// Returns the position in the buffer.
  int getBufferPosition() {
    return 0;
  }

  /// Consume [len] bytes from the buffer.
  void consumeBuffer(int len) {}
}
