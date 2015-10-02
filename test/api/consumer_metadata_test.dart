library kafka.test.api.consumer_metadata;

import 'package:test/test.dart';
import 'package:semver/semver.dart';
import 'package:kafka/kafka.dart';

KafkaClient _client;
ConsumerMetadataRequest _request;

void main() {
  setUp(() {
    var host = new KafkaHost('127.0.0.1', 9092);
    var version = new SemanticVersion.fromString('0.8.2');
    _client = new KafkaClient(version, [host]);
    _request = new ConsumerMetadataRequest(_client, host, 'testGroup');
  });

  test('it fetches consumer metadata', () async {
    var response = await _request.send();
    expect(response.errorCode, equals(0));
    expect(response.coordinatorId, isNotNull);
    expect(response.coordinatorHost, isNotNull);
    expect(response.coordinatorPort, isNotNull);
  });
}