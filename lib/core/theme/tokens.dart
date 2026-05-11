import 'package:flutter/material.dart';

/// Figma の Foundations ページからエクスポートしたデザイントークン（仕様書 §12）。
///
/// SSOT は Figma だが、コードからはこのファイル経由で参照する。
/// ハードコード値（`#FF0000`, `16px` 等）の埋め込みは禁止。
class TofuTokens {
  const TofuTokens._();

  // =========================================================================
  // Primitive — Sumi (墨, 和の中性色ランプ)
  // =========================================================================
  static const Color sumi900 = Color(0xFF0E0D0C);
  static const Color sumi400 = Color(0xFF74716A);

  // =========================================================================
  // Primitive — Gray
  // =========================================================================
  static const Color gray50 = Color(0xFFFAFAFA);
  static const Color gray100 = Color(0xFFF5F5F5);
  static const Color gray200 = Color(0xFFE5E5E5);
  static const Color gray300 = Color(0xFFD4D4D4);
  static const Color gray400 = Color(0xFFA3A3A3);
  static const Color gray500 = Color(0xFF737373);
  static const Color gray600 = Color(0xFF525252);
  static const Color gray700 = Color(0xFF404040);
  static const Color gray800 = Color(0xFF262626);
  static const Color gray900 = Color(0xFF171717);

  // =========================================================================
  // Brand — 藍 (Ai) を既定テーマとして採用
  // =========================================================================
  static const Color brandPrimary = Color(0xFF173A5E);
  static const Color brandPrimaryHover = Color(0xFF102D49);
  static const Color brandPrimaryPressed = Color(0xFF0B2236);
  static const Color brandPrimarySubtleStrong = Color(0xFFD6E0EA);
  static const Color brandPrimarySubtle = Color(0xFFEDF2F6);
  static const Color brandPrimaryBorder = Color(0xFFA9C0D6);
  static const Color brandAccent = Color(0xFFB83B3B);
  static const Color brandOnPrimary = Color(0xFFFBF8F1);

  // =========================================================================
  // Semantic — Background
  // =========================================================================
  static const Color bgCanvas = Color(0xFFFBF8F1);
  static const Color bgSurface = Color(0xFFF5EFE2);
  static const Color bgSubtle = Color(0xFFEDE3CE);
  static const Color bgMuted = Color(0xFFDFD0AC);
  static const Color bgStrong = Color(0xFFC9B57C);
  static const Color bgInverse = Color(0xFF161513);

  // =========================================================================
  // Semantic — Border
  // =========================================================================
  static const Color borderSubtle = Color(0xFFDFD0AC);
  static const Color borderDefault = Color(0xFFC9B57C);
  static const Color borderStrong = Color(0xFF74716A);
  static const Color borderFocus = Color(0xFF173A5E);

  // =========================================================================
  // Semantic — Text
  // =========================================================================
  static const Color textPrimary = Color(0xFF161513);
  static const Color textSecondary = Color(0xFF2A2825);
  static const Color textTertiary = Color(0xFF74716A);
  static const Color textDisabled = Color(0xFFA8A498);
  static const Color textInverse = Color(0xFFFBF8F1);
  static const Color textLink = Color(0xFF102D49);

  // =========================================================================
  // Semantic — Status (danger / info / success / warning)
  // =========================================================================
  static const Color dangerBg = Color(0xFFFCEFEB);
  static const Color dangerBgStrong = Color(0xFF9A2E2E);
  static const Color dangerBorder = Color(0xFFE48971);
  static const Color dangerText = Color(0xFF7B2424);
  static const Color dangerIcon = Color(0xFF9A2E2E);

  static const Color infoBg = Color(0xFFEDF2F6);
  static const Color infoBgStrong = Color(0xFF173A5E);
  static const Color infoBorder = Color(0xFF7196B6);
  static const Color infoText = Color(0xFF102D49);
  static const Color infoIcon = Color(0xFF173A5E);

  static const Color successBg = Color(0xFFF1F5E8);
  static const Color successBgStrong = Color(0xFF445A26);
  static const Color successBorder = Color(0xFF90B557);
  static const Color successText = Color(0xFF34471D);
  static const Color successIcon = Color(0xFF445A26);

  static const Color warningBg = Color(0xFFFAF1E5);
  static const Color warningBgStrong = Color(0xFF9A5320);
  static const Color warningBorder = Color(0xFFD29553);
  static const Color warningText = Color(0xFF43240F);
  static const Color warningIcon = Color(0xFF7C411A);

  // =========================================================================
  // Semantic — 通信ステータス（仕様書 §7 / §8）
  // =========================================================================
  static const Color statusOnline = Color(0xFF557030);
  static const Color statusOffline = Color(0xFF9A5320);
  static const Color statusBluetooth = Color(0xFF1F4870);
  static const Color statusSyncing = Color(0xFF3E6B95);
  static const Color statusSyncError = Color(0xFF9A2E2E);

  // =========================================================================
  // Spacing スケール（数値は px）
  // =========================================================================
  static const double space0 = 0;
  static const double space2 = 4;
  static const double space3 = 8;
  static const double space4 = 12;
  static const double space5 = 16;
  static const double space6 = 20;
  static const double space7 = 24;
  static const double space8 = 32;
  static const double space11 = 64;
  static const double space12 = 80;
  static const double space14 = 128;

  // =========================================================================
  // Radius スケール
  // =========================================================================
  static const double radiusNone = 0;
  static const double radiusXs = 2;
  static const double radiusSm = 4;
  static const double radiusMd = 8;
  static const double radiusLg = 12;
  static const double radiusXl = 16;
  static const double radius2xl = 24;

  // =========================================================================
  // Stroke
  // =========================================================================
  static const double strokeHairline = 1;

  // =========================================================================
  // Elevation（DROP_SHADOW）
  // =========================================================================
  static const List<BoxShadow> elevationSm = <BoxShadow>[
    BoxShadow(color: Color(0x0D000000), offset: Offset(0, 1), blurRadius: 2),
  ];
  static const List<BoxShadow> elevationMd = <BoxShadow>[
    BoxShadow(
      color: Color(0x14000000),
      offset: Offset(0, 4),
      blurRadius: 8,
      spreadRadius: -2,
    ),
    BoxShadow(
      color: Color(0x0A000000),
      offset: Offset(0, 2),
      blurRadius: 4,
      spreadRadius: -1,
    ),
  ];
  static const List<BoxShadow> elevationLg = <BoxShadow>[
    BoxShadow(
      color: Color(0x1A000000),
      offset: Offset(0, 12),
      blurRadius: 24,
      spreadRadius: -6,
    ),
    BoxShadow(
      color: Color(0x0F000000),
      offset: Offset(0, 4),
      blurRadius: 8,
      spreadRadius: -2,
    ),
  ];
  static const List<BoxShadow> elevationXl = <BoxShadow>[
    BoxShadow(
      color: Color(0x29000000),
      offset: Offset(0, 24),
      blurRadius: 48,
      spreadRadius: -12,
    ),
    BoxShadow(
      color: Color(0x1A000000),
      offset: Offset(0, 8),
      blurRadius: 16,
      spreadRadius: -4,
    ),
  ];

  // =========================================================================
  // タッチターゲット（仕様書 §12.1）
  // =========================================================================
  /// 一般操作の最小タップ領域。
  static const double touchMin = 56;

  /// 主要操作（会計確定・提供完了等）の最小タップ領域。
  static const double touchPrimary = 72;

  /// 隣接ボタン間の最低スペース。
  static const double adjacentSpacing = 8;

  /// 確定系と破壊系の間の最低スペース（誤タップ防止）。
  static const double destructiveSpacing = 16;

  // =========================================================================
  // Safe Area（仕様書 §12.2）
  // =========================================================================
  static const double safeAreaInset = 16;

  // =========================================================================
  // モーション（仕様書 §12.1）
  // =========================================================================
  static const Duration motionShort = Duration(milliseconds: 200);
  static const Duration motionMedium = Duration(milliseconds: 250);
  static const Duration motionSheet = Duration(milliseconds: 280);

  // =========================================================================
  // フォント
  // =========================================================================
  /// IBM Plex Sans JP（Figma で指定）。実機で未インストールでも読み取れるよう
  /// fallback はシステムフォントに委ねる。
  static const String fontFamily = 'IBM Plex Sans JP';
}

/// タイポグラフィ（仕様書 §12 / Figma Foundations）。
class TofuTextStyles {
  const TofuTextStyles._();

  static const TextStyle displayL = TextStyle(
    fontFamily: TofuTokens.fontFamily,
    fontSize: 72,
    height: 80 / 72,
    letterSpacing: -2,
    fontWeight: FontWeight.w700,
    color: TofuTokens.textPrimary,
  );

  static const TextStyle displayM = TextStyle(
    fontFamily: TofuTokens.fontFamily,
    fontSize: 56,
    height: 64 / 56,
    letterSpacing: -2,
    fontWeight: FontWeight.w700,
    color: TofuTokens.textPrimary,
  );

  static const TextStyle displayS = TextStyle(
    fontFamily: TofuTokens.fontFamily,
    fontSize: 48,
    height: 56 / 48,
    letterSpacing: -1,
    fontWeight: FontWeight.w600,
    color: TofuTokens.textPrimary,
  );

  static const TextStyle h1 = TextStyle(
    fontFamily: TofuTokens.fontFamily,
    fontSize: 40,
    height: 48 / 40,
    letterSpacing: -1,
    fontWeight: FontWeight.w600,
    color: TofuTokens.textPrimary,
  );

  static const TextStyle h2 = TextStyle(
    fontFamily: TofuTokens.fontFamily,
    fontSize: 32,
    height: 40 / 32,
    letterSpacing: -0.5,
    fontWeight: FontWeight.w600,
    color: TofuTokens.textPrimary,
  );

  static const TextStyle h3 = TextStyle(
    fontFamily: TofuTokens.fontFamily,
    fontSize: 24,
    height: 32 / 24,
    fontWeight: FontWeight.w500,
    color: TofuTokens.textPrimary,
  );

  static const TextStyle h4 = TextStyle(
    fontFamily: TofuTokens.fontFamily,
    fontSize: 20,
    height: 28 / 20,
    fontWeight: FontWeight.w500,
    color: TofuTokens.textPrimary,
  );

  static const TextStyle bodyLg = TextStyle(
    fontFamily: TofuTokens.fontFamily,
    fontSize: 18,
    height: 28 / 18,
    fontWeight: FontWeight.w400,
    color: TofuTokens.textPrimary,
  );

  static const TextStyle bodyLgBold = TextStyle(
    fontFamily: TofuTokens.fontFamily,
    fontSize: 18,
    height: 28 / 18,
    fontWeight: FontWeight.w600,
    color: TofuTokens.textPrimary,
  );

  static const TextStyle bodyMd = TextStyle(
    fontFamily: TofuTokens.fontFamily,
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeight.w400,
    color: TofuTokens.textPrimary,
  );

  static const TextStyle bodyMdBold = TextStyle(
    fontFamily: TofuTokens.fontFamily,
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeight.w600,
    color: TofuTokens.textPrimary,
  );

  static const TextStyle bodySm = TextStyle(
    fontFamily: TofuTokens.fontFamily,
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w400,
    color: TofuTokens.textPrimary,
  );

  static const TextStyle bodySmBold = TextStyle(
    fontFamily: TofuTokens.fontFamily,
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w500,
    color: TofuTokens.textPrimary,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: TofuTokens.fontFamily,
    fontSize: 12,
    height: 16 / 12,
    letterSpacing: 0.5,
    fontWeight: FontWeight.w400,
    color: TofuTokens.textTertiary,
  );

  static const TextStyle captionBold = TextStyle(
    fontFamily: TofuTokens.fontFamily,
    fontSize: 12,
    height: 16 / 12,
    letterSpacing: 0.5,
    fontWeight: FontWeight.w500,
    color: TofuTokens.textTertiary,
  );

  /// 整理券番号など、視認性最優先の超大型数値。
  static const TextStyle numberDisplay = TextStyle(
    fontFamily: TofuTokens.fontFamily,
    fontSize: 72,
    height: 80 / 72,
    letterSpacing: -1,
    fontWeight: FontWeight.w700,
    color: TofuTokens.textPrimary,
  );

  static const TextStyle numberLg = TextStyle(
    fontFamily: TofuTokens.fontFamily,
    fontSize: 32,
    height: 40 / 32,
    fontWeight: FontWeight.w700,
    color: TofuTokens.textPrimary,
  );

  static const TextStyle numberMd = TextStyle(
    fontFamily: TofuTokens.fontFamily,
    fontSize: 24,
    height: 32 / 24,
    fontWeight: FontWeight.w500,
    color: TofuTokens.textPrimary,
  );
}
