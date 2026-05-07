import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../domain/entities/order.dart';
import 'csv_export_service.dart';

/// 共有シート起動を抽象化する関数シグネチャ（テスト容易性のため）。
typedef ShareSheetLauncher = Future<ShareResult> Function(
  List<XFile> files, {
  String? subject,
});

Future<ShareResult> _defaultShareLauncher(
  List<XFile> files, {
  String? subject,
}) {
  return Share.shareXFiles(files, subject: subject);
}

/// CsvExportService が組み立てた CSV をファイルに書き出し、OS の共有シートを開く。
///
/// 仕様書 §8.3 のローカルデータ救出経路。
class CsvExportFileService {
  CsvExportFileService({
    CsvExportService csv = const CsvExportService(),
    Future<Directory> Function() getDirectory =
        getApplicationDocumentsDirectory,
    ShareSheetLauncher share = _defaultShareLauncher,
    DateTime Function() now = DateTime.now,
  })  : _csv = csv,
        _getDirectory = getDirectory,
        _share = share,
        _now = now;

  final CsvExportService _csv;
  final Future<Directory> Function() _getDirectory;
  final ShareSheetLauncher _share;
  final DateTime Function() _now;

  /// CSV をファイルに書き出して、書き出し先のパスを返す。
  Future<String> writeToFile({
    required Iterable<Order> orders,
    required String shopId,
  }) async {
    final String csv = _csv.serialize(orders: orders, shopId: shopId);
    final Directory dir = await _getDirectory();
    final String fileName = _buildFileName(shopId);
    final File file = File(p.join(dir.path, fileName));
    await file.writeAsString(csv);
    return file.path;
  }

  /// 書き出し → OS の共有シート起動 まで一気にやる。
  Future<String> writeAndShare({
    required Iterable<Order> orders,
    required String shopId,
  }) async {
    final String path = await writeToFile(orders: orders, shopId: shopId);
    await _share(
      <XFile>[XFile(path)],
      subject: 'Tofu POS 売上データ',
    );
    return path;
  }

  String _buildFileName(String shopId) {
    final DateTime n = _now();
    final String stamp = '${n.year.toString().padLeft(4, '0')}'
        '${n.month.toString().padLeft(2, '0')}'
        '${n.day.toString().padLeft(2, '0')}'
        '_${n.hour.toString().padLeft(2, '0')}'
        '${n.minute.toString().padLeft(2, '0')}';
    final String safeShopId =
        shopId.replaceAll(RegExp(r'[^A-Za-z0-9_\-]'), '_');
    return 'tofu-pos_${safeShopId}_$stamp.csv';
  }
}
