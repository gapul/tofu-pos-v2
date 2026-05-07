import 'package:meta/meta.dart';

import '../enums/customer_attributes_enums.dart';

/// 顧客属性（仕様書 §5.2 / §6.1.1）。
///
/// 顧客属性入力フラグがオンのときのみ収集される。
/// レジ担当の見立てで選ぶ前提のため、すべて null 可。
@immutable
class CustomerAttributes {
  const CustomerAttributes({
    this.age,
    this.gender,
    this.group,
  });

  static const CustomerAttributes empty = CustomerAttributes();

  final CustomerAge? age;
  final CustomerGender? gender;
  final CustomerGroup? group;

  bool get isEmpty => age == null && gender == null && group == null;

  CustomerAttributes copyWith({
    CustomerAge? age,
    CustomerGender? gender,
    CustomerGroup? group,
    bool clearAge = false,
    bool clearGender = false,
    bool clearGroup = false,
  }) {
    return CustomerAttributes(
      age: clearAge ? null : (age ?? this.age),
      gender: clearGender ? null : (gender ?? this.gender),
      group: clearGroup ? null : (group ?? this.group),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CustomerAttributes &&
          age == other.age &&
          gender == other.gender &&
          group == other.group);

  @override
  int get hashCode => Object.hash(age, gender, group);
}
