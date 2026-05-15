import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'tofu_input.dart';

/// Figma `Molecules/Inputs/FormField` (id `35:4`) を Flutter で再現。
///
/// 構成: ラベル + 入力 (任意 child or TofuInput) + helper/error テキスト。
/// `errorText` が非 null の場合は赤系の helper を表示し、内部の
/// [TofuInput] には error 配色を伝搬させる (build 時に [child] を渡した
/// 場合は呼び出し側が `errorText` を別途渡すこと)。
@immutable
class TofuFormField extends StatelessWidget {
  const TofuFormField({
    required this.label,
    super.key,
    this.child,
    this.controller,
    this.hintText,
    this.helperText,
    this.errorText,
    this.required = false,
    this.enabled = true,
    this.inputSize = TofuInputSize.md,
    this.keyboardType,
    this.onChanged,
    this.suffixIcon,
    this.prefixIcon,
    this.obscureText = false,
  });

  /// 上段ラベル。
  final String label;

  /// 任意の入力ウィジェットを差し込む場合に指定。
  /// 未指定なら [TofuInput] を内部生成する。
  final Widget? child;

  /// 内部 TofuInput 用 controller。`child` 指定時は無視。
  final TextEditingController? controller;
  final String? hintText;

  /// 補助テキスト。`errorText` があれば表示しない。
  final String? helperText;

  /// エラーメッセージ。非 null/非空でエラー状態。
  final String? errorText;

  /// `*` 印付きの必須ラベル。
  final bool required;

  final bool enabled;
  final TofuInputSize inputSize;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;

  @override
  Widget build(BuildContext context) {
    final bool hasError = errorText != null && errorText!.isNotEmpty;

    final Widget input =
        child ??
        TofuInput(
          controller: controller,
          size: inputSize,
          hintText: hintText,
          enabled: enabled,
          errorText: hasError ? errorText : null,
          keyboardType: keyboardType,
          onChanged: onChanged,
          prefixIcon: prefixIcon,
          suffixIcon: suffixIcon,
          obscureText: obscureText,
        );

    final String? bottom = hasError ? errorText : helperText;
    final Color bottomColor = hasError
        ? TofuTokens.dangerText
        : TofuTokens.textTertiary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _Label(label: label, required: required, enabled: enabled),
        const SizedBox(height: TofuTokens.space3),
        // child を指定された場合は外側 FormField がエラー表示を担う。
        if (child != null && hasError) input else input,
        if (bottom != null && bottom.isNotEmpty && child != null) ...<Widget>[
          const SizedBox(height: TofuTokens.space2),
          Text(
            bottom,
            style: TofuTextStyles.caption.copyWith(color: bottomColor),
          ),
        ] else if (bottom != null &&
            bottom.isNotEmpty &&
            !hasError) ...<Widget>[
          const SizedBox(height: TofuTokens.space2),
          Text(
            bottom,
            style: TofuTextStyles.caption.copyWith(color: bottomColor),
          ),
        ],
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label({
    required this.label,
    required this.required,
    required this.enabled,
  });

  final String label;
  final bool required;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final Color color = enabled
        ? TofuTokens.textSecondary
        : TofuTokens.textDisabled;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          label,
          style: TofuTextStyles.bodySmBold.copyWith(color: color),
        ),
        if (required) ...<Widget>[
          const SizedBox(width: TofuTokens.space1),
          Text(
            '*',
            style: TofuTextStyles.bodySmBold.copyWith(
              color: TofuTokens.dangerText,
            ),
          ),
        ],
      ],
    );
  }
}
