/// 端末の役割（仕様書 §2）。
enum DeviceRole {
  register,
  kitchen,
  calling
  ;

  String get label {
    switch (this) {
      case DeviceRole.register:
        return 'レジ';
      case DeviceRole.kitchen:
        return 'キッチン';
      case DeviceRole.calling:
        return '呼び出し';
    }
  }
}
