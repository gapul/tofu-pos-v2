import 'dart:async';
import 'dart:math';

/// 指数バックオフ + ジッターによる再試行ポリシー。
///
/// ```dart
/// const RetryPolicy policy = RetryPolicy(
///   maxAttempts: 3,
///   initialDelay: Duration(milliseconds: 200),
///   maxDelay: Duration(seconds: 5),
/// );
/// final result = await policy.run(() => http.get(url));
/// ```
///
/// 並列実行・回路遮断（circuit breaker）は意図的にサポートしない。
/// 単独の冪等な呼び出しに対する再試行ラッパーに留める。
class RetryPolicy {
  const RetryPolicy({
    this.maxAttempts = 3,
    this.initialDelay = const Duration(milliseconds: 200),
    this.maxDelay = const Duration(seconds: 5),
    this.multiplier = 2.0,
    this.jitter = 0.2,
  })  : assert(maxAttempts >= 1, 'maxAttempts must be >= 1'),
        assert(multiplier >= 1.0, 'multiplier must be >= 1.0'),
        assert(jitter >= 0 && jitter <= 1.0, 'jitter must be in [0, 1]');

  /// 最大試行回数（初回 + 再試行）。1 なら再試行なし。
  final int maxAttempts;

  /// 1 回目の再試行までの待機時間。
  final Duration initialDelay;

  /// 待機時間の上限。
  final Duration maxDelay;

  /// 待機時間を試行ごとに何倍にするか（指数）。
  final double multiplier;

  /// 待機時間に乗せるジッター割合（[0, 1]）。
  /// 例: 0.2 なら ±20% の範囲でランダムに揺らぐ。
  final double jitter;

  /// [body] を最大 [maxAttempts] 回まで実行する。
  ///
  /// [retryOn] が `null` のときは全例外を再試行対象とする。
  /// [retryOn] が `false` を返した場合は即座に例外を再送出する。
  ///
  /// [sleep] と [random] はテスト用フック。
  Future<T> run<T>(
    Future<T> Function() body, {
    bool Function(Object error)? retryOn,
    Future<void> Function(Duration)? sleep,
    Random? random,
  }) async {
    final Random rng = random ?? Random();
    final Future<void> Function(Duration) sleeper =
        sleep ?? Future<void>.delayed;

    Object? lastError;
    StackTrace? lastStack;
    Duration delay = initialDelay;

    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        return await body();
      } catch (e, st) {
        lastError = e;
        lastStack = st;
        final bool shouldRetry = retryOn?.call(e) ?? true;
        if (!shouldRetry) {
          rethrow;
        }
        if (attempt == maxAttempts) {
          break;
        }
        await sleeper(_applyJitter(delay, rng));
        // 次回 delay を指数倍にして maxDelay でキャップ。
        final int nextMicros = (delay.inMicroseconds * multiplier).round();
        final Duration grown = Duration(microseconds: nextMicros);
        delay = grown > maxDelay ? maxDelay : grown;
      }
    }
    Error.throwWithStackTrace(lastError!, lastStack ?? StackTrace.current);
  }

  Duration _applyJitter(Duration base, Random rng) {
    if (jitter == 0) return base;
    // ±jitter の範囲で乗算。
    final double factor = 1 + (rng.nextDouble() * 2 - 1) * jitter;
    final int micros = (base.inMicroseconds * factor).round().clamp(0, 1 << 62);
    return Duration(microseconds: micros);
  }
}
