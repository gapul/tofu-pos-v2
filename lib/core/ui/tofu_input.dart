import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/tokens.dart';

/// Figma `Atoms/Input` (ComponentSet `24:22`) を Flutter で再現。
///
/// size 軸:
/// - `md`: 48h / py12 px16 / radius 8 / font 16
/// - `lg`: 60h / py16 px20 / radius 12 / font 18
///
/// state 軸 (Flutter 側では Focus / TextEditingController で自動切替):
/// - `default` : 1px borderDefault
/// - `focused` : 2px borderFocus
/// - `filled`  : 値あり / 非フォーカス → default と同じ枠 (Figma 上同色)
/// - `disabled`: bgMuted 塗り / 1px borderSubtle
/// - `error`   : 2px dangerBorder (+ オプションで helper にエラー文)
///
/// 背景は常に bgSurface。文字は body-md / body-lg。
enum TofuInputSize { md, lg }

@immutable
class TofuInput extends StatelessWidget {
  const TofuInput({
    super.key,
    this.controller,
    this.size = TofuInputSize.md,
    this.hintText,
    this.errorText,
    this.enabled = true,
    this.obscureText = false,
    this.keyboardType,
    this.inputFormatters,
    this.onChanged,
    this.onSubmitted,
    this.focusNode,
    this.autofocus = false,
    this.textInputAction,
    this.maxLines = 1,
    this.minLines,
    this.prefixIcon,
    this.suffixIcon,
  });

  final TextEditingController? controller;
  final TofuInputSize size;
  final String? hintText;
  final String? errorText;
  final bool enabled;
  final bool obscureText;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final FocusNode? focusNode;
  final bool autofocus;
  final TextInputAction? textInputAction;
  final int? maxLines;
  final int? minLines;
  final Widget? prefixIcon;
  final Widget? suffixIcon;

  @override
  Widget build(BuildContext context) {
    final bool hasError = errorText != null && errorText!.isNotEmpty;

    final ({
      EdgeInsets padding,
      double radius,
      TextStyle textStyle,
      double minHeight,
    })
    m = switch (size) {
      TofuInputSize.md => (
        padding: const EdgeInsets.symmetric(
          horizontal: TofuTokens.space5,
          vertical: TofuTokens.space4,
        ),
        radius: TofuTokens.radiusMd,
        textStyle: TofuTextStyles.bodyMd,
        minHeight: 48,
      ),
      TofuInputSize.lg => (
        padding: const EdgeInsets.symmetric(
          horizontal: TofuTokens.space6,
          vertical: TofuTokens.space5,
        ),
        radius: TofuTokens.radiusLg,
        textStyle: TofuTextStyles.bodyLg,
        minHeight: 60,
      ),
    };

    OutlineInputBorder buildBorder(Color color, double width) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(m.radius),
          borderSide: BorderSide(color: color, width: width),
        );

    final InputDecoration decoration = InputDecoration(
      isDense: true,
      filled: true,
      fillColor: enabled ? TofuTokens.bgSurface : TofuTokens.bgMuted,
      hintText: hintText,
      hintStyle: m.textStyle.copyWith(color: TofuTokens.textTertiary),
      contentPadding: m.padding,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      errorText: hasError ? errorText : null,
      errorStyle: TofuTextStyles.captionBold.copyWith(
        color: TofuTokens.dangerText,
      ),
      enabledBorder: buildBorder(
        hasError ? TofuTokens.dangerBorder : TofuTokens.borderDefault,
        hasError ? TofuTokens.strokeThick : TofuTokens.strokeHairline,
      ),
      focusedBorder: buildBorder(
        hasError ? TofuTokens.dangerBorder : TofuTokens.borderFocus,
        TofuTokens.strokeThick,
      ),
      disabledBorder: buildBorder(
        TofuTokens.borderSubtle,
        TofuTokens.strokeHairline,
      ),
      errorBorder: buildBorder(TofuTokens.dangerBorder, TofuTokens.strokeThick),
      focusedErrorBorder: buildBorder(
        TofuTokens.dangerBorder,
        TofuTokens.strokeThick,
      ),
    );

    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: m.minHeight),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        autofocus: autofocus,
        enabled: enabled,
        obscureText: obscureText,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        textInputAction: textInputAction,
        maxLines: obscureText ? 1 : maxLines,
        minLines: minLines,
        style: m.textStyle.copyWith(
          color: enabled ? TofuTokens.textPrimary : TofuTokens.textDisabled,
        ),
        cursorColor: TofuTokens.borderFocus,
        decoration: decoration,
      ),
    );
  }
}
