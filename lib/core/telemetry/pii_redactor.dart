import 'dart:convert';

import 'telemetry_event.dart';
import 'telemetry_sink.dart';

/// テレメトリに乗る属性から PII（個人特定情報）を落とす純関数群。
///
/// 方針:
///  * 「無くして良い情報は捨てる」。可逆な暗号化はしない。
///  * 連続値（年齢など）はバケット化して粒度を落とす。
///  * 文字列は SHA を持ち込まずに `String.hashCode` で短い指紋に変換する
///    （衝突は許容する。クラスタ分析できれば十分）。
///  * 既にバケット化済みの enum 表現（`teens` / `twenties` 等）は素通しする。
///
/// 対象キー:
///  * `email`, `mail`, `phone`, `tel`, `name`, `username`
///    → `*_hash` キーに置き換え、原文は捨てる
///  * `age`（整数の生値）→ `age_bucket` (`'10s'` / `'20s'` ...) に置き換え
///  * `customer_age` 等の既にバケット化済みの値は素通し
///
/// 設計上の注意:
///  * `kind` や `message` には触らない。呼び出し側が PII を含めない責務。
///  * `Telemetry.error` が attrs に挿入する `error` / `stack` 文字列もここでは
///    変換しない（例外メッセージ・スタックトレースに PII を入れない、という
///    呼び出し側規約に依存する）。具体例: 顧客名や電話番号を例外メッセージに
///    そのまま埋め込まないこと。
///  * 完全な防御線ではなく多層防御の1枚。新しい PII フィールドを足したら
///    ここの `_piiKeys` も更新する。
class PiiRedactor {
  const PiiRedactor();

  /// 値ごと捨てて *_hash に変換するキー群。
  static const Set<String> _piiKeys = <String>{
    'email',
    'mail',
    'phone',
    'tel',
    'name',
    'username',
    'user_name',
    'full_name',
  };

  /// 値ごと捨てて *_bucket に変換するキー群（数値の年齢など）。
  static const Set<String> _ageKeys = <String>{
    'age',
    'user_age',
    'raw_age',
  };

  /// 例外文字列やスタックトレースが入りうるキー群（呼び出し側規約だけに
  /// 任せず、ここで軽くマスクして多層防御の1枚にする）。
  static const Set<String> _freeTextKeys = <String>{
    'error',
    'stack',
    'stack_trace',
    'message',
    'detail',
    'reason',
  };

  /// メールアドレスらしき塊。`local@domain` を丸ごとマスクする。
  static final RegExp _emailLike = RegExp(r'[\w.+\-]+@[\w.\-]+\.[A-Za-z]{2,}');

  /// 日本の電話番号らしき塊:
  ///   - ハイフン区切り（市外2〜4 / 局番2〜4 / 加入者3〜4）
  ///   - 0 始まりの 10〜11 桁連続
  static final RegExp _phoneHyphen = RegExp(r'\b\d{2,4}-\d{2,4}-\d{3,4}\b');
  static final RegExp _phoneFlat = RegExp(r'\b0\d{9,10}\b');

  /// 単一の attrs マップを redact する。元のマップは破壊しない。
  Map<String, Object?> redact(Map<String, Object?> attrs) {
    if (attrs.isEmpty) return attrs;
    final Map<String, Object?> out = <String, Object?>{};
    for (final MapEntry<String, Object?> e in attrs.entries) {
      final String key = e.key;
      final Object? value = e.value;

      if (_piiKeys.contains(key)) {
        if (value != null) {
          out['${key}_hash'] = _shortHash(value.toString());
        }
        continue;
      }
      if (_ageKeys.contains(key)) {
        out['${key}_bucket'] = _ageBucket(value);
        continue;
      }
      if (_freeTextKeys.contains(key) && value is String) {
        out[key] = _maskFreeText(value);
        continue;
      }
      out[key] = value;
    }
    return out;
  }

  /// 自由テキストから email / 電話番号らしきパターンをマスクする。
  /// 完璧な検出ではなく、誤って漏れた個人情報を最終防衛で減らすことが目的。
  static String _maskFreeText(String s) {
    if (s.isEmpty) return s;
    return s
        .replaceAll(_emailLike, '***@***')
        .replaceAll(_phoneHyphen, '***-****-****')
        .replaceAll(_phoneFlat, '***-****-****');
  }

  /// イベント全体を redact した新しい [TelemetryEvent] を返す。
  TelemetryEvent redactEvent(TelemetryEvent e) {
    return TelemetryEvent(
      shopId: e.shopId,
      deviceId: e.deviceId,
      deviceRole: e.deviceRole,
      kind: e.kind,
      level: e.level,
      occurredAt: e.occurredAt,
      message: e.message,
      scenarioId: e.scenarioId,
      appVersion: e.appVersion,
      attrs: redact(e.attrs),
    );
  }

  /// 整数 `age` を 10 歳刻みのバケットに丸める。
  /// 0..9 → '0s', 10..19 → '10s', ..., 60+ → '60s+'.
  /// 想定外（負数 / 非数）は 'unknown' を返す。
  static String _ageBucket(Object? raw) {
    int? n;
    if (raw is int) {
      n = raw;
    } else if (raw is num) {
      n = raw.toInt();
    } else if (raw is String) {
      n = int.tryParse(raw);
    }
    if (n == null || n < 0) return 'unknown';
    if (n >= 60) return '60s+';
    final int decade = (n ~/ 10) * 10;
    return '${decade}s';
  }

  /// 衝突を許容する短い指紋。
  /// 文字列を UTF-8 にしてから fnv1a 32bit を計算 → 8桁 hex。
  static String _shortHash(String s) {
    const int fnvOffset = 0x811c9dc5;
    const int fnvPrime = 0x01000193;
    int h = fnvOffset;
    for (final int b in utf8.encode(s)) {
      h = (h ^ b) & 0xffffffff;
      h = (h * fnvPrime) & 0xffffffff;
    }
    return h.toRadixString(16).padLeft(8, '0');
  }
}

/// 既存 [TelemetrySink] を [PiiRedactor] でラップして送信前に redact する。
class RedactingTelemetrySink implements TelemetrySink {
  const RedactingTelemetrySink(
    this._inner, {
    PiiRedactor redactor = const PiiRedactor(),
  }) : _redactor = redactor;

  final TelemetrySink _inner;
  final PiiRedactor _redactor;

  @override
  void enqueue(TelemetryEvent event) {
    _inner.enqueue(_redactor.redactEvent(event));
  }

  @override
  Future<void> flush() => _inner.flush();
}
