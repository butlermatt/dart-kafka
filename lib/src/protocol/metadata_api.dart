part of kafka.protocol;

/// Kafka MetadataRequest.
class MetadataRequest extends KafkaRequest {
  /// API key of [MetadataRequest]
  final int apiKey = 3;

  /// API version of [MetadataRequest]
  final int apiVersion = 0;

  /// List of topic names to fetch metadata for. If set to null or empty
  /// this request will fetch metadata for all topics.
  final List<String> topicNames;

  /// Creats new instance of Kafka MetadataRequest.
  ///
  /// If [topicNames] is omitted or empty then metadata for all existing topics
  /// will be returned.
  MetadataRequest([this.topicNames]) : super();

  @override
  List<int> toBytes() {
    var builder = new KafkaBytesBuilder.withRequestHeader(
        apiKey, apiVersion, correlationId);
    List list = (this.topicNames is List) ? this.topicNames : [];
    builder.addArray(list, KafkaType.string);

    var body = builder.takeBytes();
    builder.addBytes(body);

    return builder.takeBytes();
  }

  @override
  createResponse(List<int> data) {
    return new MetadataResponse.fromBytes(data);
  }
}

/// Kafka MetadataResponse.
class MetadataResponse {
  /// List of brokers in the cluster.
  final List<Broker> brokers;

  /// List with metadata for each topic.
  final List<TopicMetadata> topics;

  MetadataResponse._(this.brokers, this.topics);

  /// Creates response from binary data.
  factory MetadataResponse.fromBytes(List<int> data) {
    var reader = new KafkaBytesReader.fromBytes(data);
    var size = reader.readInt32();
    assert(size == data.length - 4);

    reader.readInt32(); // correlationId

    var brokers = reader.readArray(KafkaType.object, (reader) {
      return new Broker(
          reader.readInt32(), reader.readString(), reader.readInt32());
    });

    var topicMetadata = reader.readArray(
        KafkaType.object, (reader) => new TopicMetadata._readFrom(reader));
    return new MetadataResponse._(brokers, topicMetadata);
  }

  /// Returns [Broker] by specified [nodeId].
  Broker getBroker(int nodeId) {
    return brokers.firstWhere((b) => b.id == nodeId);
  }

  TopicMetadata getTopicMetadata(String topicName) {
    return topics.firstWhere((topic) => topic.topicName == topicName,
        orElse: () =>
            throw new StateError('No topic ${topicName} found in metadata.'));
  }
}

/// Represents Kafka TopicMetadata data structure returned in MetadataResponse.
class TopicMetadata {
  final int errorCode;
  final String topicName;
  final List<PartitionMetadata> partitions;

  TopicMetadata._(this.errorCode, this.topicName, this.partitions);

  factory TopicMetadata._readFrom(KafkaBytesReader reader) {
    var errorCode = reader.readInt16();
    var topicName = reader.readString();
    var partitions = reader.readArray(
        KafkaType.object, (reader) => new PartitionMetadata._readFrom(reader));
    return new TopicMetadata._(errorCode, topicName, partitions);
  }

  PartitionMetadata getPartition(int partitionId) =>
      partitions.firstWhere((p) => p.partitionId == partitionId);

  @override
  String toString() =>
      "TopicMetadata(errorCode: ${errorCode}, name: ${topicName}, partitions: ${partitions.length})";
}

/// Data structure representing partition metadata returned in MetadataResponse.
class PartitionMetadata {
  final int partitionErrorCode;
  final int partitionId;
  final int leader;
  final List<int> replicas;
  final List<int> inSyncReplicas;

  PartitionMetadata._(this.partitionErrorCode, this.partitionId, this.leader,
      this.replicas, this.inSyncReplicas);

  factory PartitionMetadata._readFrom(KafkaBytesReader reader) {
    var errorCode = reader.readInt16();
    var partitionId = reader.readInt32();
    var leader = reader.readInt32();
    var replicas = reader.readArray(KafkaType.int32);
    var inSyncReplicas = reader.readArray(KafkaType.int32);
    return new PartitionMetadata._(
        errorCode, partitionId, leader, replicas, inSyncReplicas);
  }
}
