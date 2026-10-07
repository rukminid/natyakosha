import 'package:equatable/equatable.dart';

import 'app_user.dart';
import 'model_utils.dart';

/// `schools/{schoolId}/directory/{uid}` — the part of a profile every
/// approved member of the school may see: name, role, photo and the
/// birthday (day and month only, never the year or age).
///
/// Students cannot read other `users/{uid}` docs, so chat pickers and the
/// birthday board read this instead. Each person writes only their own entry.
class Member extends Equatable {
  const Member({
    required this.id,
    required this.name,
    required this.role,
    this.photoUrl,
    this.birthMonth,
    this.birthDay,
    this.managed = false,
  });

  final String id;
  final String name;
  final UserRole role;
  final String? photoUrl;
  final int? birthMonth;
  final int? birthDay;

  /// A student the guru added who has no login: shown on the birthday board
  /// but not offered in chat.
  final bool managed;

  bool get isStaff => role.isStaff;
  bool get hasBirthday => birthMonth != null && birthDay != null;

  /// This person's birthday in [year]. A 29 Feb birthday is celebrated on
  /// 28 Feb in years without a leap day. Null when no birthday is set.
  DateTime? birthdayIn(int year) {
    if (!hasBirthday) return null;
    final leapYear = DateTime(year, 3, 0).day == 29;
    final day = (birthMonth == 2 && birthDay == 29 && !leapYear) ? 28 : birthDay!;
    return DateTime(year, birthMonth!, day);
  }

  /// True when the birthday falls on the calendar day [day].
  bool hasBirthdayOn(DateTime day) {
    final b = birthdayIn(day.year);
    return b != null && b.month == day.month && b.day == day.day;
  }

  factory Member.fromMap(String id, Map<String, dynamic> map) => Member(
        id: id,
        name: map['name'] as String? ?? '',
        role: readEnum(UserRole.values, map['role'], UserRole.student),
        photoUrl: map['photoUrl'] as String?,
        birthMonth: map['birthMonth'] as int?,
        birthDay: map['birthDay'] as int?,
        managed: map['managed'] == true,
      );

  /// The entry for [user] (without the server timestamp, added on write).
  factory Member.fromUser(AppUser user) => Member(
        id: user.id,
        name: user.name,
        role: user.role,
        photoUrl: user.photoUrl,
        birthMonth: user.dob?.month,
        birthDay: user.dob?.day,
        managed: user.managed,
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'role': role.name,
        'photoUrl': photoUrl,
        'birthMonth': birthMonth,
        'birthDay': birthDay,
        // Only written for guru-added students; the rules reject it from anyone else.
        if (managed) 'managed': true,
      };

  @override
  List<Object?> get props => [id, name, role, photoUrl, birthMonth, birthDay, managed];
}
