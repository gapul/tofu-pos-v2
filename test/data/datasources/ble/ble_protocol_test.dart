import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tofu_pos/core/transport/transport_event.dart';
import 'package:tofu_pos/data/datasources/ble/ble_protocol.dart';
import 'package:tofu_pos/domain/value_objects/ticket_number.dart';

void main() {
  TransportEvent makeOrder({String items = '[]'}) => OrderSubmittedEvent(
    shopId: 'shop_a',
    eventId: 'e1',
    occurredAt: DateTime.utc(2026, 5, 7, 12),
    orderId: 1,
    ticketNumber: const TicketNumber(7),
    itemsJson: items,
  );

  TransportEvent makeProductMaster(int approxBytes) {
    // 文字列を膨らませて指定バイト数あたりのペイロードにする
    final String payload = '"${'x' * approxBytes}"';
    return ProductMasterUpdateEvent(
      shopId: 'shop_a',
      eventId: 'e2',
      occurredAt: DateTime.utc(2026, 5, 7, 12),
      productsJson: '[$payload]',
    );
  }

  group('BleProtocol.encode', () {
    test('small message fits in one frame', () {
      final List<Uint8List> frames = BleProtocol.encode(makeOrder(), seq: 0);
      expect(frames, hasLength(1));
      expect(frames.first[0], 0); // seq
      expect(frames.first[1], 1); // total
      expect(frames.first[2], 0); // index
      expect(
        frames.first.length,
        lessThanOrEqualTo(BleProtocol.defaultChunkSize),
      );
    });

    test('large message splits into multiple frames', () {
      final List<Uint8List> frames = BleProtocol.encode(
        makeProductMaster(1000),
        seq: 5,
        chunkSize: 100,
      );
      expect(frames.length, greaterThan(1));
      for (int i = 0; i < frames.length; i++) {
        expect(frames[i][0], 5);
        expect(frames[i][1], frames.length);
        expect(frames[i][2], i);
        expect(frames[i].length, lessThanOrEqualTo(100));
      }
    });

    test('rejects out-of-range seq', () {
      expect(
        () => BleProtocol.encode(makeOrder(), seq: 256),
        throwsArgumentError,
      );
      expect(
        () => BleProtocol.encode(makeOrder(), seq: -1),
        throwsArgumentError,
      );
    });

    test('rejects too-small chunk size', () {
      expect(
        () => BleProtocol.encode(makeOrder(), seq: 0, chunkSize: 3),
        throwsArgumentError,
      );
    });
  });

  group('BleFrameAssembler', () {
    test('reassembles single frame', () {
      final BleFrameAssembler ass = BleFrameAssembler();
      final List<Uint8List> frames = BleProtocol.encode(
        makeOrder(items: '[{"name":"a"}]'),
        seq: 1,
      );
      final TransportEvent? r = ass.feed(frames.single);
      expect(r, isA<OrderSubmittedEvent>());
      expect((r! as OrderSubmittedEvent).itemsJson, '[{"name":"a"}]');
    });

    test('reassembles multi-frame in order', () {
      final BleFrameAssembler ass = BleFrameAssembler();
      final TransportEvent original = makeProductMaster(1000);
      final List<Uint8List> frames = BleProtocol.encode(
        original,
        seq: 7,
        chunkSize: 80,
      );
      TransportEvent? result;
      for (final Uint8List f in frames) {
        result = ass.feed(f);
      }
      expect(result, isA<ProductMasterUpdateEvent>());
      final ProductMasterUpdateEvent r = result! as ProductMasterUpdateEvent;
      expect(
        r.productsJson,
        (original as ProductMasterUpdateEvent).productsJson,
      );
    });

    test('reassembles multi-frame out of order', () {
      final BleFrameAssembler ass = BleFrameAssembler();
      final List<Uint8List> frames = BleProtocol.encode(
        makeProductMaster(500),
        seq: 9,
        chunkSize: 80,
      );
      // 逆順で投入
      TransportEvent? result;
      for (final Uint8List f in frames.reversed) {
        result = ass.feed(f);
      }
      expect(result, isA<ProductMasterUpdateEvent>());
    });

    test('multiple seq can be in flight independently', () {
      final BleFrameAssembler ass = BleFrameAssembler();
      final List<Uint8List> a = BleProtocol.encode(
        makeOrder(items: '[{"a":1}]'),
        seq: 1,
        chunkSize: 60,
      );
      final List<Uint8List> b = BleProtocol.encode(
        makeOrder(items: '[{"b":2}]'),
        seq: 2,
        chunkSize: 60,
      );
      // a の途中で b を挟む
      ass.feed(a.first);
      b.forEach(ass.feed);
      expect(ass.pendingSeqCount, 1); // a がまだ未完成
      // a を最後まで
      for (int i = 1; i < a.length; i++) {
        ass.feed(a[i]);
      }
      expect(ass.pendingSeqCount, 0);
    });

    test('returns null on too-short frame', () {
      final BleFrameAssembler ass = BleFrameAssembler();
      expect(ass.feed(Uint8List.fromList(<int>[1, 2])), isNull);
    });

    test('reset clears in-flight buckets', () {
      final BleFrameAssembler ass = BleFrameAssembler();
      final List<Uint8List> frames = BleProtocol.encode(
        makeProductMaster(500),
        seq: 1,
        chunkSize: 80,
      );
      ass.feed(frames.first);
      expect(ass.pendingSeqCount, 1);
      ass.reset();
      expect(ass.pendingSeqCount, 0);
    });
  });
}
