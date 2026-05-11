import 'package:flutter_test/flutter_test.dart';
import 'package:tofu_pos/core/startup/startup_pipeline.dart';

void main() {
  group('StartupPipeline', () {
    test('全ステップを宣言順に実行する', () async {
      final List<String> order = <String>[];
      final StartupPipeline p = StartupPipeline(<StartupStep>[
        StartupStep(name: 'a', run: () async => order.add('a')),
        StartupStep(name: 'b', run: () async => order.add('b')),
        StartupStep(name: 'c', run: () async => order.add('c')),
      ]);

      await p.run();

      expect(order, <String>['a', 'b', 'c']);
    });

    test('非 fatal の失敗は飲み込み、後続ステップは実行される', () async {
      final List<String> order = <String>[];
      final StartupPipeline p = StartupPipeline(<StartupStep>[
        StartupStep(name: 'a', run: () async => order.add('a')),
        StartupStep(
          name: 'boom',
          run: () async => throw StateError('fail'),
        ),
        StartupStep(name: 'c', run: () async => order.add('c')),
      ]);

      await p.run();

      expect(order, <String>['a', 'c']);
    });

    test('fatal=true の失敗は再送出される', () async {
      final StartupPipeline p = StartupPipeline(<StartupStep>[
        StartupStep(
          name: 'die',
          run: () async => throw StateError('fatal'),
          fatal: true,
        ),
      ]);

      await expectLater(p.run(), throwsStateError);
    });

    test('fatal=true のステップで停止し、後続は実行されない', () async {
      final List<String> order = <String>[];
      final StartupPipeline p = StartupPipeline(<StartupStep>[
        StartupStep(name: 'a', run: () async => order.add('a')),
        StartupStep(
          name: 'die',
          run: () async => throw StateError('fatal'),
          fatal: true,
        ),
        StartupStep(name: 'c', run: () async => order.add('c')),
      ]);

      await expectLater(p.run(), throwsStateError);
      expect(order, <String>['a']);
    });
  });
}
