import 'package:equatable/equatable.dart';

/// A dance school: `schools/{schoolId}`. The name and city are readable
/// before sign-in so the sign-up screen can show the institute dropdown.
class Institute extends Equatable {
  const Institute({
    required this.id,
    required this.name,
    this.city,
    this.ownerId,
    this.active = true,
  });

  final String id;
  final String name;
  final String? city;

  /// The guru who registered it.
  final String? ownerId;
  final bool active;

  String get displayName => city == null || city!.isEmpty ? name : '$name, $city';

  factory Institute.fromMap(String id, Map<String, dynamic> map) => Institute(
        id: id,
        name: map['name'] as String? ?? '',
        city: map['city'] as String?,
        ownerId: map['ownerId'] as String?,
        active: map['active'] as bool? ?? true,
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'city': city,
        'ownerId': ownerId,
        'active': active,
      };

  @override
  List<Object?> get props => [id, name, city, ownerId, active];
}
