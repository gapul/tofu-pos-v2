import 'package:flutter/material.dart';

import 'num_stepper.dart';

/// 互換性のための旧 API。新規コードでは [TofuNumStepper] を使うこと。
///
/// Phase 3 (Molecules 再構築) で [TofuNumStepper] に置換されたが、既存呼び出し
/// (cash_close_screen / product_master_screen など) を一括 rename せず段階的に
/// 移行するため、当面の間 alias として残す。
@Deprecated('Use TofuNumStepper instead (lib/core/ui/num_stepper.dart).')
class NumericStepper extends StatelessWidget {
  @Deprecated('Use TofuNumStepper instead (lib/core/ui/num_stepper.dart).')
  const NumericStepper({
    required this.value,
    required this.onChanged,
    super.key,
    this.min = 0,
    this.max = 999999,
    this.step = 1,
    this.suffix,
    this.formatter,
    this.compact = false,
    this.label,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;
  final int step;
  final String? suffix;
  final String Function(int)? formatter;
  final bool compact;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return TofuNumStepper(
      value: value,
      onChanged: onChanged,
      min: min,
      max: max,
      step: step,
      suffix: suffix,
      formatter: formatter,
      label: label,
      size: compact ? TofuNumStepperSize.sm : TofuNumStepperSize.md,
    );
  }
}
