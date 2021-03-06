/// Subpackage with implementation of Kafka protocol.
///
/// Users of this library are not supposed to import this package directly and
/// use main 'kafka' package instead.
///
/// However if you really know what you're doing you can use it with:
///
/// ```dart
/// import 'package:kafka/protocol.dart';
/// ```
library kafka.protocol;

import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'common.dart';

part 'src/protocol/consumer_metadata_api.dart';
part 'src/protocol/fetch_api.dart';
part 'src/protocol/messages.dart';
part 'src/protocol/metadata_api.dart';
part 'src/protocol/offset_api.dart';
part 'src/protocol/offset_commit_api.dart';
part 'src/protocol/offset_fetch_api.dart';
part 'src/protocol/produce_api.dart';
part 'src/protocol/bytes_builder.dart';
part 'src/protocol/bytes_reader.dart';
part 'src/protocol/common.dart';
part 'src/util/crc32.dart';
