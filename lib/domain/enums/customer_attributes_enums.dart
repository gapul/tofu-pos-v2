/// 顧客属性の値域（仕様書 §5.2 / §6.1.1）。
///
/// レジ担当が見立てで選ぶ前提のため、選択肢は粗めに保つ。
library;

enum CustomerAge {
  under10,
  teens,
  twenties,
  thirties,
  forties,
  fifties,
  sixtiesPlus
  ;

  String get label {
    switch (this) {
      case CustomerAge.under10:
        return '〜10s';
      case CustomerAge.teens:
        return '10代';
      case CustomerAge.twenties:
        return '20代';
      case CustomerAge.thirties:
        return '30代';
      case CustomerAge.forties:
        return '40代';
      case CustomerAge.fifties:
        return '50代';
      case CustomerAge.sixtiesPlus:
        return '60代+';
    }
  }
}

enum CustomerGender {
  male,
  female,
  other
  ;

  String get label {
    switch (this) {
      case CustomerGender.male:
        return '男性';
      case CustomerGender.female:
        return '女性';
      case CustomerGender.other:
        return 'その他';
    }
  }
}

enum CustomerGroup {
  solo,
  couple,
  family,
  group
  ;

  String get label {
    switch (this) {
      case CustomerGroup.solo:
        return '1人';
      case CustomerGroup.couple:
        return 'カップル';
      case CustomerGroup.family:
        return '家族';
      case CustomerGroup.group:
        return 'グループ';
    }
  }
}
