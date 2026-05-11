import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../error/app_exceptions.dart';
import '../telemetry/telemetry.dart';
import '../theme/tokens.dart';

/// 子ツリーの build エラーを captured して、フォールバック UI に置き換える。
///
/// 仕組み:
///   * 初回構築時に [ErrorWidget.builder] を1回だけ上書きし、
///     アプリ全体のデフォルトエラー画面を [_ErrorFallback] に差し替える。
///   * 子 subtree が `_ErrorFallback` に置換されるだけで親は生き残る
///     （Flutter は子の build 例外を `ErrorWidget.builder` に流す）。
///   * Telemetry は `main.dart` の `FlutterError.onError` がフレームワーク全体の
///     例外を `flutter.error` として既に送っている。本クラスは追加で
///     `ui.error_boundary` を送り、`label`（route 識別子）と
///     AppException の `kind` を attrs に付けて UI 層由来として分類できるようにする。
///     生エラー自体は `flutter.error` 側にも残るので、二重に見えるが目的が違う。
///
/// セットアップ画面など「失敗を握りつぶしたくない」画面では使わない。
class ErrorBoundary extends StatefulWidget {
  const ErrorBoundary({
    required this.child,
    super.key,
    this.label,
  });

  final Widget child;

  /// Telemetry に乗せる識別子（例: 'route:/regi/checkout'）。
  final String? label;

  /// テストで毎回 install をリセットするためのフック。
  @visibleForTesting
  static void debugReset() {
    _installed = false;
    _currentLabel = null;
  }

  static bool _installed = false;

  /// 現在マウント中の ErrorBoundary が宣言した label。
  /// `ErrorWidget.builder` は BuildContext を取らないため、
  /// アクティブな boundary の label を静的に共有する。
  /// ルートは同時に 1 つしか active にならない前提（兄弟ではない）。
  static String? _currentLabel;

  static void _ensureInstalled() {
    if (_installed) return;
    _installed = true;
    ErrorWidget.builder = (details) {
      final Object error = details.exception;
      Telemetry.instance.error(
        'ui.error_boundary',
        message: details.context?.toString() ?? 'unknown',
        error: error,
        stackTrace: details.stack,
        attrs: <String, Object?>{
          if (error is AppException) 'kind': error.kind,
          if (_currentLabel != null) 'label': _currentLabel,
        },
      );
      return _ErrorFallback(error: error);
    };
  }

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  int _retryToken = 0;

  @override
  void initState() {
    super.initState();
    ErrorBoundary._ensureInstalled();
    if (widget.label != null) {
      ErrorBoundary._currentLabel = widget.label;
    }
  }

  @override
  void dispose() {
    if (ErrorBoundary._currentLabel == widget.label) {
      ErrorBoundary._currentLabel = null;
    }
    super.dispose();
  }

  void _retry() {
    setState(() => _retryToken++);
  }

  @override
  Widget build(BuildContext context) {
    return _RetryScope(
      onRetry: _retry,
      child: KeyedSubtree(
        key: ValueKey<int>(_retryToken),
        child: widget.child,
      ),
    );
  }
}

/// Fallback から retry を発火するため、boundary のコールバックを子孫に流す。
class _RetryScope extends InheritedWidget {
  const _RetryScope({required this.onRetry, required super.child});
  final VoidCallback onRetry;

  static VoidCallback? maybeOf(BuildContext context) {
    final _RetryScope? scope =
        context.dependOnInheritedWidgetOfExactType<_RetryScope>();
    return scope?.onRetry;
  }

  @override
  bool updateShouldNotify(_RetryScope old) => false;
}

class _ErrorFallback extends StatelessWidget {
  const _ErrorFallback({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    final String code = error is AppException
        ? (error as AppException).kind
        : error.runtimeType.toString();
    final String detail = kReleaseMode ? '' : error.toString();
    final VoidCallback? retry = _RetryScope.maybeOf(context);
    return Material(
      color: TofuTokens.bgCanvas,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(TofuTokens.space7),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(Icons.error_outline,
                    size: 56, color: TofuTokens.dangerIcon),
                const SizedBox(height: TofuTokens.space5),
                const Text('エラーが発生しました', style: TofuTextStyles.h3),
                const SizedBox(height: TofuTokens.space3),
                Text(
                  code,
                  style: TofuTextStyles.captionBold,
                  textAlign: TextAlign.center,
                ),
                if (detail.isNotEmpty) ...<Widget>[
                  const SizedBox(height: TofuTokens.space3),
                  Text(
                    detail,
                    style: TofuTextStyles.caption,
                    textAlign: TextAlign.center,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: TofuTokens.space7),
                if (retry != null)
                  FilledButton(
                    onPressed: retry,
                    child: const Text('再試行'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
