import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Round profile picture: a just-picked local file, the saved photo,
/// or the person's initials.
class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, required this.name, this.photoUrl, this.localPath, this.radius = 28});

  final String name;
  final String? photoUrl;

  /// A freshly picked image that is not uploaded yet; wins over [photoUrl].
  final String? localPath;
  final double radius;

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    final first = parts.first[0];
    final last = parts.length > 1 ? parts.last[0] : '';
    return (first + last).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    ImageProvider? image;
    if (localPath != null) {
      image = FileImage(File(localPath!));
    } else if (photoUrl != null && photoUrl!.isNotEmpty) {
      image = CachedNetworkImageProvider(photoUrl!);
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.maroon,
      foregroundImage: image,
      child: Text(
        _initials,
        style: TextStyle(color: AppColors.gold, fontSize: radius * 0.7, fontWeight: FontWeight.w700),
      ),
    );
  }
}
