// Copyright (c) 2023- All souce code authors. All rights reserved.
//
// This source code is licensed under Apache 2.0 License.

/// Interface for an output stream that can be used to write bytes.
abstract class OutputStream {
  void write(int b);

  void writeBytes(List<int> bs) {
    writeAll(bs, 0, bs.length);
  }

  void writeAll(List<int> bs, int off, int len) {
    if ((off < 0 || off > bs.length) ||
        (len < 0 || off + len > bs.length || off + len < 0)) {
      throw ArgumentError("The range exceeds the buffer length");
    } else if (len == 0) {
      return;
    }
    for (int i = off; i < off + len; i++) {
      write(bs[i]);
    }
  }

  void flush() {}
  void close();
}
