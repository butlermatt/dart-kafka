part of kafka;

/// Initial contact point with a Kafka cluster.
class ContactPoint {
  final String host;
  final int port;

  ContactPoint(this.host, this.port);
}

/// Session responsible for communication with Kafka cluster.
///
/// In order to create new Session you need to pass a list of [ContactPoint]s to
/// the constructor. Each ContactPoint is defined by a host and a port of one
/// of the Kafka brokers. At least one ContactPoint is required to connect to
/// the cluster, all the rest members of the cluster will be automatically
/// detected by the Session.
///
/// For production deployments it is recommended to provide more than one
/// ContactPoint since this will enable "failover" in case one of the instances
/// is temporarily unavailable.
class KafkaSession {
  /// List of Kafka brokers which are used as initial contact points.
  final Queue<ContactPoint> contactPoints;

  Map<String, Socket> _sockets = new Map();
  Map<String, StreamSubscription> _subscriptions = new Map();
  Map<String, List<int>> _buffers = new Map();
  Map<String, int> _sizes = new Map();
  Map<KafkaRequest, Completer> _inflightRequests = new Map();

  MetadataResponse _metadata;

  /// Creates new session.
  ///
  /// [contactPoints] will be used to fetch Kafka metadata information. At least
  /// one is required. However for production consider having more than 1.
  /// In case of one of the hosts is temporarily unavailable the session will
  /// rotate them until sucessful response is returned. Error will be thrown
  /// when all of the default hosts are unavailable.
  KafkaSession(List<ContactPoint> contactPoints)
      : contactPoints = new Queue.from(contactPoints);

  /// Fetches Kafka server metadata. If [topicNames] is null then metadata for
  /// all topics will be returned.
  ///
  /// This is a wrapper around Kafka API [MetadataRequest].
  /// Result will also contain information about all brokers in the Kafka cluster.
  /// See [MetadataResponse] for details.
  Future<MetadataResponse> getMetadata(
      {List<String> topicNames, bool invalidateCache: false}) async {
    if (invalidateCache) _metadata = null;

    if (_metadata == null) {
      // TODO: actually rotate default hosts on failure.
      var contactPoint = _getCurrentContactPoint();
      var request = new MetadataRequest(topicNames);
      _metadata = await _send(contactPoint.host, contactPoint.port, request);
    }

    return _metadata;
  }

  /// Fetches metadata for specified [consumerGroup].
  ///
  /// It handles `ConsumerCoordinatorNotAvailableCode(15)` API error which Kafka
  /// returns in case [ConsumerMetadataRequest] is sent for the very first time
  /// to this particular broker (when special topic to store consumer offsets
  /// does not exist yet).
  ///
  /// It will attempt up to 5 retries (with linear delay) in order to fetch
  /// metadata.
  Future<ConsumerMetadataResponse> getConsumerMetadata(
      String consumerGroup) async {
    // TODO: rotate default hosts.
    var contactPoint = _getCurrentContactPoint();
    var request = new ConsumerMetadataRequest(consumerGroup);

    ConsumerMetadataResponse response =
        await _send(contactPoint.host, contactPoint.port, request);
    var retries = 1;
    var error = new KafkaServerError(response.errorCode);
    while (error.isConsumerCoordinatorNotAvailable && retries < 5) {
      var future = new Future.delayed(new Duration(seconds: retries),
          () => _send(contactPoint.host, contactPoint.port, request));

      response = await future;
      error = new KafkaServerError(response.errorCode);
      retries++;
    }

    if (error.isError) throw error;

    return response;
  }

  /// Sends request to specified [Broker].
  Future<dynamic> send(Broker broker, KafkaRequest request) {
    return _send(broker.host, broker.port, request);
  }

  Future<dynamic> _send(String host, int port, KafkaRequest request) async {
    var socket = await _getSocket(host, port);
    Completer completer = new Completer();
    _inflightRequests[request] = completer;
    // TODO: add timeout for how long to wait for response.
    // TODO: add error handling.
    socket.add(request.toBytes());

    return completer.future;
  }

  /// Closes this session and terminates all open socket connections.
  ///
  /// After session has been closed it can't be used or re-opened.
  Future close() async {
    for (var h in _sockets.keys) {
      await _subscriptions[h].cancel();
      _sockets[h].destroy();
    }
  }

  void _handleData(String hostPort, List<int> d) {
    var buffer = _buffers[hostPort];

    buffer.addAll(d);
    if (buffer.length >= 4 && _sizes[hostPort] == -1) {
      var sizeBytes = buffer.sublist(0, 4);
      var reader = new KafkaBytesReader.fromBytes(sizeBytes);
      _sizes[hostPort] = reader.readInt32();
    }

    var extra;
    if (buffer.length > _sizes[hostPort] + 4) {
      extra = buffer.sublist(_sizes[hostPort] + 4);
      buffer.removeRange(_sizes[hostPort] + 4, buffer.length);
    }

    if (buffer.length == _sizes[hostPort] + 4) {
      var header = buffer.sublist(4, 8);
      var reader = new KafkaBytesReader.fromBytes(header);
      var correlationId = reader.readInt32();
      var request = _inflightRequests.keys
          .firstWhere((r) => r.correlationId == correlationId);
      var completer = _inflightRequests[request];
      completer.complete(request.createResponse(buffer));
      _inflightRequests.remove(request);
      buffer.clear();
      _sizes[hostPort] = -1;
      if (extra is List && extra.isNotEmpty) {
        _handleData(hostPort, extra);
      }
    }
  }

  ContactPoint _getCurrentContactPoint() {
    return contactPoints.first;
  }

  // void _rotateDefaultHosts() {
  //   var current = defaultHosts.removeFirst();
  //   defaultHosts.addLast(current);
  // }

  Future<Socket> _getSocket(String host, int port) async {
    var key = '${host}:${port}';
    if (!_sockets.containsKey(key)) {
      var s = await Socket.connect(host, port);
      _buffers[key] = new List();
      _sizes[key] = -1;
      _subscriptions[key] = s.listen((d) => _handleData(key, d));
      _sockets[key] = s;
      _sockets[key].setOption(SocketOption.TCP_NODELAY, true);
    }

    return _sockets[key];
  }
}
