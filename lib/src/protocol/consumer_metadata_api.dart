part of kafka.protocol;

/// Kafka ConsumerMetadataRequest.
class ConsumerMetadataRequest extends KafkaRequest {
  final int apiKey = 10;
  final int apiVersion = 0;
  final String consumerGroup;

  /// Creates new instance of ConsumerMetadataRequest.
  ConsumerMetadataRequest(this.consumerGroup) : super();

  /// Converts this request into byte list
  @override
  List<int> toBytes() {
    var builder = new KafkaBytesBuilder.withRequestHeader(
        apiKey, apiVersion, correlationId);

    builder.addString(consumerGroup);

    var body = builder.takeBytes();
    builder.addBytes(body);

    return builder.takeBytes();
  }

  @override
  createResponse(List<int> data) {
    return new ConsumerMetadataResponse.fromBytes(data);
  }
}

/// Response for [ConsumerMetadataRequest].
class ConsumerMetadataResponse {
  final int errorCode;
  final int coordinatorId;
  final String coordinatorHost;
  final int coordinatorPort;

  Broker get coordinator =>
      new Broker(coordinatorId, coordinatorHost, coordinatorPort);

  /// Creates new instance of ConsumerMetadataResponse.
  ConsumerMetadataResponse(this.errorCode, this.coordinatorId,
      this.coordinatorHost, this.coordinatorPort);

  /// Creates response from provided data.
  factory ConsumerMetadataResponse.fromBytes(List<int> data) {
    var reader = new KafkaBytesReader.fromBytes(data);
    var size = reader.readInt32();
    assert(size == data.length - 4);

    reader.readInt32(); // correlationId
    var errorCode = reader.readInt16();
    var id = reader.readInt32();
    var host = reader.readString();
    var port = reader.readInt32();

    return new ConsumerMetadataResponse(errorCode, id, host, port);
  }
}
