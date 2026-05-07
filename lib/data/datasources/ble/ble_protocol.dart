import 'dart:convert';
import 'dart:typed_data';

import '../../../core/transport/transport_event.dart';
import '../lan/lan_protocol.dart';

/// BLE Characteristic 書き込みは1回あたり最大 ~512B（典型MTU 247-512）の制約があるため、
/// 大きな TransportEvent を複数フレームに分割・再結合するプロトコル。
///
/// フレーム形式（バイナリ）:
///   [0]   seq    : 0-255 メッセージ識別子（同一メッセージの全フレームで同じ）
///   [1]   total  : このメッセージの総フレーム数（1〜255）
///   [2]   index  : このフレームの番号（0〜total-1）
///   [3..] payload: UTF-8 エンコードされた JSON 文字列の断片
///
/// JSON ペイロード自体は LanProtocol と同じフォーマットを使う（再利用）。
class BleProtocol {
  BleProtocol._();

  /// ヘッダオーバーヘッド。
  static const int headerSize = 3;

  /// Characteristic 書き込みの推奨最大バイト数。
  ///
  /// BLE 4.x で安全な ATT_MTU は 23B、5.x で交渉して 247B〜512B。
  /// 余裕を見て 180 を既定とする（多くのプラットフォームで安全）。
  static const int defaultChunkSize = 180;

  /// メッセージをフレーム列にエンコード。
  static List<Uint8List> encode(
    TransportEvent event, {
    required int seq,
    int chunkSize = defaultChunkSize,
  }) {
    if (seq < 0 || seq > 255) {
      throw ArgumentError('seq must be 0..255');
    }
    if (chunkSize <= headerSize) {
      throw ArgumentError('chunkSize too small (must be > headerSize)');
    }

    final String jsonStr = LanProtocol.encode(event);
    final Uint8List payload = utf8.encode(jsonStr);
    final int payloadPerFrame = chunkSize - headerSize;
    final int total = (payload.length / payloadPerFrame).ceil().clamp(1, 255);

    if (total > 255) {
      throw StateError('Message too large to fit in 255 frames');
    }

    final List<Uint8List> frames = <Uint8List>[];
    for (int i = 0; i < total; i++) {
      final int start = i * payloadPerFrame;
      final int end = (start + payloadPerFrame).clamp(0, payload.length);
      final Uint8List frame = Uint8List(headerSize + (end - start))
        ..[0] = seq
        ..[1] = total
        ..[2] = i;
      frame.setRange(headerSize, frame.length, payload, start);
      frames.add(frame);
    }
    return frames;
  }
}

/// 受信側でフレームを集めて再結合する状態機械。
///
/// 同一 seq のフレームが揃った時点で完成メッセージを返す。
/// 異常時（途中で別 seq が来た等）は対応する seq の進行をリセットする。
class BleFrameAssembler {
  /// `seq` ごとの収集状態。
  final Map<int, _Bucket> _buckets = <int, _Bucket>{};

  /// 1フレームを投入。揃っていればイベントを返す。揃っていなければ null。
  TransportEvent? feed(Uint8List frame) {
    if (frame.length < BleProtocol.headerSize) {
      return null;
    }
    final int seq = frame[0];
    final int total = frame[1];
    final int index = frame[2];
    if (total == 0 || index >= total) {
      return null;
    }

    _Bucket bucket = _buckets[seq] ??= _Bucket(total);
    if (bucket.total != total) {
      // 同 seq で総数が変わったら破棄して新規にする
      bucket = _Bucket(total);
      _buckets[seq] = bucket;
    }

    final Uint8List body = frame.sublist(BleProtocol.headerSize);
    bucket.fragments[index] = body;

    if (bucket.fragments.length < total) {
      return null;
    }

    // 全部揃った → 結合 → デコード
    final BytesBuilder bb = BytesBuilder();
    for (int i = 0; i < total; i++) {
      final Uint8List? f = bucket.fragments[i];
      if (f == null) {
        return null; // 抜けがある（理論上ありえないが念のため）
      }
      bb.add(f);
    }
    _buckets.remove(seq);

    final String jsonStr = utf8.decode(bb.toBytes());
    return LanProtocol.decode(jsonStr);
  }

  /// 進行中だが完成していない seq を破棄。
  void reset() => _buckets.clear();

  int get pendingSeqCount => _buckets.length;
}

class _Bucket {
  _Bucket(this.total) : fragments = <int, Uint8List>{};
  final int total;
  final Map<int, Uint8List> fragments;
}
