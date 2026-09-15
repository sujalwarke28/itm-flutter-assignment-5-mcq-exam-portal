import 'package:flutter/material.dart';

import '../utils/app_theme.dart';

/// Tappable avatar with a camera badge and an upload spinner overlay — used
/// wherever the app lets the user change their profile picture.
class ProfileAvatarPicker extends StatelessWidget {
  final String? photoUrl;
  final bool isUploading;
  final VoidCallback? onTap;
  final double radius;
  final IconData placeholderIcon;

  const ProfileAvatarPicker({
    super.key,
    required this.photoUrl,
    required this.isUploading,
    required this.onTap,
    this.radius = 26,
    this.placeholderIcon = Icons.person_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isUploading ? null : onTap,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircleAvatar(
            radius: radius,
            backgroundColor: AppColors.primary.withValues(alpha: 0.12),
            backgroundImage: photoUrl != null ? NetworkImage(photoUrl!) : null,
            child: photoUrl == null ? Icon(placeholderIcon, color: AppColors.primary) : null,
          ),
          if (isUploading)
            CircleAvatar(
              radius: radius,
              backgroundColor: Colors.black45,
              child: SizedBox(
                height: radius * 0.75,
                width: radius * 0.75,
                child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
            )
          else if (onTap != null)
            Positioned(
              bottom: -2,
              right: -2,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: Theme.of(context).cardColor, width: 2),
                ),
                child: const Icon(Icons.camera_alt_rounded, size: 12, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}
