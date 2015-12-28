library kafka.test.consumer;

import 'package:test/test.dart';
import 'package:kafka/kafka.dart';
import 'setup.dart';

void main() {
  group('Consumer:', () {
    KafkaSession _session;
    String _topicName = 'dartKafkaTest';
    Map<int, int> _expectedOffsets = new Map();
    Map<int, int> _initialOffsets = new Map();

    setUp(() async {
      var host = await getDefaultHost();
      _session = new KafkaSession([new ContactPoint(host, 9092)]);
      var producer = new Producer(_session, 1, 100);
      var result = await producer.produce([
        new ProduceEnvelope(_topicName, 0, [new Message('msg1'.codeUnits)]),
        new ProduceEnvelope(_topicName, 1, [new Message('msg2'.codeUnits)]),
        new ProduceEnvelope(_topicName, 2, [new Message('msg3'.codeUnits)]),
      ]);
      if (result.hasErrors) {
        throw new StateError(
            'Consumer test: setUp failed to produce messages.');
      }
      _expectedOffsets = result.offsets[_topicName];

      var offsets = new List<ConsumerOffset>();
      for (var p in _expectedOffsets.keys) {
        _initialOffsets[p] = _expectedOffsets[p] - 1;
        offsets.add(new ConsumerOffset(_topicName, p, _initialOffsets[p], ''));
      }
      var group = new ConsumerGroup(_session, 'cg');
      await group.commitOffsets(offsets, 0, '');
    });

    tearDown(() async {
      await _session.close();
    });

    test('it can consume messages from multiple brokers and commit offsets',
        () async {
      var topics = {
        _topicName: [0, 1, 2]
      };
      var consumer = new Consumer(
          _session, new ConsumerGroup(_session, 'cg'), topics, 100, 1);
      var consumedOffsets = new Map();
      await for (MessageEnvelope envelope in consumer.consume(limit: 3)) {
        consumedOffsets[envelope.partitionId] = envelope.offset;
        expect(envelope.offset, _expectedOffsets[envelope.partitionId]);
        envelope.commit('');
      }
      expect(consumedOffsets.length, _expectedOffsets.length);
    });

    test(
        'it can consume messages from multiple brokers without commiting offsets',
        () async {
      var topics = {
        _topicName: [0, 1, 2]
      };
      var consumer = new Consumer(
          _session, new ConsumerGroup(_session, 'cg'), topics, 100, 1);
      var consumedOffsets = new Map();
      await for (MessageEnvelope envelope in consumer.consume(limit: 3)) {
        consumedOffsets[envelope.partitionId] = envelope.offset;
        expect(envelope.offset, _expectedOffsets[envelope.partitionId]);
        envelope.ack();
      }
      expect(consumedOffsets, _expectedOffsets);

      var group = new ConsumerGroup(_session, 'cg');
      var offsets = await group.fetchOffsets(topics);
      expect(offsets, hasLength(3));
      for (var o in offsets) {
        expect(_initialOffsets[o.partitionId], o.offset);
      }
    });

    test('it can handle cancelation request', () async {
      var topics = {
        _topicName: [0, 1, 2]
      };
      var consumer = new Consumer(
          _session, new ConsumerGroup(_session, 'cg'), topics, 100, 1);
      var consumedOffsets = new Map();
      await for (MessageEnvelope envelope in consumer.consume(limit: 3)) {
        consumedOffsets[envelope.partitionId] = envelope.offset;
        expect(envelope.offset, _expectedOffsets[envelope.partitionId]);
        envelope.cancel();
      }
      expect(consumedOffsets.length, equals(1));
    });

    test('it propagates worker errors via stream controller', () async {
      var topics = {
        'noSuchTopic': [0, 1, 2]
      };

      var consume = () async {
        try {
          var consumer = new Consumer(
              _session, new ConsumerGroup(_session, 'cg'), topics, 100, 1);
          var consumedOffsets = new Map();
          await for (MessageEnvelope envelope in consumer.consume(limit: 3)) {
            envelope.ack();
          }
          return false;
        } catch (e) {
          return true;
        }
      };

      var result = await consume();

      expect(result, isTrue);
    });
  });
}
