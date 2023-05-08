// Copyright (c) 2023- All souce code authors. All rights reserved.
//
// This source code is licensed under Apache 2.0 License.

// ignore_for_file: constant_identifier_names, unused_field, non_constant_identifier_names, overridden_fields

part of fbthrift;

/// An transport that allows for a variable-length frame header followed by an
/// arbitrary number of frames.
/// Creatint 2pc as [TFramedTransport]
class THeaderTransport extends TFramedTransport {
  static const int HEADER_MAGIC_MASK = 0xffff0000;
  static const int HEADER_FLAGS_MASK = 0x0000ffff;
  static const int HEADER_MAGIC = 0x0FFF0000;
  static const int HTTP_SERVER_MAGIC = 0x504F5354;
  static const int MAX_FRAME_SIZE = 0x3FFFFFFF;
  int _zlibBufferSize = 512;
  static const int T_BINARY_PROTOCOL = 0;
  static const int T_JSON_PROTOCOL = 1;
  static const int T_COMPACT_PROTOCOL = 2;

  static final int numClientTypes = 4;
  int _protoId = T_COMPACT_PROTOCOL;
  final ClientTypes _clientType = ClientTypes.HEADERS;
  int _seqId = 0;
  int _flags = 0;

  final List<bool> _supportedClients;
  final List<Transforms> _writeTransforms;
  List<int> _readTransforms;
  final Map<String, String> _readHeaders;
  final Map<String, String> _readPersistentHeaders;
  final Map<String, String> _writeHeaders;
  final Map<String, String> _writePersistentHeaders;

  static final String IDENTITY_HEADER = "identity";
  static final String ID_VERSION_HEADER = "id_version";
  static final String ID_VERSION = "1";

  ClientTypes clientType = ClientTypes.HEADERS;

  String? _identity;

  THeaderTransport({
    required TTransport transport,
    List<bool>? supportedClients,
    List<Transforms>? writeTransforms,
    List<int>? readTransforms,
    Map<String, String>? readHeaders,
    Map<String, String>? readPersistentHeaders,
    Map<String, String>? writeHeaders,
    Map<String, String>? writePersistentHeaders,
    List<ClientTypes>? clientTypes,
  })  : _writeTransforms = writeTransforms ?? <Transforms>[],

        // Always supported headers
        _supportedClients =
            supportedClients ?? List<bool>.filled(numClientTypes, false),
        _writeHeaders = writeHeaders ?? <String, String>{},
        _writePersistentHeaders = writePersistentHeaders ?? <String, String>{},
        _readTransforms = readTransforms ?? <int>[],
        _readHeaders = readHeaders ?? <String, String>{},
        _readPersistentHeaders = readPersistentHeaders ?? <String, String>{},
        super(transport) {
    _supportedClients[ClientTypes.HEADERS.value] = true;

    if (clientTypes != null) {
      for (ClientTypes t in clientTypes) {
        _supportedClients[t.value] = true;
      }
    }
  }

  TTransport get underlyingTransport => transport_;

  int get protocolId {
    if (_clientType == ClientTypes.HEADERS) {
      return _protoId;
    } else {
      return 0;
    }
  }

  set protocolId(int protoId) => _protoId = protoId;

  set zlibBufferSize(int sz) => _zlibBufferSize = sz;

  void addTransform(Transforms transform) => _writeTransforms.add(transform);

  void setHeader(String key, String value) => _writeHeaders[key] = value;

  Map<String, String> get writeHeaders => _writeHeaders;

  /// Set a persistent header. Persistent headers are sent with every request.
  void setPersistentHeader(String key, String value) =>
      _writePersistentHeaders[key] = value;

  /// Get a persistent header when sending requests.
  Map<String, String> get writePersistentHeaders => _writePersistentHeaders;

  /// Get a persistent header when receiving requests.
  Map<String, String> get readPersistentHeaders => _readPersistentHeaders;

  Map<String, String> get headers => _readHeaders;

  void clearHeaders() => _writeHeaders.clear();

  void clearPersistentHeaders() => _writePersistentHeaders.clear();

  String? get peerIdentity {
    if (_readHeaders.containsKey(IDENTITY_HEADER) &&
        ID_VERSION == _readHeaders[ID_VERSION_HEADER]) {
      return _readHeaders[IDENTITY_HEADER];
    }
    return null;
  }

  set identity(String identity) => _identity = identity;

  @override
  int read(Int8List buffer, int offset, int length) {
    if (readBuffer_ != null) {
      int got = readBuffer_?.read(buffer, offset, length) ?? 0;
      if (got > 0) {
        return got;
      }
    }
    readFrame();
    return readBuffer_?.read(buffer, offset, length) ?? 0;
  }

  @override
  final Int8List i32buf = Int8List(4);

  @override
  Future readFrame() async {
    transport_.readAll(i32buf, 0, 4);
    int word1 = TFramedTransport.decodeWord(i32buf);

    if ((word1 & TBinaryProtocol.VERSION_MASK) == TBinaryProtocol.VERSION_1) {
      throw TTransportError(null, "This transport does not support Unframed");
    } else if (word1 == HTTP_SERVER_MAGIC) {
      throw TTransportError(null, "This transport does not support HTTP");
    } else {
      if (word1 - 4 > MAX_FRAME_SIZE) {
        // special case for the most common question in user-group
        // this will probably saves hours of engineering effort.
        int magic1 = 0x61702048; // ASCII "ap H" in little endian
        int magic2 = 0x6C6C6F63; // ASCII "lloc" in little endian
        if (word1 == magic1 || word1 == magic2) {
          throw TTransportError(null,
              "The Thrift server received an ASCII request and safely ignored it. In all likelihood, this isn't the reason of your problem (probably a local daemon sending HTTP content to all listening ports).");
        }
        throw TTransportError(null, "Framed transport frame is too large");
      }

      // Could be framed or header format.  Check next word.
      transport_.readAll(i32buf, 0, 4);
      int version = TFramedTransport.decodeWord(i32buf);
      if ((version & TBinaryProtocol.VERSION_MASK) ==
          TBinaryProtocol.VERSION_1) {
        clientType = ClientTypes.FRAMED_DEPRECATED;
        Int8List buff = Int8List(word1);
        buff.setRange(0, 4, i32buf);

        transport_.readAll(buff, 4, word1 - 4);
        readBuffer_?.reset(buf: buff);
      } else if ((version & HEADER_MAGIC_MASK) == HEADER_MAGIC) {
        clientType = ClientTypes.HEADERS;
        if (word1 - 4 < 10) {
          throw TTransportError(null, "Header transport frame is too small");
        }
        Int8List buff = Int8List(word1);
        buff.setRange(0, 4, i32buf);

        // read packet minus version
        transport_.readAll(buff, 4, word1 - 4);

        _flags = version & HEADER_FLAGS_MASK;
        // read seqId
        _seqId = TFramedTransport.decodeWord(buff, 4);
        int headerSize = TFramedTransport.decodeShort(buff, 8);

        readHeaderFormat(headerSize, buff);
      } else {
        clientType = ClientTypes.UNKNOWN;
        throw TTransportError(null, "Unsupported client type");
      }
    }
  }

  nio.ByteBuffer transform(nio.ByteBuffer data) {
    if (_writeTransforms.contains(Transforms.ZLIB_TRANSFORM)) {
      throw UnimplementedError();
      // Int8List output = Int8List(data.limit + 512);
      // OutputStreamBase out = OutputStream( data.bigEndian);
      // zip.ZLibEncoder encoder = zip.ZLibEncoder();

      // try {
      //   var input = data.hb.getRange(data.position, data.hb.length);
      //   encoder.encode(Int8List.fromList(input), output: output);
      // } finally {
      //   encoder.
      // }
    }
    return data;
  }

  /// 获取表头长度
  int getWriteHeadersSize(Map<String, String> headers) {
    if (headers.isEmpty) {
      return 0;
    }
    int len = 10;

    for (var header in headers.entries) {
      len += 10;
      len += header.key.length;
      len += header.value.length;
    }
    return len;
  }

  /// 写入表头
  nio.ByteBuffer flushInfoHeaders(Infos info, Map<String, String> headers) {
    nio.ByteBuffer infoData =
        nio.ByteBuffer.allocate(getWriteHeadersSize(headers));
    if (headers.isNotEmpty) {
      writeVarint(infoData, info.value);
      writeVarint(infoData, headers.length);
      for (var pairs in headers.entries) {
        writeString(infoData, pairs.key);
        writeString(infoData, pairs.value);
      }
      headers.clear();
    }
    infoData.limit = infoData.position;
    infoData.position = 0;
    return infoData;
  }

  @override
  Future flush([bool oneway = false]) async {
    try {
      TApplicationError? tae;
      Int8List buf = writeBuffer_.get();
      // writeBuffer_.clear();
      int len = writeBuffer_.len();
      if (len >= 2 &&
          buf[0] == TCompactProtocol.PROTOCOL_ID &&
          ((buf[1] >> TCompactProtocol.TYPE_SHIFT_AMOUNT) & 0x03) ==
              TMessageType.EXCEPTION) {
        TCompactProtocol proto = TCompactProtocol(TMemoryInputTransport(buf));
        // ignore: unused_local_variable
        TMessage msg = proto.readMessageBegin();
        tae = TApplicationError.read(proto);
      } else if (len >= 4 &&
          ((buf[0] << 24) | (buf[1] << 16)) == TBinaryProtocol.VERSION_1 &&
          buf[3] == TMessageType.EXCEPTION) {
        TBinaryProtocol proto = TBinaryProtocol(TMemoryInputTransport(buf));
        // ignore: unused_local_variable
        TMessage msg = proto.readMessageBegin();
        tae = TApplicationError.read(proto);
      }
      if (tae != null) {
        if (!_writeHeaders.containsKey('uex')) {
          _writeHeaders['uex'] = "TApplicationError";
        }
        if (!_writeHeaders.containsKey('uexw')) {
          _writeHeaders['uexw'] = tae.message ?? '[null]';
        }
      }
    } catch (e) {
      // ignore
    }

    nio.ByteBuffer frame = nio.ByteBuffer.wrap(writeBuffer_.get());
    frame.limit = writeBuffer_.len();
    writeBuffer_.reset();

    if (clientType == ClientTypes.HEADERS) {
      frame = transform(frame);
    }

    if (frame.remaining() > MAX_FRAME_SIZE) {
      throw TTransportError(null, "Frame size exceeds max length");
    }

    if (_protoId == T_JSON_PROTOCOL && clientType != ClientTypes.HTTP) {
      throw TTransportError(null, "Trying to send JSON encoding over binary");
    }

    if (clientType == ClientTypes.HEADERS) {
      nio.ByteBuffer transformData =
          nio.ByteBuffer.allocate(_writeTransforms.length * 5);

      int numTransforms = _writeTransforms.length;
      for (Transforms trans in _writeTransforms) {
        writeVarint(transformData, trans.value);
      }
      transformData.limit = transformData.position;
      transformData.position = 0;

      if (_identity != null && _identity!.isNotEmpty) {
        _writeHeaders[ID_VERSION_HEADER] = ID_VERSION;
        _writeHeaders[IDENTITY_HEADER] = _identity!;
      }

      nio.ByteBuffer infoData1 =
          flushInfoHeaders(Infos.INFO_PKEYVALUE, _writePersistentHeaders);
      nio.ByteBuffer infoData2 =
          flushInfoHeaders(Infos.INFO_KEYVALUE, _writeHeaders);

      nio.ByteBuffer headerData = nio.ByteBuffer.allocate(10);
      writeVarint(headerData, _protoId);
      writeVarint(headerData, numTransforms);
      headerData.limit = headerData.position;
      headerData.position = 0;

      int headerSize = transformData.remaining() +
          infoData1.remaining() +
          infoData2.remaining() +
          headerData.remaining();

      int paddingSize = 4 - headerSize % 4;
      headerSize += paddingSize;

      nio.ByteBuffer out = nio.ByteBuffer.allocate(headerSize + 14);

      encodeInt(out, 10 + headerSize + frame.remaining());
      encodeShort(out, HEADER_MAGIC >> 16);
      encodeShort(out, _flags);
      encodeInt(out, _seqId);
      encodeShort(out, (headerSize / 4).round());

      out.putSrc(headerData);
      out.putSrc(transformData);
      out.putSrc(infoData1);
      out.putSrc(infoData2);

      for (int i = 0; i < paddingSize; i++) {
        out.put(b: 0x00);
      }

      out.position = 0;

      transport_.write(out.array(), out.position, out.remaining());
      transport_.write(frame.array(), frame.position, frame.remaining());
    } else if (clientType == ClientTypes.FRAMED_DEPRECATED) {
      nio.ByteBuffer out = nio.ByteBuffer.allocate(4);
      encodeInt(out, frame.remaining());
      out.position = 0;
      transport_.write(out.array(), out.position, out.remaining());
      transport_.write(frame.array(), frame.position, frame.remaining());
    } else if (clientType == ClientTypes.HTTP) {
      throw TTransportError(null, "HTTP is not supported for THeaderTransport");
    } else {
      throw TTransportError(null, "Unknown client type");
    }

    if (oneway) {
      await transport_.onewayFlush();
    } else {
      await transport_.flush();
    }
  }

  // final Int8List i32buf = Int8List(4);
  void encodeInt(nio.ByteBuffer out, final int val) {
    TFramedTransport.encodeWord(val, i32buf);
    out.putByte(i32buf, 0, 4);
  }

  Int8List i16buf = Int8List(2);
  void encodeShort(nio.ByteBuffer out, final int val) {
    TFramedTransport.encodeShort(val, i16buf);
    out.putByte(i16buf, 0, 2);
  }

  int readVarint32Buf(nio.ByteBuffer frame) {
    int result = 0;
    int shift = 0;

    while (true) {
      int b = frame.get();
      result |= (b & 0x7f) << shift;
      if ((b & 0x80) != 0x80) {
        break;
      }
      shift += 7;
    }

    return result;
  }

  void readHeaderFormat(int headerSize, Int8List buff) {
    nio.ByteBuffer frame = nio.ByteBuffer.wrap(buff);

    frame.position = 10; // Advance past version, flags, seqid

    headerSize = headerSize * 4;
    int endHeader = headerSize + frame.position;

    if (headerSize > frame.remaining()) {
      throw TTransportError(null, "Header size is larger than frame");
    }

    _protoId = readVarint32Buf(frame);
    int numTransforms = readVarint32Buf(frame);

    // Clear out any previous transforms
    _readTransforms = <int>[];

    if (_protoId == T_JSON_PROTOCOL && clientType != ClientTypes.HTTP) {
      throw TTransportError(null, "Trying to recv JSON encoding over binary");
    }

    // Read in the headers.  Data for each varies. See
    // doc/HeaderFormat.txt
    int hmacSz = 0;
    for (int i = 0; i < numTransforms; i++) {
      int transId = readVarint32Buf(frame);
      if (transId == Transforms.ZLIB_TRANSFORM.value) {
        _readTransforms.add(transId);
      } else if (transId == Transforms.SNAPPY_TRANSFORM.value) {
        throw TTransportError(null, "Snappy transform no longer supported");
      } else if (transId == Transforms.HMAC_TRANSFORM.value) {
        throw TTransportError(null, "Hmac transform no longer supported");
      } else {
        throw TTransportError(null, "Unknown transform during recv");
      }
    }

    // Read the info section.
    _readHeaders.clear();
    while (frame.position < endHeader) {
      int infoId = readVarint32Buf(frame);
      if (infoId == Infos.INFO_KEYVALUE.value) {
        int numKeys = readVarint32Buf(frame);
        for (int i = 0; i < numKeys; i++) {
          String key = readString(frame);
          String value = readString(frame);
          _readHeaders[key] = value;
        }
      } else if (infoId == Infos.INFO_PKEYVALUE.value) {
        int numKeys = readVarint32Buf(frame);
        for (int i = 0; i < numKeys; i++) {
          String key = readString(frame);
          String value = readString(frame);
          readPersistentHeaders[key] = value;
        }
      } else {
        // Unknown info ID, continue on to reading data.
        break;
      }
    }

    _readHeaders.addAll(readPersistentHeaders);

    // Read in the data section.
    frame.position = endHeader;
    frame.limit = frame.limit - hmacSz; // limit to data without mac

    frame = untransform(frame);
    readBuffer_?.reset(
        buf: frame.array(), offset: frame.position, length: frame.remaining());
  }

  nio.ByteBuffer untransform(nio.ByteBuffer data) {
    if (_readTransforms.contains(Transforms.ZLIB_TRANSFORM.value)) {
      // TODO ZIPdecompressor
    }
    return data;
  }

  writeString(nio.ByteBuffer out, String str) {
    Int8List buf = Int8List.fromList(utf8.encode(str));
    writeVarint(out, buf.length);
    out.putByte(buf);
  }

  String readString(nio.ByteBuffer frame) {
    int len = readVarint32Buf(frame);
    Int8List buf = Int8List(len);
    frame.get(dst: buf, offset: 0, length: len);
    return utf8.decode(buf);
  }

  void resetProtocol() {
    clientType = ClientTypes.HEADERS;
    readFrame();
  }

  writeVarint(nio.ByteBuffer out, int value) {
    while (true) {
      if ((value & ~0x7F) == 0) {
        out.put(b: value.toSigned(8));
        return;
      } else {
        out.put(b: ((value.toSigned(8)) | 0x80));
        value >>= 7;
      }
    }
  }

  // void writeVarint32Buf(nio.ByteBuffer frame, int value) {
  //   while (true) {
  //     if ((value & ~0x7F) == 0) {
  //       frame.put(b: value);
  //       return;
  //     } else {
  //       frame.put(b: ((value & 0x7F) | 0x80));
  //       value >>= 7;
  //     }
  //   }
  // }
}

class ClientTypes {
  final int value;
  const ClientTypes._(this.value);
  static const HEADERS = ClientTypes._(0);
  static const FRAMED_DEPRECATED = ClientTypes._(1);
  static const HTTP = ClientTypes._(3);
  static const UNKNOWN = ClientTypes._(4);
}

class Infos {
  final int value;
  const Infos._(this.value);
  static const INFO_KEYVALUE = Infos._(0x01);
  static const INFO_PKEYVALUE = Infos._(0x02);
}

class Transforms {
  final int value;
  const Transforms._(this.value);
  static const ZLIB_TRANSFORM = Transforms._(0x01);
  static const HMAC_TRANSFORM = Transforms._(0x02);
  static const SNAPPY_TRANSFORM = Transforms._(0x03);
}
