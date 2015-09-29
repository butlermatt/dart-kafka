library kafka.test.api.fetch;

import 'dart:convert';
import 'package:test/test.dart';
import 'package:kafka/kafka.dart';

String _topicName = 'dartKafkaTest';
KafkaClient _client;
FetchRequest _request;
String _message;
int _offset;

void main() {
  setUp(() async {
    var host = new KafkaHost('127.0.0.1', 9092);
    _client = new KafkaClient('0.8.2', [host]);

    ProduceRequest produce = new ProduceRequest(_client, host, 1, 1000);
    var now = new DateTime.now();
    _message = 'test:' + now.toIso8601String();
    produce.addMessages(_topicName, 0, [_message]);
    var response = await produce.send();
    _offset = response.topics.first.partitions.first.offset;
    _request = new FetchRequest(_client, host, 100, 1);
  });

  test('it fetches message from Kafka topic', () async {
    _request.add(_topicName, 0, _offset);
    var response = await _request.send();

    expect(response.topics, hasLength(1));
    expect(response.topics[_topicName].first.messages, hasLength(1));
    var value =
        response.topics[_topicName].first.messages.messages[_offset].value;
    var text = UTF8.decode(value);
    expect(text, equals(_message));
  });
}