import 'package:flutter_test/flutter_test.dart';
import 'package:tofu_pos/core/logging/app_logger.dart';

void main() {
  group('AppLogger.formatEvent', () {
    test('component と action をブラケットで囲む', () {
      expect(
        AppLogger.formatEvent('sync', 'push_orders', const <String, Object?>{}),
        '[sync.push_orders]',
      );
    });

    test('プリミティブ field を key=value でつなぐ', () {
      expect(
        AppLogger.formatEvent('sync', 'run_once', const <String, Object?>{
          'success': 3,
          'failure': 0,
        }),
        '[sync.run_once] success=3 failure=0',
      );
    });

    test('null は省略する', () {
      expect(
        AppLogger.formatEvent('regi', 'checkout', const <String, Object?>{
          'order_id': 42,
          'optional': null,
          'kitchen': true,
        }),
        '[regi.checkout] order_id=42 kitchen=true',
      );
    });

    test('空白を含む値はクォートする', () {
      expect(
        AppLogger.formatEvent('lan', 'peer_connected', const <String, Object?>{
          'name': 'tofu pos kitchen',
        }),
        '[lan.peer_connected] name="tofu pos kitchen"',
      );
    });

    test('insertion order が保持される', () {
      // LinkedHashMap の挿入順を維持していることを確認。
      final Map<String, Object?> fields = <String, Object?>{};
      fields['z'] = 1;
      fields['a'] = 2;
      fields['m'] = 3;
      expect(
        AppLogger.formatEvent('x', 'y', fields),
        '[x.y] z=1 a=2 m=3',
      );
    });

    test('bool / num はそのまま、string は quote 不要なら裸', () {
      expect(
        AppLogger.formatEvent('ble', 'scan', const <String, Object?>{
          'shop': 'shop_a',
          'count': 5,
          'active': false,
        }),
        '[ble.scan] shop=shop_a count=5 active=false',
      );
    });
  });

  group('AppLogger.event', () {
    test('event は formatEvent と同じ文字列を返す', () {
      final String got = AppLogger.event(
        'kitchen',
        'ingest_submitted',
        fields: const <String, Object?>{'order_id': 1, 'ticket': 5},
      );
      expect(got, '[kitchen.ingest_submitted] order_id=1 ticket=5');
    });
  });
}
