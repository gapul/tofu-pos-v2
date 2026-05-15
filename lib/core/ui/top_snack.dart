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
///   - `OverlayEntry` を直近の `Overlay` (= MaterialApp の root)
///     に挿入する。Scaffold に依存しないので、appBar や bottomNavBar の
///     有無に関係なく同じ位置に出る。
///   - 同時表示は 1 件まで。新しい show は古いものを置き換える。
class TopSnack {
  TopSnack._();

  static OverlayEntry? _current;
  static Timer? _timer;

  /// 現在ライブな (entry, timer) を一意に識別する世代番号。
  ///
  /// 旧仕様では `_TopSnackContent.dispose()` がグローバル `_timer` を無条件に
  /// cancel していたため、以下の順序で「新しい SnackBar が永遠に消えない」
  /// バグが起きていた:
  ///
  ///   1. show() #1 が entry1 + timer1 を立てる
  ///   2. show() #2 が timer1 を cancel → entry1.remove() を呼ぶ
  ///   3. show() #2 が entry2 を insert → timer2 を立てる
  ///   4. 次フレームで entry1 の Widget が dispose → グローバル _timer
  ///      (= 既に timer2) を cancel してしまい、entry2 が自動消去されない
  ///
  /// `_generation` を per-show でインクリメントし、dispose 側は自分の世代と
  /// 現行世代が一致するときだけ cancel するようにして race を断つ。
  static int _generation = 0;
  static int get _currentGeneration => _generation;
  static const Duration _enterAnim = Duration(milliseconds: 220);

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

    _scheduleDismiss(immediate: true);
    _generation++;

    final Color bg = color ?? TofuTokens.bgInverse;
    final Color fg = foreground ?? TofuTokens.brandOnPrimary;
    final OverlayEntry entry = OverlayEntry(
      builder: (ctx) => _TopSnackContent(
        message: message,
        background: bg,
        foreground: fg,
        icon: icon,
        actionLabel: actionLabel,
        onAction: onAction == null
            ? null
            : () {
                _scheduleDismiss(immediate: true);
                onAction();
              },
      ),
    );
    overlay.insert(entry);
    _current = entry;
    _timer = Timer(effective + _enterAnim, _scheduleDismiss);
  }

  /// 表示中があれば消す。テストや画面遷移直前のクリーンアップに使う。
  static void dismiss() {
    _scheduleDismiss(immediate: true);
  }

  static void _scheduleDismiss({bool immediate = false}) {
    _timer?.cancel();
    _timer = null;
    final OverlayEntry? entry = _current;
    if (entry == null) return;
    _current = null;
    entry.remove();
  }
}

class _TopSnackContent extends StatefulWidget {
  const _TopSnackContent({
    required this.message,
    required this.background,
    required this.foreground,
    this.icon,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final Color background;
  final Color foreground;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  State<_TopSnackContent> createState() => _TopSnackContentState();
}

class _TopSnackContentState extends State<_TopSnackContent>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  )..forward();

  /// 自分が属する show() 呼び出しの世代。dispose 時に「現行世代が
  /// 自分と同じ」場合だけ Timer を片付ける（後発の show が立てた新しい
  /// Timer を巻き込んで cancel しないため）。
  late final int _generation = TopSnack._currentGeneration;

  @override
  void dispose() {
    // 自分の世代がまだ現行ならグローバル timer を解放。後発 show により
    // 既に世代が進んでいる場合は何もしない（新しい SnackBar の自動消去
    // タイマーを潰してしまわないため）。test の `timersPending` 対策は
    // 「現行世代を消す」「自分が現行のときだけ消す」のどちらでも満たせる。
    if (TopSnack._currentGeneration == _generation) {
      TopSnack._timer?.cancel();
      TopSnack._timer = null;
    }
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
      child: IgnorePointer(
        ignoring: false,
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
                            onPressed: widget.onAction,
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
