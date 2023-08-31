/// Licensed to the Apache Software Foundation (ASF) under one
/// or more contributor license agreements. See the NOTICE file
/// distributed with this work for additional information
/// regarding copyright ownership. The ASF licenses this file
/// to you under the Apache License, Version 2.0 (the
/// 'License'); you may not use this file except in compliance
/// with the License. You may obtain a copy of the License at
///
/// http://www.apache.org/licenses/LICENSE-2.0
///
/// Unless required by applicable law or agreed to in writing,
/// software distributed under the License is distributed on an
/// 'AS IS' BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
/// KIND, either express or implied. See the License for the
/// specific language governing permissions and limitations
/// under the License.

// ignore_for_file: constant_identifier_names, non_constant_identifier_names, unnecessary_this

part of fbthrift;

class TCompactProtocol extends TProtocol {
  static const int NO_LENGTH_LIMIT = -1;
  static final TStruct ANONYMOUS_STRUCT = TStruct('');
  static final TField TSTOP = TField('', TType.STOP, 0);

  static final Int8List ttypeToCompactType = Int8List(20);

  static const int PROTOCOL_ID = -126;
  static const int TYPE_SHIFT_AMOUNT = 5;
  static const int VERSION = 2;
  static const int VERSION_LOW = 1;
  static const int VERSION_DOUBLE_BE = 2;
  static const int VERSION_MASK = 0x1f;
  static const int TYPE_MASK = -32;
  static const int TYPE_BITS = 7;

  static fill() {
    ttypeToCompactType[TType.STOP] = TType.STOP;
    ttypeToCompactType[TType.BOOL] = Types.BOOLEAN_TRUE;
    ttypeToCompactType[TType.BYTE] = Types.BYTE;
    ttypeToCompactType[TType.I16] = Types.I16;
    ttypeToCompactType[TType.I32] = Types.I32;
    ttypeToCompactType[TType.I64] = Types.I64;
    ttypeToCompactType[TType.DOUBLE] = Types.DOUBLE;
    ttypeToCompactType[TType.STRING] = Types.BINARY;
    ttypeToCompactType[TType.LIST] = Types.LIST;
    ttypeToCompactType[TType.SET] = Types.SET;
    ttypeToCompactType[TType.MAP] = Types.MAP;
    ttypeToCompactType[TType.STRUCT] = Types.STRUCT;
    ttypeToCompactType[TType.FLOAT] = Types.FLOAT;
  }

  ShortStack lastField_ = ShortStack(15);

  int lastFieldId_ = 0;

  int version_ = TCompactProtocol.VERSION;

  TField? booleanField_;

  dynamic boolValue_;

  final int stringLengthLimit_;

  final int containerLengthLimit_;

  final Int8List buffer = Int8List(10);

  TCompactProtocol(
    TTransport transport, [
    int stringLengthLimit = NO_LENGTH_LIMIT,
    int containerLengthLimit = NO_LENGTH_LIMIT,
  ])  : this.stringLengthLimit_ = stringLengthLimit,
        this.containerLengthLimit_ = containerLengthLimit,
        super(transport) {
    TCompactProtocol.fill();
  }

  void reset() {
    lastField_.clear();
    lastFieldId_ = 0;
  }

  @override
  void writeMessageBegin(TMessage message) {
    writeByteDirect(TCompactProtocol.PROTOCOL_ID);
    writeByteDirect((VERSION & VERSION_MASK) |
        ((message.type << TYPE_SHIFT_AMOUNT) & TYPE_MASK));
    writeVarint32(message.seqid);
    writeString(message.name);
  }

  @override
  void writeStructBegin(TStruct struct) {
    lastField_.push(lastFieldId_);
    lastFieldId_ = 0;
  }

  @override
  void writeStructEnd() {
    lastFieldId_ = lastField_.pop();
  }

  @override
  void writeFieldBegin(TField field) {
    if (field.type == TType.BOOL) {
      // we want to possibly include the value, so we'll wait.
      booleanField_ = field;
    } else {
      writeFieldBeginInternal(field, -1.toSigned(8));
    }
  }

  void writeFieldBeginInternal(TField field, int typeOverride) {
    // if there's a type override, use that.
    int typeToWrite = typeOverride == -1.toSigned(8)
        ? getCompactType(field.type)
        : typeOverride;

    // check if we can delta encode the field id
    if (field.id > lastFieldId_ && field.id - lastFieldId_ <= 15) {
      // include the type delta with the field ID
      writeByteDirect((field.id - lastFieldId_) << 4 | typeToWrite);
    } else {
      // write separate type and ID values
      writeByteDirect(typeToWrite);
      writeI16(field.id);
    }
    lastFieldId_ = field.id;
  }

  @override
  void writeMapBegin(TMap map) {
    if (map.length == 0) {
      writeByteDirect(0);
    } else {
      writeVarint32(map.length);
      writeByteDirect(
        getCompactType(map.keyType) << 4 | getCompactType(map.valueType),
      );
    }
  }

  @override
  void writeListBegin(TList list) {
    writeCollectionBegin(list.elementType, list.length);
  }

  @override
  void writeBool(bool? b) {
    if (b == null) return;
    if (booleanField_ != null) {
      // we haven't written the field header yet
      writeFieldBeginInternal(
          booleanField_!, (b ? Types.BOOLEAN_TRUE : Types.BOOLEAN_FALSE));
      booleanField_ = null;
    } else {
      // we're not part of a field, so just write the value.
      writeByteDirect((b ? Types.BOOLEAN_TRUE : Types.BOOLEAN_FALSE));
    }
  }

  @override
  void writeByte(int b) {
    writeByteDirect(b);
  }

  @override
  void writeI16(int? i16) {
    i16 ??= 0;
    writeVarint32(intToZigZag(i16));
  }

  @override
  void writeI32(int? i32) {
    i32 ??= 0;
    writeVarint32(intToZigZag(i32));
  }

  @override
  void writeI64(int? i64) {
    i64 ??= 0;
    writeVarint64(longToZigzag(Int64(i64)));
  }

  final ByteData tempBD = ByteData(10);
  @override
  void writeDouble(double? d) {
    d ??= 0.0;
    tempBD.setFloat64(0, d, Endian.little);
    trans_.write(tempBD.buffer.asInt8List(), 0, 8);
  }

  @override
  void writeString(String? str) {
    Int8List bytes = Int8List.fromList(utf8.encode(str ?? ''));
    writeBinary(bytes, 0, bytes.length);
  }

  @override
  void writeBinary(List<int>? bytes, [int offset = 0, int? length]) {
    bytes ??= <int>[];
    length ??= bytes.length;
    writeVarint32(length);
    trans_.write(Int8List.fromList(bytes), offset, length);
  }

  @override
  void writeMessageEnd() {}

  @override
  void writeMapEnd() {}

  @override
  void writeListEnd() {}

  @override
  void writeSetEnd() {}

  @override
  void writeFieldEnd() {}

  void writeCollectionBegin(int elemType, int size) {
    if (size <= 14) {
      writeByteDirect(size << 4 | getCompactType(elemType));
    } else {
      writeByteDirect(0xf0 | getCompactType(elemType));
      writeVarint32(size);
    }
  }

  void writeVarint32(int n) {
    int idx = 0;
    while (true) {
      if ((n & ~0x7F) == 0) {
        buffer[idx++] = n.toSigned(8);
        break;
      } else {
        buffer[idx++] = (n & 0xFF | 0x80).toSigned(8);
        n >>= 7;
      }
    }
    trans_.write(buffer, 0, idx);
  }

  void writeVarint64(Int64 n) {
    int idx = 0;
    while (true) {
      if (removeTrailing7Bits(n) == 0) {
        buffer[idx++] = n.toInt().toSigned(8);
        break;
      } else {
        buffer[idx++] = (n.toInt() & 0xFF | 0x80).toSigned(8);
        n = n.shiftRightUnsigned(7);
      }
    }
    trans_.write(buffer, 0, idx);
  }

  int intToZigZag(int n) {
    return (n << 1) ^ (n >> 31);
  }

  Int64 longToZigzag(Int64 l) {
    return (l << 1) ^ (l >> 63);
  }

  void fixedLongToBytes(Int64 n, Int8List buf, int off) {
    buf[off + 0] = ((n.toInt() >> 56) & 0xff).toSigned(8);
    buf[off + 1] = ((n.toInt() >> 48) & 0xff).toSigned(8);
    buf[off + 2] = ((n.toInt() >> 40) & 0xff).toSigned(8);
    buf[off + 3] = ((n.toInt() >> 32) & 0xff).toSigned(8);
    buf[off + 4] = ((n.toInt() >> 24) & 0xff).toSigned(8);
    buf[off + 5] = ((n.toInt() >> 16) & 0xff).toSigned(8);
    buf[off + 6] = ((n.toInt() >> 8) & 0xff).toSigned(8);
    buf[off + 7] = ((n.toInt() >> 0) & 0xff).toSigned(8);
  }

  int removeTrailing7Bits(Int64 n) {
    var result = (n & (~(Int64.ONE << 7))).toInt();
    return result;
  }

  void writeByteDirect(int n) {
    n = n.toSigned(8);
    buffer[0] = n.toInt();
    trans_.write(buffer, 0, 1);
  }

  @override
  TMessage readMessageBegin() {
    int protocolId = readByte();
    if (protocolId != PROTOCOL_ID) {
      throw TProtocolError(TProtocolErrorType.INVALID_DATA,
          "Expected protocol id $PROTOCOL_ID but got $protocolId");
    }
    int versionAndType = readByte();
    version_ = (versionAndType & VERSION_MASK).toSigned(8);
    if (!(version_ <= VERSION && version_ >= VERSION_LOW)) {
      throw TProtocolError(TProtocolErrorType.INVALID_DATA,
          "Expected version $VERSION or lower but got $version_");
    }

    int type = (versionAndType >> TYPE_SHIFT_AMOUNT).toSigned(8);
    int seqid = readVarint32();
    String messageName = readString();
    return TMessage(messageName, type, seqid);
  }

  @override
  TStruct readStructBegin() {
    lastField_.push(lastFieldId_);
    lastFieldId_ = 0;
    return ANONYMOUS_STRUCT;
  }

  @override
  void readStructEnd() {
    lastFieldId_ = lastField_.pop();
  }

  @override
  TField readFieldBegin() {
    int type = readByte();
    if (type == TType.STOP) {
      return TSTOP;
    }

    int fieldId;
    int modifier = ((type & 0xF0) >> 4).toSigned(16);
    if (modifier == 0) {
      fieldId = readI16();
    } else {
      fieldId = (lastFieldId_ + modifier).toSigned(16);
    }

    TField field = TField("", getTType((type & 0x0F).toSigned(8)), fieldId);

    if (isBoolType(type)) {
      boolValue_ = (type & 0x0F).toSigned(8) == Types.BOOLEAN_TRUE;
    }

    lastFieldId_ = field.id;
    return field;
  }

  @override
  TMap readMapBegin() {
    int size = readVarint32();
    checkContainerReadLength(size);
    int keyAndValueType = (size == 0 ? 0 : readByte()).toSigned(8);
    int keyType = getTType((keyAndValueType >> 4).toSigned(8));
    int valueType = getTType((keyAndValueType & 0xf).toSigned(8));
    if (size > 0) {
      ensureMapHasEnough(size, keyType, valueType);
    }
    return TMap(keyType, valueType, size);
  }

  @override
  TList readListBegin() {
    int size_and_type = readByte().toSigned(8);
    int size = (size_and_type >> 4) & 0x0f;
    if (size == 15) {
      size = readVarint32();
    }
    checkContainerReadLength(size);
    int type = getTType(size_and_type);
    ensureContainerHasEnough(size, type);
    return TList(type, size);
  }

  @override
  TSet readSetBegin() {
    return TSet.fromList(readListBegin());
  }

  @override
  bool readBool() {
    if (boolValue_ != null) {
      bool result = boolValue_;
      boolValue_ = null;
      return result;
    }
    return readByte() == Types.BOOLEAN_TRUE;
  }

  @override
  int readByte() {
    int b;
    if (trans_.getBytesRemainingInBuffer() > 0) {
      b = trans_.getBuffer()?[trans_.getBufferPosition()] ?? 0;
      trans_.consumeBuffer(1);
    } else {
      trans_.readAll(buffer, 0, 1);
      b = buffer[0];
    }
    return b;
  }

  @override
  int readI16() {
    return zigzagToInt(readVarint32());
  }

  @override
  int readI32() {
    return zigzagToInt(readVarint32());
  }

  @override
  int readI64() {
    return zigzagToLong(readVarint64()).toInt();
  }

  final Int8List tempList = Int8List(10);
  @override
  double readDouble() {
    trans_.readAll(tempList, 0, 8);
    return tempList.buffer.asByteData().getFloat64(0, Endian.big);
  }

  @override
  String readString() {
    int length = readVarint32();
    checkContentReadLength(length);
    if (length == 0) {
      return "";
    }
    if (trans_.getBytesRemainingInBuffer() >= length) {
      final buffer = trans_.getBuffer();
      if (buffer == null) return '';
      final bufferPosition = trans_.getBufferPosition();
      final str =
          utf8.decode(Int8List.view(buffer.buffer, bufferPosition, length));
      trans_.consumeBuffer(length);
      return str;
    } else {
      return utf8.decode(readBinary(length));
    }
  }

  @override
  Int8List readBinary([dynamic length]) {
    length ??= readVarint32();
    checkContentReadLength(length);
    if (length == 0) {
      return Int8List(0);
    }
    ensureContainerHasEnough(length, TType.BYTE);
    Int8List buf = Int8List(length);
    trans_.readAll(buf, 0, length);
    return buf;
  }

  void checkContentReadLength(int length) {
    if (length < 0) {
      throw TProtocolError(
          TProtocolErrorType.NEGATIVE_SIZE, "Negative length $length");
    }
    if (stringLengthLimit_ > 0 && length > stringLengthLimit_) {
      throw TProtocolError(TProtocolErrorType.SIZE_LIMIT,
          "Length $length exceeds string length limit $stringLengthLimit_");
    }
  }

  void checkContainerReadLength(int length) {
    if (length < 0) {
      throw TProtocolError(
          TProtocolErrorType.NEGATIVE_SIZE, "Negative length $length");
    }
    if (containerLengthLimit_ > 0 && length > containerLengthLimit_) {
      throw TProtocolError(TProtocolErrorType.SIZE_LIMIT,
          "Length $length exceeds container length limit $containerLengthLimit_");
    }
  }

  @override
  void readMessageEnd() {}

  @override
  void readFieldEnd() {}

  @override
  void readMapEnd() {}

  @override
  void readListEnd() {}

  @override
  void readSetEnd() {}

  int readVarint32() {
    int result = 0;
    int shift = 0;
    if (trans_.getBytesRemainingInBuffer() >= 5) {
      Int8List? buf = trans_.getBuffer();
      if (buf == null) return 0;
      int pos = trans_.getBufferPosition();
      int off = 0;
      while (true) {
        int b = buf[pos + off].toSigned(8);
        result |= (b & 0x7f) << shift;
        if ((b & 0x80) != 0x80) {
          break;
        }
        shift += 7;
        off++;
      }
      trans_.consumeBuffer(off + 1);
    } else {
      while (true) {
        int b = readByte().toSigned(8);
        result |= (b & 0x7f) << shift;
        if ((b & 0x80) != 0x80) {
          break;
        }
        shift += 7;
      }
    }
    return result;
  }

  Int64 readVarint64() {
    int shift = 0;
    Int64 result = Int64.ZERO;
    if (trans_.getBytesRemainingInBuffer() >= 10) {
      Int8List buf = trans_.getBuffer() ?? Int8List(0);
      int pos = trans_.getBufferPosition();
      int off = 0;
      while (true) {
        int b = buf[pos + off].toSigned(8);
        result |= Int64(b & 0x7f) << shift;
        if ((b & 0x80) != 0x80) {
          break;
        }
        shift += 7;
        off++;
      }
      trans_.consumeBuffer(off + 1);
    } else {
      while (true) {
        int b = readByte().toSigned(8);
        result |= Int64(b & 0x7f) << shift;
        if ((b & 0x80) != 0x80) {
          break;
        }
        shift += 7;
      }
    }
    return result;
  }

  int zigzagToInt(int n) {
    return (n >> 1) ^ -(n & 1);
  }

  Int64 zigzagToLong(Int64 n) {
    return (n >> 1) ^ -(n & 1);
  }

  Int64 byteToLong(Int8List bytes) {
    return Int64(((bytes[0] & 0xFF) << 56) |
        ((bytes[1] & 0xFF) << 48) |
        ((bytes[2] & 0xFF) << 40) |
        ((bytes[3] & 0xFF) << 32) |
        ((bytes[4] & 0xFF) << 24) |
        ((bytes[5] & 0xFF) << 16) |
        ((bytes[6] & 0xFF) << 8) |
        ((bytes[7] & 0xFF)));
  }

  Int64 bytesToLongLE(Int8List bytes) {
    return Int64((bytes[7] & 0xFF) << 56) |
        Int64((bytes[6] & 0xFF) << 48) |
        Int64((bytes[5] & 0xFF) << 40) |
        Int64((bytes[4] & 0xFF) << 32) |
        Int64((bytes[3] & 0xFF) << 24) |
        Int64((bytes[2] & 0xFF) << 16) |
        Int64((bytes[1] & 0xFF) << 8) |
        Int64((bytes[0] & 0xFF));
  }

  int bytesToInt(Int8List bytes) {
    return ((bytes[0] & 0xFF) << 24) |
        ((bytes[1] & 0xFF) << 16) |
        ((bytes[2] & 0xFF) << 8) |
        ((bytes[3] & 0xFF));
  }

  bool isBoolType(int b) {
    int lowerNibble = b & 0x0f;
    return (lowerNibble == Types.BOOLEAN_TRUE ||
        lowerNibble == Types.BOOLEAN_FALSE);
  }

  int getTType(int type) {
    switch ((type & 0x0F).toSigned(8)) {
      case TType.STOP:
        return TType.STOP;
      case Types.BOOLEAN_FALSE:
      case Types.BOOLEAN_TRUE:
        return TType.BOOL;
      case Types.BYTE:
        return TType.BYTE;
      case Types.I16:
        return TType.I16;
      case Types.I32:
        return TType.I32;
      case Types.I64:
        return TType.I64;
      case Types.DOUBLE:
        return TType.DOUBLE;
      case Types.FLOAT:
        return TType.FLOAT;
      case Types.BINARY:
        return TType.STRING;
      case Types.LIST:
        return TType.LIST;
      case Types.SET:
        return TType.SET;
      case Types.MAP:
        return TType.MAP;
      case Types.STRUCT:
        return TType.STRUCT;
      default:
        throw TProtocolError(
            null, "don't know what type: ${(type & 0x0f).toSigned(8)}");
    }
  }

  int getCompactType(int ttype) {
    return ttypeToCompactType[ttype];
  }

  @override
  int typeMinimumSize(int type) {
    switch (type & 0x0F) {
      case TType.BOOL:
      case TType.BYTE:
      case TType.I16: // because of variable length encoding
      case TType.I32: // because of variable length encoding
      case TType.I64: // because of variable length encoding
      case TType.FLOAT: // because of variable length encoding
      case TType.DOUBLE: // because of variable length encoding
      case TType.STRING:
      case TType.STRUCT:
      case TType.MAP:
      case TType.SET:
      case TType.LIST:
      case TType.ENUM:
        return 1;
      default:
        throw TProtocolError(TProtocolErrorType.INVALID_DATA,
            "Unexpected data type ${(type & 0x0f).toSigned(8)}");
    }
  }

  @override
  void writeFieldStop() {
    writeByteDirect(TType.STOP);
  }

  @override
  void writeSetBegin(TSet set) {
    writeCollectionBegin(set.elementType, set.length);
  }
}

class TCompactProtocolFactory implements TProtocolFactory {
  final int stringLengthLimit_;
  final int containerLengthLimit_;

  TCompactProtocolFactory([
    int stringLengthLimit = TCompactProtocol.NO_LENGTH_LIMIT,
    int containerLengthLimit = TCompactProtocol.NO_LENGTH_LIMIT,
  ])  : this.stringLengthLimit_ = stringLengthLimit,
        this.containerLengthLimit_ = containerLengthLimit;

  @override
  TProtocol getProtocol(TTransport trans) {
    return TCompactProtocol(trans, stringLengthLimit_, containerLengthLimit_);
  }
}

class Types {
  static const int BOOLEAN_TRUE = 0x01;
  static const int BOOLEAN_FALSE = 0x02;
  static const int BYTE = 0x03;
  static const int I16 = 0x04;
  static const int I32 = 0x05;
  static const int I64 = 0x06;
  static const int DOUBLE = 0x07;
  static const int BINARY = 0x08;
  static const int LIST = 0x09;
  static const int SET = 0x0A;
  static const int MAP = 0x0B;
  static const int STRUCT = 0x0C;
  static const int FLOAT = 0x0D;
}
