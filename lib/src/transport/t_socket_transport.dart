// Copyright (c) 2023- All souce code authors. All rights reserved.
//
// This source code is licensed under Apache 2.0 License.

part of fbthrift;

/// Socket implementation of the [TTransport] interface.
class TSocketTransport extends TIOStreamTransport implements TSocketItf {
  Socket? _socket;
  final String? _host;
  final int _port;
  // ignore: unused_field
  final int _timeout;
  final int _connectionTimeout;

  Stream<List<int?>>? _bstl;

  TSocketTransport(
      {Socket? socket,
      String? host,
      int? port = 0,
      int timeout = 0,
      int connectionTimeout = 6000})
      : _socket = socket,
        _host = host ?? socket?.remoteAddress.address,
        _port = port ?? socket?.port ?? 0,
        _timeout = timeout,
        _connectionTimeout = connectionTimeout {
    _initSocket();
  }

  @override
  Socket? getSocket() => _socket;

  @override
  bool get isOpen => _socket != null;

  /// open socket and init stream
  @override
  Future open() async {
    if (_socket != null) {
      throw TTransportError(
          TTransportErrorType.ALREADY_OPEN, "Socket already open");
    }

    if (_host == null) {
      throw TTransportError(
          TTransportErrorType.NOT_OPEN, "Cannot open null host");
    }

    if (_port <= 0) {
      throw TTransportError(
          TTransportErrorType.NOT_OPEN, "Cannot open without port");
    }

    _socket = await Socket.connect(_host!, _port,
        timeout: Duration(milliseconds: _connectionTimeout));
    _initSocket();
  }

  /// set socket options and init stream
  void _initSocket() {
    _socket?.setOption(SocketOption.tcpNoDelay, true);
    outputBuffer = List<Int8List>.empty(growable: true);
    _bstl = _socket?.asBroadcastStream();
  }

  /// close socket and stream, and clear buffers
  @override
  Future close() async {
    await _socket?.close();
    _socket = null;
    _bstl = null;
  }

  /// write buffer to socket
  @override
  Future flush([bool oneway = false]) async {
    await _socket?.addStream(
        Stream.fromIterable(outputBuffer!.map<List<int>>((e) => e)));
    if (oneway) return;
    var inputBufferInt = [...(await _bstl?.first ?? [])];
    var total = [];
    total.addAll(inputBufferInt);
    if (inFrame) {
      var totalLenBytes = inputBufferInt
          .sublist(0, 4)
          .map<int>((e) => e?.toSigned(8) ?? 0)
          .toList();
      var len = TFramedTransport.decodeWord(Int8List.fromList(totalLenBytes));
      while (total.length < len + 4) {
        inputBufferInt = [...(await _bstl?.first ?? [])];
        total.addAll(inputBufferInt);
      }
    }
    inputBuffer = total.map<int?>((e) => e?.toSigned(8)).toList();
    outputBuffer?.clear();
  }
}
