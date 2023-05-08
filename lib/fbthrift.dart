// Copyright (c) 2023- All souce code authors. All rights reserved.
//
// This source code is licensed under Apache 2.0 License.

library fbthrift;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data' show ByteData, Endian, Int16List, Int8List;

import 'src/nio/byte_buffer.dart' as nio;
import 'src/io/index.dart';

import 'package:fixnum/fixnum.dart';

part 'src/t_error.dart';
part 'src/t_base.dart';
part 'src/short_stack.dart';
part 'src/t_application_error.dart';
part 'src/t_byte_array_output_stream.dart';
part 'src/t_processor.dart';

part 'src/protocol/t_protocol_error.dart';

part 'src/protocol/t_type.dart';
part 'src/protocol/t_struct.dart';
part 'src/protocol/t_field.dart';
part 'src/protocol/t_list.dart';
part 'src/protocol/t_map.dart';
part 'src/protocol/t_set.dart';
part 'src/protocol/t_message.dart';

part 'src/protocol/t_protocol_util.dart';

part 'src/protocol/t_protocol.dart';
part 'src/protocol/t_protocol_factory.dart';
part 'src/protocol/t_binary_protocol.dart';
part 'src/protocol/t_compact_protocol.dart';
part 'src/protocol/t_header_protocol.dart';

part 'src/transport/t_transport.dart';
part 'src/transport/t_transport_factory.dart';
part 'src/transport/t_memory_input_transport.dart';
part 'src/transport/t_framed_transport.dart';
part 'src/transport/t_header_transport.dart';
part 'src/transport/t_transport_error.dart';
part 'src/transport/t_io_stream_transport.dart';
part 'src/transport/t_socket_itf.dart';
part 'src/transport/t_socket_transport.dart';
