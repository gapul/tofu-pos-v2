import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// 画面上部に滑り込むトースト。ScaffoldMessenger 経由の SnackBar の代替。
///
/// 業務的な狙い:
///   - お会計や注文操作の直後、画面下部はオペレータの指が乗っている。
///     下から出る SnackBar は指で隠れて読めない。
///   - 上部の AppHeader 直下に表示することで、視線移動も最小で済む。
///
/// 実装メモ:
///   - 各 `show` は専用の OverlayEntry + State を持ち、Timer もそのインスタンス
///     内に閉じている（旧実装の static Timer race を回避）。
///   - 同時表示は 1 件まで。新しい show は古いものに dismiss 要求を出して
///     即座に置き換える。
class TopSnack {
  TopSnack._();

  /// 現在ライブな entry の dismissal トリガ。show のたびに更新される。
  static _DismissHandle? _current;

  /// 上部にトーストを表示する。`context` から Overlay を解決する。
  ///
  /// [color] は背景色。デフォルトは `bgInverse`（暗色 + 白文字）。
  /// [duration] は表示時間。**2 秒を超える指定は強制的に 2 秒に丸める**
  /// （業務要件: 学園祭オペレーションで「SnackBar が消えない」誤認を避ける）。
  static void show(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 2),
    Color? color,
    Color? foreground,
    IconData? icon,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final OverlayState? overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) {
      return;
    }
    // 業務要件: 全 TopSnack を 2 秒以内に自動消去する。呼び出し側で
    // うっかり長い duration を渡しても安全側に丸める。
    const Duration cap = Duration(seconds: 2);
    final Duration effective = duration > cap ? cap : duration;

    // 前回表示中があれば即時 dismiss 要求を出す。
    _current?.dismiss();
    _current = null;

    final _DismissHandle handle = _DismissHandle();
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => _TopSnackContent(
        handle: handle,
        message: message,
        background: color ?? TofuTokens.bgInverse,
        foreground: foreground ?? TofuTokens.brandOnPrimary,
        icon: icon,
        actionLabel: actionLabel,
        onAction: onAction,
        duration: effective,
        onRemoved: () {
          if (entry.mounted) {
            entry.remove();
          }
          if (identical(_current, handle)) {
            _current = null;
          }
        },
      ),
    );
    overlay.insert(entry);
    _current = handle;
  }

  /// 表示中があれば消す。テストや画面遷移直前のクリーンアップに使う。
  static void dismiss() {
    _current?.dismiss();
    _current = null;
  }
}

/// State 側で受け取って dispose を待つトリガ。外から `dismiss()` 即時消去要求。
class _DismissHandle {
  void Function()? _onDismiss;
  void attach(void Function() onDismiss) {
    _onDismiss = onDismiss;
  }

  void detach() {
    _onDismiss = null;
  }

  void dismiss() {
    _onDismiss?.call();
  }
}

class _TopSnackContent extends StatefulWidget {
  const _TopSnackContent({
    required this.handle,
    required this.message,
    required this.background,
    required this.foreground,
    required this.duration,
    required this.onRemoved,
    this.icon,
    this.actionLabel,
    this.onAction,
  });

  final _DismissHandle handle;
  final String message;
  final Color background;
  final Color foreground;
  final Duration duration;
  final VoidCallback onRemoved;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  State<_TopSnackContent> createState() => _TopSnackContentState();
}

class _TopSnackContentState extends State<_TopSnackContent>
    with SingleTickerProviderStateMixin {
  static const Duration _enter = Duration(milliseconds: 220);
  static const Duration _exit = Duration(milliseconds: 180);

  late final AnimationController _ac = AnimationController(
    vsync: this,
    duration: _enter,
    reverseDuration: _exit,
  );
  Timer? _autoDismiss;
  bool _exiting = false;

  @override
  void initState() {
    super.initState();
    widget.handle.attach(_beginExit);
    _ac.forward();
    _autoDismiss = Timer(widget.duration + _enter, _beginExit);
  }

  void _beginExit() {
    if (_exiting || !mounted) return;
    _exiting = true;
    _autoDismiss?.cancel();
    _autoDismiss = null;
    _ac.reverse().whenComplete(() {
      widget.handle.detach();
      widget.onRemoved();
    });
  }

  @override
  void dispose() {
    _autoDismiss?.cancel();
    widget.handle.detach();
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final MediaQueryData mq = MediaQuery.of(context);
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragEnd: (d) {
          if ((d.primaryVelocity ?? 0) < -200) {
            _beginExit();
          }
        },
        onTap: _beginExit,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -1),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: _ac, curve: Curves.easeOut)),
          child: FadeTransition(
            opacity: _ac,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: EdgeInsets.only(
                  top: TofuTokens.space3,
                  left: TofuTokens.space4 + mq.padding.left,
                  right: TofuTokens.space4 + mq.padding.right,
                ),
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: TofuTokens.space5,
                      vertical: TofuTokens.space4,
                    ),
                    decoration: BoxDecoration(
                      color: widget.background,
                      borderRadius: BorderRadius.circular(TofuTokens.radiusLg),
                      boxShadow: const <BoxShadow>[
                        BoxShadow(
                          color: Color(0x33000000),
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        if (widget.icon != null) ...<Widget>[
                          Icon(widget.icon, color: widget.foreground, size: 20),
                          const SizedBox(width: TofuTokens.space3),
                        ],
                        Flexible(
                          child: Text(
                            widget.message,
                            style: TofuTextStyles.bodyMdBold.copyWith(
                              color: widget.foreground,
                            ),
                          ),
                        ),
                        if (widget.actionLabel != null &&
                            widget.onAction != null) ...<Widget>[
                          const SizedBox(width: TofuTokens.space4),
                          TextButton(
                            onPressed: () {
                              widget.onAction?.call();
                              _beginExit();
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: widget.foreground,
                              padding: const EdgeInsets.symmetric(
                                horizontal: TofuTokens.space3,
                              ),
                              minimumSize: const Size(0, 36),
                            ),
                            child: Text(
                              widget.actionLabel!,
                              style: TofuTextStyles.bodyMdBold.copyWith(
                                color: widget.foreground,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
