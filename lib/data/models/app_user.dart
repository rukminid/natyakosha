import 'package:equatable/equatable.dart';

import 'model_utils.dart';

enum UserRole {
  guru,
  teacher,
  student,
  parent;

  /// Gurus and teachers manage the school; students and parents view.
  bool get isStaff => this == UserRole.guru || this == UserRole.teacher;

  String get label => switch (this) {
        UserRole.guru => 'Guru',
        UserRole.teacher => 'Teacher',
        UserRole.student => 'Student',
        UserRole.parent => 'Parent',
      };
}

/// New sign-ups start as [pending] until a guru of the institute approves.
enum AccountStatus {
  pending,
  approved,
  rejected,

  /// A student the guru added and later removed from the roster.
  inactive;

  String get label => switch (this) {
        AccountStatus.pending => 'Waiting for approval',
        AccountStatus.approved => 'Approved',
        AccountStatus.rejected => 'Not approved',
        AccountStatus.inactive => 'Removed',
      };
}

enum Gender {
  female,
  male,
  other,
  preferNotToSay;

  String get label => switch (this) {
        Gender.female => 'Female',
        Gender.male => 'Male',
        Gender.other => 'Other',
        Gender.preferNotToSay => 'Prefer not to say',
      };
}

/// Stored at `users/{uid}`. Holds the school the person belongs to,
/// so security rules and queries can scope everything to that school.
class AppUser extends Equatable {
  const AppUser({
    required this.id,
    required this.name,
    required this.role,
    required this.schoolId,
    this.status = AccountStatus.approved,
    this.schoolName,
    this.email,
    this.phone,
    this.dob,
    this.gender,
    this.batchId,
    this.childIds = const [],
    this.photoUrl,
    this.managed = false,
    this.guardianPhone,
    this.createdAt,
  });

  final String id;
  final String name;
  final UserRole role;
  final String schoolId;

  /// Accounts created in the Firebase console without a status count as approved.
  final AccountStatus status;

  /// Denormalised so "waiting for approval from `<institute>`" needs no extra read.
  final String? schoolName;
  final String? email;

  /// E.164, e.g. +919876543210. Used as the login id.
  final String? phone;
  final DateTime? dob;
  final Gender? gender;
  final String? batchId;

  /// For parents: the student ids they can see.
  final List<String> childIds;
  final String? photoUrl;

  /// Added by the guru, with no login of their own (the student may never
  /// install the app). Only staff edit these records.
  final bool managed;

  /// Parent or guardian mobile, E.164. Kept for the guru; not a login id.
  final String? guardianPhone;
  final DateTime? createdAt;

  bool get isApproved => status == AccountStatus.approved;

  factory AppUser.fromMap(String id, Map<String, dynamic> map) => AppUser(
        id: id,
        name: map['name'] as String? ?? '',
        role: readEnum(UserRole.values, map['role'], UserRole.student),
        schoolId: map['schoolId'] as String? ?? '',
        status: readEnum(AccountStatus.values, map['status'], AccountStatus.approved),
        schoolName: map['schoolName'] as String?,
        email: map['email'] as String?,
        phone: map['phone'] as String?,
        dob: readDate(map['dob']),
        gender: map['gender'] == null ? null : readEnum(Gender.values, map['gender'], Gender.other),
        batchId: map['batchId'] as String?,
        childIds: readStringList(map['childIds']),
        photoUrl: map['photoUrl'] as String?,
        managed: map['managed'] == true,
        guardianPhone: map['guardianPhone'] as String?,
        createdAt: readDate(map['createdAt']),
      );

  /// For Firestore (dates as Timestamps).
  Map<String, dynamic> toMap() => {
        ..._plain(),
        'dob': writeTimestamp(dob),
        'createdAt': writeTimestamp(createdAt),
      };

  /// For the Hive cache (includes the id; dates as ISO strings).
  Map<String, dynamic> toJson() => {
        'id': id,
        ..._plain(),
        'dob': writeDateIso(dob),
        'createdAt': writeDateIso(createdAt),
      };

  factory AppUser.fromJson(Map<String, dynamic> json) =>
      AppUser.fromMap(json['id'] as String, json);

  Map<String, dynamic> _plain() => {
        'name': name,
        'role': role.name,
        'schoolId': schoolId,
        'status': status.name,
        'schoolName': schoolName,
        'email': email,
        'phone': phone,
        'gender': gender?.name,
        'batchId': batchId,
        'childIds': childIds,
        'photoUrl': photoUrl,
        'managed': managed,
        'guardianPhone': guardianPhone,
      };

  AppUser copyWith({
    AccountStatus? status,
    String? name,
    DateTime? dob,
    Gender? gender,
    String? photoUrl,
    String? guardianPhone,
  }) =>
      AppUser(
        id: id,
        name: name ?? this.name,
        role: role,
        schoolId: schoolId,
        status: status ?? this.status,
        schoolName: schoolName,
        email: email,
        phone: phone,
        dob: dob ?? this.dob,
        gender: gender ?? this.gender,
        batchId: batchId,
        childIds: childIds,
        photoUrl: photoUrl ?? this.photoUrl,
        managed: managed,
        guardianPhone: guardianPhone ?? this.guardianPhone,
        createdAt: createdAt,
      );

  @override
  List<Object?> get props => [
        id, name, role, schoolId, status, schoolName, email, phone, dob,
        gender, batchId, childIds, photoUrl, managed, guardianPhone, createdAt,
      ];
}
