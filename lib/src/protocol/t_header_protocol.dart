// Copyright (c) 2023- All souce code authors. All rights reserved.
//
// This source code is licensed under Apache 2.0 License.

// ignore_for_file: prefer_final_fields

part of fbthrift;

class Factory implements TProtocolFactory {
  List<ClientTypes> _clientTypes;
  Factory({List<ClientTypes>? clientTypes}) : _clientTypes = clientTypes ?? [];

  @override
  TProtocol getProtocol(TTransport transport) {
    if (transport is THeaderTransport) {
      return THeaderProtocol(transport);
    } else {
      return THeaderProtocol(transport, clientTypes: _clientTypes);
    }
  }
}

class THeaderProtocol extends TProtocol {
  TProtocol? _proto;
  int _protoId = 0;

  THeaderProtocol(
    TTransport transport, {
    List<ClientTypes>? clientTypes,
    int maxLength = TFramedTransport.DEFAULT_MAX_LENGTH,
  }) : super(clientTypes == null
            ? transport
            : THeaderTransport(
                transport: transport,
                clientTypes: clientTypes,
                maxLength: maxLength,
              )) {
    _resetProtocol();
  }

  _resetProtocol() {
    if (_proto != null && _protoId == (trans_ as THeaderTransport).protocolId) {
      return;
    }

    _protoId = (trans_ as THeaderTransport).protocolId;
    switch (_protoId) {
      case THeaderTransport.T_BINARY_PROTOCOL:
        _proto = TBinaryProtocol(trans_, strictRead: true, strictWrite: true);
        break;
      case THeaderTransport.T_COMPACT_PROTOCOL:
        _proto = TCompactProtocol(trans_);
        break;
      default:
        throw TProtocolError(null, "Unknown protocol id: $_protoId");
    }
  }

  @override
  Int8List readBinary() {
    return _proto?.readBinary() ?? Int8List(0);
  }

  @override
  bool readBool() {
    return _proto?.readBool() ?? false;
  }

  @override
  int readByte() {
    return _proto?.readByte() ?? 0;
  }

  @override
  double readDouble() {
    return _proto?.readDouble() ?? 0.0;
  }

  @override
  TField readFieldBegin() {
    return _proto?.readFieldBegin() ?? TField("", TType.STOP, 0);
  }

  @override
  void readFieldEnd() {
    _proto?.readFieldEnd();
  }

  @override
  int readI16() {
    return _proto?.readI16() ?? 0;
  }

  @override
  int readI32() {
    return _proto?.readI32() ?? 0;
  }

  @override
  int readI64() {
    return _proto?.readI64() ?? 0;
  }

  @override
  TList readListBegin() {
    return _proto?.readListBegin() ?? TList(TType.STOP, 0);
  }

  @override
  void readListEnd() {
    _proto?.readListEnd();
  }

  @override
  TMap readMapBegin() {
    return _proto?.readMapBegin() ?? TMap(TType.STOP, TType.STOP, 0);
  }

  @override
  void readMapEnd() {
    _proto?.readMapEnd();
  }

  @override
  TMessage readMessageBegin() {
    try {
      (trans_ as THeaderTransport).resetProtocol();
      _resetProtocol();
    } catch (e) {
      // throw TProtocolException("Failed to reset protocol: $e");
    }
    return _proto?.readMessageBegin() ?? TMessage("", TMessageType.CALL, 0);
  }

  @override
  void readMessageEnd() {
    _proto?.readMessageEnd();
  }

  @override
  TSet readSetBegin() {
    return _proto?.readSetBegin() ?? TSet(TType.STOP, 0);
  }

  @override
  void readSetEnd() {
    _proto?.readSetEnd();
  }

  @override
  String readString() {
    return _proto?.readString() ?? "";
  }

  @override
  TStruct readStructBegin() {
    return _proto?.readStructBegin() ?? TStruct("");
  }

  @override
  void readStructEnd() {
    _proto?.readStructEnd();
  }

  @override
  void writeBinary(Int8List? bytes) {
    _proto?.writeBinary(bytes);
  }

  @override
  void writeBool(bool? b) {
    _proto?.writeBool(b);
  }

  @override
  void writeByte(int b) {
    _proto?.writeByte(b);
  }

  @override
  void writeDouble(double? d) {
    _proto?.writeDouble(d);
  }

  @override
  void writeFieldBegin(TField field) {
    _proto?.writeFieldBegin(field);
  }

  @override
  void writeFieldEnd() {
    _proto?.writeFieldEnd();
  }

  @override
  void writeFieldStop() {
    _proto?.writeFieldStop();
  }

  @override
  void writeI16(int? i16) {
    _proto?.writeI16(i16);
  }

  @override
  void writeI32(int? i32) {
    _proto?.writeI32(i32);
  }

  @override
  void writeI64(int? i64) {
    _proto?.writeI64(i64);
  }

  @override
  void writeListBegin(TList list) {
    _proto?.writeListBegin(list);
  }

  @override
  void writeListEnd() {
    _proto?.writeListEnd();
  }

  @override
  void writeMapBegin(TMap map) {
    _proto?.writeMapBegin(map);
  }

  @override
  void writeMapEnd() {
    _proto?.writeMapEnd();
  }

  @override
  void writeMessageBegin(TMessage message) {
    _proto?.writeMessageBegin(message);
  }

  @override
  void writeMessageEnd() {
    _proto?.writeMessageEnd();
  }

  @override
  void writeSetBegin(TSet set) {
    _proto?.writeSetBegin(set);
  }

  @override
  void writeSetEnd() {
    _proto?.writeSetEnd();
  }

  @override
  void writeString(String? str) {
    _proto?.writeString(str);
  }

  @override
  void writeStructBegin(TStruct struct) {
    _proto?.writeStructBegin(struct);
  }

  @override
  void writeStructEnd() {
    _proto?.writeStructEnd();
  }
}
