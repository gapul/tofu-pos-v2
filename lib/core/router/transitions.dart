import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// PR-3: 画面遷移トランジションのヘルパー。
///
/// Material Motion (SharedAxis / FadeThrough) を `GoRoute.pageBuilder` で
/// 再利用するための薄いラッパ。ロジックは持たない。
///
/// - [sharedAxisPage]: 連続するフロー内の遷移（horizontal）。
///   /setup/* やレジフロー (customer → products → checkout → done) に使う。
/// - [fadeThroughPage]: サイドジャンプ的な遷移（settings / history / cash-close）。
class TofuTransitions {
  TofuTransitions._();

  /// SharedAxisTransition (horizontal) でラップした [CustomTransitionPage] を返す。
  static CustomTransitionPage<T> sharedAxisPage<T>({
    required LocalKey key,
    required Widget child,
  }) {
    return CustomTransitionPage<T>(
      key: key,
      child: child,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return SharedAxisTransition(
          animation: animation,
          secondaryAnimation: secondaryAnimation,
          transitionType: SharedAxisTransitionType.horizontal,
          fillColor: Colors.transparent,
          child: child,
        );
      },
    );
  }

  /// FadeThroughTransition でラップした [CustomTransitionPage] を返す。
  static CustomTransitionPage<T> fadeThroughPage<T>({
    required LocalKey key,
    required Widget child,
  }) {
    return CustomTransitionPage<T>(
      key: key,
      child: child,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeThroughTransition(
          animation: animation,
          secondaryAnimation: secondaryAnimation,
          fillColor: Colors.transparent,
          child: child,
        );
      },
    );
  }
}
