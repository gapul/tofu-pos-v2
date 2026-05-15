import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:lottie/lottie.dart';

/// Lordicon (CC BY 4.0) の Lottie JSON を再生するラッパー widget。
///
/// 使い方:
/// ```dart
/// Lordicon(name: 'trash', size: 20, color: Colors.white,
///          trigger: LordiconTrigger.tap)
/// ```
///
/// - `name`: `assets/lordicons/<name>.json` を再生する。
/// - `size`: 一辺の dp。Lottie の `BoxFit.contain` で内部に収める。
/// - `color`: 与えると `ColorFiltered` で tint する (System Regular の
///   モノクロアイコン前提)。null なら原色のまま。
/// - `trigger`: 再生トリガー。`loop` / `inView` / `tap` / `hover` / `once`。
///
/// JSON が存在しない場合は [fallbackIcon] (デフォルト
/// [Icons.image_outlined]) を Material Icon としてフォールバック表示する。
/// これにより、開発初期段階で JSON 未配置でもアプリはクラッシュしない。
///
/// アイコンの取得手順は `assets/lordicons/README.md` を参照。
@immutable
class Lordicon extends StatefulWidget {
  const Lordicon({
    required this.name,
    super.key,
    this.size = 24,
    this.color,
    this.trigger = LordiconTrigger.inView,
    this.fallbackIcon = Icons.image_outlined,
    this.semanticLabel,
  });

  final String name;
  final double size;
  final Color? color;
  final LordiconTrigger trigger;
  final IconData fallbackIcon;
  final String? semanticLabel;

  /// 指定された name のアセットが利用可能か。テストや tap トリガで
  /// 事前判定に使える (内部キャッシュあり)。
  static Future<bool> exists(String name) => _LordiconAssetCache.has(name);

  @override
  State<Lordicon> createState() => _LordiconState();
}

/// `Lordicon` の再生トリガー。
enum LordiconTrigger {
  /// 画面表示時に一度だけ再生。
  inView,

  /// 1 回だけ再生 (mount 時)。
  once,

  /// 無限ループ再生。
  loop,

  /// `onTap` 相当の外部発火 (このウィジェット自体には GestureDetector を
  /// 仕込まない。再生は親側で `Lordicon` を rebuild させて行う)。
  /// シンプル実装として、tap 時の親側からは `key` を変えて作り直す。
  tap,

  /// hover/focus 相当。`MouseRegion.onEnter` で再生開始、`onExit` で停止。
  /// マウス操作環境（Web/desktop）では実際にホバーで動く。タッチ環境では
  /// 静止状態 (= 初期フレーム) のまま。
  hover,
}

class _LordiconState extends State<Lordicon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Future<bool>? _availability;

  @override
  void initState() {
    super.initState();
    // initState で確実に生成 (`late final = ...` だと
    // 一度も build を経ずに widget が unmount された場合、
    // dispose 中に SingleTickerProviderStateMixin が
    // 既に deactivated な element 上で ticker を生成しようとして
    // assertion に引っかかる)。
    _controller = AnimationController(vsync: this);
    _availability = _LordiconAssetCache.has(widget.name);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _availability,
      builder: (context, snap) {
        final bool ready = snap.data ?? false;
        if (!ready) {
          // 未ロード or 未配置: Material Icon にフォールバック。
          // データロード未完 (snap.data == null) でも視覚的破綻を避けるため
          // 静的アイコンで埋める (size/color を継承)。
          return Icon(
            widget.fallbackIcon,
            size: widget.size,
            color: widget.color,
            semanticLabel: widget.semanticLabel,
          );
        }
        final Widget animation = Lottie.asset(
          'assets/lordicons/${widget.name}.json',
          width: widget.size,
          height: widget.size,
          fit: BoxFit.contain,
          controller: _controller,
          onLoaded: (composition) {
            _controller.duration = composition.duration;
            switch (widget.trigger) {
              case LordiconTrigger.loop:
                // repeat() は TickerFuture (never-completes) を返す。
                // ループを開始させて戻り値は明示的に破棄する。
                unawaited(_controller.repeat().orCancel.catchError((_) {}));
              case LordiconTrigger.once:
              case LordiconTrigger.inView:
              case LordiconTrigger.tap:
                unawaited(_controller.forward(from: 0));
              case LordiconTrigger.hover:
                // hover は MouseRegion で発火する。初期は再生せず静止。
                _controller.value = 0;
            }
          },
          // Web では `useCompression: false` などのワークアラウンドが
          // 必要になることがあるため、最低限の defensive 設定を入れる。
          options: kIsWeb ? LottieOptions(enableMergePaths: true) : null,
        );

        final Widget tinted = widget.color != null
            ? ColorFiltered(
                colorFilter: ColorFilter.mode(
                  widget.color!,
                  BlendMode.srcIn,
                ),
                child: animation,
              )
            : animation;

        // hover trigger: MouseRegion で onEnter/onExit を捕捉。
        final Widget interactive = widget.trigger == LordiconTrigger.hover
            ? MouseRegion(
                onEnter: (_) => unawaited(
                  _controller.forward(from: 0).orCancel.catchError((_) {}),
                ),
                onExit: (_) => _controller.reset(),
                child: tinted,
              )
            : tinted;

        if (widget.semanticLabel != null) {
          return Semantics(
            label: widget.semanticLabel,
            image: true,
            child: interactive,
          );
        }
        return interactive;
      },
    );
  }
}

/// `assets/lordicons/<name>.json` の存在チェックを非同期キャッシュ。
///
/// 起動時に毎フレーム rootBundle へ問い合わせると無駄なので、
/// 名前ごとに 1 回だけ評価して結果を保持する。
class _LordiconAssetCache {
  _LordiconAssetCache._();

  static final Map<String, Future<bool>> _cache = <String, Future<bool>>{};

  static Future<bool> has(String name) {
    return _cache.putIfAbsent(name, () async {
      try {
        await rootBundle.load('assets/lordicons/$name.json');
        return true;
      } on Exception {
        // Flutter は asset 未配置時に内部的に FlutterError を throw するが、
        // `avoid_catching_errors` を避けるため Exception/`catch (_)` 経由で
        // 受ける。実害は無い (true でも false でも widget はフォールバック)。
        return false;
      } catch (_) {
        // `Error` を含むあらゆる例外も「未配置」として処理。
        return false;
      }
    });
  }
}
