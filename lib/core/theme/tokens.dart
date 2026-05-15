import 'package:flutter/material.dart';

/// Figma Foundations (canvas id `0:1`) からエクスポートしたデザイントークン。
///
/// SSOT は Figma で、コード側からはこのファイル経由でのみ参照する。
/// ハードコードされた色値 (`#FF0000` 等) や生の数値 (`16px` 等) を
/// このファイル以外で使うのは禁止 (仕様書 §12)。
///
/// 命名は Figma の `category/name` を `categoryName` (camelCase) に
/// 1 対 1 で写像している。例: `semantic/bg/canvas` → `bgCanvas`。
class TofuTokens {
  const TofuTokens._();

  // ===========================================================================
  // Primitive — Sumi (墨, 和の中性色ランプ) — Figma `Theme 藍/Sample` 等で参照。
  // ===========================================================================
  static const Color sumi900 = Color(0xFF0E0D0C);
  static const Color sumi400 = Color(0xFF74716A);

  // ===========================================================================
  // Primitive — Tailwind 互換ランプ (Figma `Primitive Colors/{blue,gray,...}`)
  // ===========================================================================
  // Blue
  static const Color blue50 = Color(0xFFEFF6FF);
  static const Color blue100 = Color(0xFFDBEAFE);
  static const Color blue200 = Color(0xFFBFDBFE);
  static const Color blue300 = Color(0xFF93C5FD);
  static const Color blue400 = Color(0xFF60A5FA);
  static const Color blue500 = Color(0xFF3B82F6);
  static const Color blue600 = Color(0xFF2563EB);
  static const Color blue700 = Color(0xFF1D4ED8);
  static const Color blue800 = Color(0xFF1E40AF);
  static const Color blue900 = Color(0xFF1E3A8A);
  static const Color blue950 = Color(0xFF172554);

  // Gray (neutral)
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
  static const Color gray950 = Color(0xFF0A0A0A);

  // Green
  static const Color green50 = Color(0xFFF0FDF4);
  static const Color green100 = Color(0xFFDCFCE7);
  static const Color green200 = Color(0xFFBBF7D0);
  static const Color green300 = Color(0xFF86EFAC);
  static const Color green400 = Color(0xFF4ADE80);
  static const Color green500 = Color(0xFF22C55E);
  static const Color green600 = Color(0xFF16A34A);
  static const Color green700 = Color(0xFF15803D);
  static const Color green800 = Color(0xFF166534);
  static const Color green900 = Color(0xFF14532D);
  static const Color green950 = Color(0xFF052E16);

  // Orange
  static const Color orange50 = Color(0xFFFFF7ED);
  static const Color orange100 = Color(0xFFFFEDD5);
  static const Color orange200 = Color(0xFFFED7AA);
  static const Color orange300 = Color(0xFFFDBA74);
  static const Color orange400 = Color(0xFFFB923C);
  static const Color orange500 = Color(0xFFF97316);
  static const Color orange600 = Color(0xFFEA580C);
  static const Color orange700 = Color(0xFFC2410C);
  static const Color orange800 = Color(0xFF9A3412);
  static const Color orange900 = Color(0xFF7C2D12);
  static const Color orange950 = Color(0xFF431407);

  // Red
  static const Color red50 = Color(0xFFFEF2F2);
  static const Color red100 = Color(0xFFFEE2E2);
  static const Color red200 = Color(0xFFFECACA);
  static const Color red300 = Color(0xFFFCA5A5);
  static const Color red400 = Color(0xFFF87171);
  static const Color red500 = Color(0xFFEF4444);
  static const Color red600 = Color(0xFFDC2626);
  static const Color red700 = Color(0xFFB91C1C);
  static const Color red800 = Color(0xFF991B1B);
  static const Color red900 = Color(0xFF7F1D1D);
  static const Color red950 = Color(0xFF450A0A);

  // Yellow
  static const Color yellow50 = Color(0xFFFEFCE8);
  static const Color yellow100 = Color(0xFFFEF9C3);
  static const Color yellow200 = Color(0xFFFEF08A);
  static const Color yellow300 = Color(0xFFFDE047);
  static const Color yellow400 = Color(0xFFFACC15);
  static const Color yellow500 = Color(0xFFEAB308);
  static const Color yellow600 = Color(0xFFCA8A04);
  static const Color yellow700 = Color(0xFFA16207);
  static const Color yellow800 = Color(0xFF854D0E);
  static const Color yellow900 = Color(0xFF713F12);
  static const Color yellow950 = Color(0xFF422006);

  // ===========================================================================
  // Brand Themes (Figma `Brand Themes/Theme Cards`)
  // ----------------------------------------------------------------------------
  // 既定テーマ: 藍 (Ai)。`brand*` エイリアスは Ai を指す。
  // 他テーマ (朱 Shu / 抹茶 Matcha) は将来切替時のために定数保持。
  // ===========================================================================

  // Theme 藍 (Ai) — 既定
  static const Color aiPrimary = Color(0xFF173A5E);
  static const Color aiPrimaryHover = Color(0xFF102D49);
  static const Color aiPrimaryPressed = Color(0xFF0B2236);
  static const Color aiPrimarySubtleStrong = Color(0xFFD6E0EA);
  static const Color aiPrimarySubtle = Color(0xFFEDF2F6);
  static const Color aiPrimaryBorder = Color(0xFFA9C0D6);
  static const Color aiAccent = Color(0xFFB83B3B);

  // Theme 朱 (Shu)
  static const Color shuPrimary = Color(0xFFB83B3B);
  static const Color shuPrimaryHover = Color(0xFF9A2E2E);
  static const Color shuPrimaryPressed = Color(0xFF7B2424);
  static const Color shuPrimarySubtleStrong = Color(0xFFF8D9D0);
  static const Color shuPrimarySubtle = Color(0xFFFCEFEB);
  static const Color shuPrimaryBorder = Color(0xFFF0B5A4);
  static const Color shuAccent = Color(0xFF1F4870);

  // Theme 抹茶 (Matcha)
  static const Color matchaPrimary = Color(0xFF557030);
  static const Color matchaPrimaryHover = Color(0xFF445A26);
  static const Color matchaPrimaryPressed = Color(0xFF34471D);
  static const Color matchaPrimarySubtleStrong = Color(0xFFDDE8C5);
  static const Color matchaPrimarySubtle = Color(0xFFF1F5E8);
  static const Color matchaPrimaryBorder = Color(0xFFBCD089);
  static const Color matchaAccent = Color(0xFF9A5320);

  // Brand alias → Ai (既定)
  static const Color brandPrimary = aiPrimary;
  static const Color brandPrimaryHover = aiPrimaryHover;
  static const Color brandPrimaryPressed = aiPrimaryPressed;
  static const Color brandPrimarySubtleStrong = aiPrimarySubtleStrong;
  static const Color brandPrimarySubtle = aiPrimarySubtle;
  static const Color brandPrimaryBorder = aiPrimaryBorder;
  static const Color brandAccent = aiAccent;
  static const Color brandOnPrimary = Color(0xFFFBF8F1); // = bgCanvas

  // ===========================================================================
  // Semantic — Background (Figma `Semantic Colors/Background`)
  // ===========================================================================
  static const Color bgCanvas = Color(0xFFFBF8F1);
  static const Color bgSurface = Color(0xFFF5EFE2);
  static const Color bgSubtle = Color(0xFFEDE3CE);
  static const Color bgMuted = Color(0xFFDFD0AC);
  static const Color bgStrong = Color(0xFFC9B57C);
  static const Color bgInverse = Color(0xFF161513);

  // ===========================================================================
  // Semantic — Border (Figma `Semantic Colors/Border`)
  // ===========================================================================
  static const Color borderSubtle = Color(0xFFDFD0AC);
  static const Color borderDefault = Color(0xFFC9B57C);
  static const Color borderStrong = Color(0xFF74716A);
  static const Color borderFocus = Color(0xFF173A5E);
  static const Color borderInverse = Color(0xFF161513);

  // ===========================================================================
  // Semantic — Text (Figma `Semantic Colors/Text`)
  // ===========================================================================
  static const Color textPrimary = Color(0xFF161513);
  static const Color textSecondary = Color(0xFF2A2825);
  static const Color textTertiary = Color(0xFF74716A);
  static const Color textDisabled = Color(0xFFA8A498);
  static const Color textInverse = Color(0xFFFBF8F1);
  static const Color textLink = Color(0xFF102D49);

  // ===========================================================================
  // Semantic — Status: Danger / Info / Success / Warning
  // (Figma `Semantic Colors/{Danger,Info,Success,Warning}`)
  // ===========================================================================
  // Danger
  static const Color dangerBg = Color(0xFFFCEFEB);
  static const Color dangerBgStrong = Color(0xFF9A2E2E);
  static const Color dangerBorder = Color(0xFFE48971);
  static const Color dangerText = Color(0xFF7B2424);
  static const Color dangerIcon = Color(0xFF9A2E2E);

  // Info
  static const Color infoBg = Color(0xFFEDF2F6);
  static const Color infoBgStrong = Color(0xFF173A5E);
  static const Color infoBorder = Color(0xFF7196B6);
  static const Color infoText = Color(0xFF102D49);
  static const Color infoIcon = Color(0xFF173A5E);

  // Success
  static const Color successBg = Color(0xFFF1F5E8);
  static const Color successBgStrong = Color(0xFF445A26);
  static const Color successBorder = Color(0xFF90B557);
  static const Color successText = Color(0xFF34471D);
  static const Color successIcon = Color(0xFF445A26);

  // Warning
  static const Color warningBg = Color(0xFFFAF1E5);
  static const Color warningBgStrong = Color(0xFF9A5320);
  static const Color warningBorder = Color(0xFFD29553);
  static const Color warningText = Color(0xFF43240F);
  static const Color warningIcon = Color(0xFF7C411A);

  // ===========================================================================
  // Semantic — POS 通信ステータス (Figma `Semantic Colors/POS Status`)
  // ===========================================================================
  static const Color statusOnline = Color(0xFF557030);
  static const Color statusOffline = Color(0xFF9A5320);
  static const Color statusBluetooth = Color(0xFF1F4870);
  static const Color statusSyncing = Color(0xFF3E6B95);
  static const Color statusSyncError = Color(0xFF9A2E2E);

  // ===========================================================================
  // Spacing スケール (Figma `Spacing/space/0..14`, 数値は px)
  // ===========================================================================
  static const double space0 = 0;
  static const double space1 = 2;
  static const double space2 = 4;
  static const double space3 = 8;
  static const double space4 = 12;
  static const double space5 = 16;
  static const double space6 = 20;
  static const double space7 = 24;
  static const double space8 = 32;
  static const double space9 = 40;
  static const double space10 = 48;
  static const double space11 = 64;
  static const double space12 = 80;
  static const double space13 = 96;
  static const double space14 = 128;

  // ===========================================================================
  // Radius スケール (Figma `Radius/{none,xs,sm,md,lg,xl,2xl,full}`)
  // ===========================================================================
  static const double radiusNone = 0;
  static const double radiusXs = 2;
  static const double radiusSm = 4;
  static const double radiusMd = 8;
  static const double radiusLg = 12;
  static const double radiusXl = 16;
  static const double radius2xl = 24;
  static const double radiusFull = 9999;

  // ===========================================================================
  // Stroke
  // ===========================================================================
  static const double strokeHairline = 1;
  static const double strokeThick = 2;

  // ===========================================================================
  // Elevation (Figma `Elevation/{sm,md,lg,xl,focus-ring}`, DROP_SHADOW)
  // ===========================================================================
  static const List<BoxShadow> elevationSm = <BoxShadow>[
    BoxShadow(
      color: Color(0x0D000000),
      offset: Offset(0, 1),
      blurRadius: 2,
    ),
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

  /// フォーカスリング (Figma `Elevation/focus-ring`)。
  /// blue-500 系を spread 3px で外側描画。
  static const List<BoxShadow> elevationFocusRing = <BoxShadow>[
    BoxShadow(
      color: Color(0x663B82F6),
      spreadRadius: 3,
    ),
  ];

  // ===========================================================================
  // タッチターゲット (仕様書 §12.1)
  // ===========================================================================
  /// 一般操作の最小タップ領域。
  static const double touchMin = 56;

  /// 主要操作 (会計確定・提供完了等) の最小タップ領域。
  static const double touchPrimary = 72;

  /// 隣接ボタン間の最低スペース。
  static const double adjacentSpacing = 8;

  /// 確定系と破壊系の間の最低スペース (誤タップ防止)。
  static const double destructiveSpacing = 16;

  // ===========================================================================
  // Safe Area (仕様書 §12.2)
  // ===========================================================================
  static const double safeAreaInset = 16;

  // ===========================================================================
  // モーション (仕様書 §12.1)
  // ===========================================================================
  static const Duration motionShort = Duration(milliseconds: 200);
  static const Duration motionMedium = Duration(milliseconds: 250);
  static const Duration motionSheet = Duration(milliseconds: 280);

  // ===========================================================================
  // フォント
  // ===========================================================================
  /// 日本語フォントは Noto Sans JP (SIL OFL 1.1) をアプリに同梱する。
  ///
  /// Figma 上のデザイン指定は IBM Plex Sans JP だが、当該フォントを
  /// bundle すると配布物が大きく肥大するため、視覚的に近く CJK 全体を
  /// カバーする Noto Sans JP を採用する。bundle していなかった頃は
  /// 古い Android (システムフォントに日本語が無い) で文字が豆腐 (□)
  /// になっていたため、ファミリ名は必ず pubspec.yaml の `fonts:` 宣言
  /// と一致させること。
  static const String fontFamily = 'NotoSansJP';
}

/// タイポグラフィ (Figma `Typography` styles 11:2..11:19)。
///
/// 各 [TextStyle] は Figma の `fontFamily / fontSize / fontWeight /
/// lineHeightPx / letterSpacing` を厳密に反映する。
class TofuTextStyles {
  const TofuTextStyles._();

  // ---- Display ---------------------------------------------------------------
  /// `Display/L` — 72px / 80lh / w700 / ls -1.44 (= -0.02em)
  static const TextStyle displayL = TextStyle(
    fontFamily: TofuTokens.fontFamily,
    fontSize: 72,
    height: 80 / 72,
    letterSpacing: -1.44,
    fontWeight: FontWeight.w700,
    color: TofuTokens.textPrimary,
  );

  /// `Display/M` — 56px / 64lh / w700 / ls -1.12
  static const TextStyle displayM = TextStyle(
    fontFamily: TofuTokens.fontFamily,
    fontSize: 56,
    height: 64 / 56,
    letterSpacing: -1.12,
    fontWeight: FontWeight.w700,
    color: TofuTokens.textPrimary,
  );

  /// `Display/S` — 48px / 56lh / w600 / ls -0.48
  static const TextStyle displayS = TextStyle(
    fontFamily: TofuTokens.fontFamily,
    fontSize: 48,
    height: 56 / 48,
    letterSpacing: -0.48,
    fontWeight: FontWeight.w600,
    color: TofuTokens.textPrimary,
  );

  // ---- Heading ---------------------------------------------------------------
  /// `Heading/H1` — 40px / 48lh / w600 / ls -0.40
  static const TextStyle h1 = TextStyle(
    fontFamily: TofuTokens.fontFamily,
    fontSize: 40,
    height: 48 / 40,
    letterSpacing: -0.40,
    fontWeight: FontWeight.w600,
    color: TofuTokens.textPrimary,
  );

  /// `Heading/H2` — 32px / 40lh / w600 / ls -0.16
  static const TextStyle h2 = TextStyle(
    fontFamily: TofuTokens.fontFamily,
    fontSize: 32,
    height: 40 / 32,
    letterSpacing: -0.16,
    fontWeight: FontWeight.w600,
    color: TofuTokens.textPrimary,
  );

  /// `Heading/H3` — 24px / 32lh / w500 / ls 0
  static const TextStyle h3 = TextStyle(
    fontFamily: TofuTokens.fontFamily,
    fontSize: 24,
    height: 32 / 24,
    fontWeight: FontWeight.w500,
    color: TofuTokens.textPrimary,
  );

  /// `Heading/H4` — 20px / 28lh / w500 / ls 0
  static const TextStyle h4 = TextStyle(
    fontFamily: TofuTokens.fontFamily,
    fontSize: 20,
    height: 28 / 20,
    fontWeight: FontWeight.w500,
    color: TofuTokens.textPrimary,
  );

  // ---- Body ------------------------------------------------------------------
  /// `Body/Lg` — 18px / 28lh / w400
  static const TextStyle bodyLg = TextStyle(
    fontFamily: TofuTokens.fontFamily,
    fontSize: 18,
    height: 28 / 18,
    fontWeight: FontWeight.w400,
    color: TofuTokens.textPrimary,
  );

  /// `Body/Lg-Bold` — 18px / 28lh / w600
  static const TextStyle bodyLgBold = TextStyle(
    fontFamily: TofuTokens.fontFamily,
    fontSize: 18,
    height: 28 / 18,
    fontWeight: FontWeight.w600,
    color: TofuTokens.textPrimary,
  );

  /// `Body/Md` — 16px / 24lh / w400
  static const TextStyle bodyMd = TextStyle(
    fontFamily: TofuTokens.fontFamily,
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeight.w400,
    color: TofuTokens.textPrimary,
  );

  /// `Body/Md-Bold` — 16px / 24lh / w600
  static const TextStyle bodyMdBold = TextStyle(
    fontFamily: TofuTokens.fontFamily,
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeight.w600,
    color: TofuTokens.textPrimary,
  );

  /// `Body/Sm` — 14px / 20lh / w400
  static const TextStyle bodySm = TextStyle(
    fontFamily: TofuTokens.fontFamily,
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w400,
    color: TofuTokens.textPrimary,
  );

  /// `Body/Sm-Bold` — 14px / 20lh / w500
  static const TextStyle bodySmBold = TextStyle(
    fontFamily: TofuTokens.fontFamily,
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w500,
    color: TofuTokens.textPrimary,
  );

  // ---- Caption ---------------------------------------------------------------
  /// `Caption` — 12px / 16lh / w400 / ls 0.06
  static const TextStyle caption = TextStyle(
    fontFamily: TofuTokens.fontFamily,
    fontSize: 12,
    height: 16 / 12,
    letterSpacing: 0.06,
    fontWeight: FontWeight.w400,
    color: TofuTokens.textTertiary,
  );

  /// `Caption-Bold` — 12px / 16lh / w500 / ls 0.06
  static const TextStyle captionBold = TextStyle(
    fontFamily: TofuTokens.fontFamily,
    fontSize: 12,
    height: 16 / 12,
    letterSpacing: 0.06,
    fontWeight: FontWeight.w500,
    color: TofuTokens.textTertiary,
  );

  // ---- Number ----------------------------------------------------------------
  /// `Number/Display` — 72px / 80lh / w700 / ls -0.72
  ///
  /// 整理券番号や合計金額など、視認性最優先の超大型数値に使う。
  static const TextStyle numberDisplay = TextStyle(
    fontFamily: TofuTokens.fontFamily,
    fontSize: 72,
    height: 80 / 72,
    letterSpacing: -0.72,
    fontWeight: FontWeight.w700,
    color: TofuTokens.textPrimary,
  );

  /// `Number/Lg` — 32px / 40lh / w700
  static const TextStyle numberLg = TextStyle(
    fontFamily: TofuTokens.fontFamily,
    fontSize: 32,
    height: 40 / 32,
    fontWeight: FontWeight.w700,
    color: TofuTokens.textPrimary,
  );

  /// `Number/Md` — 24px / 32lh / w500
  static const TextStyle numberMd = TextStyle(
    fontFamily: TofuTokens.fontFamily,
    fontSize: 24,
    height: 32 / 24,
    fontWeight: FontWeight.w500,
    color: TofuTokens.textPrimary,
  );
}
