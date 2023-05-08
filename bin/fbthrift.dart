// Copyright (c) 2023- All souce code authors. All rights reserved.
//
// This source code is licensed under Apache 2.0 License.

import 'dart:io';

import 'package:fbthrift/fbthrift.dart';

Future<void> main(List<String> arguments) async {
  TTransport transport =
      TSocketTransport(socket: await Socket.connect('127.0.0.1', 9670));

  var headTransport = THeaderTransport(
    transport: transport,
    clientTypes: [ClientTypes.HEADERS],
    supportedClients: [false],
  );
  var protocol = THeaderProtocol(headTransport);
  print(protocol);
}
