import 'package:flutter/material.dart';

import '../../../../design_system/theme/app_chrome_theme.dart';

enum ProfileImageAction { camera, gallery, remove }

Future<ProfileImageAction?> showProfileImageSourceSheet(
  BuildContext context, {
  bool showRemove = false,
}) {
  return showModalBottomSheet<ProfileImageAction>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take photo'),
              onTap: () => Navigator.of(context).pop(ProfileImageAction.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () =>
                  Navigator.of(context).pop(ProfileImageAction.gallery),
            ),
            if (showRemove)
              ListTile(
                leading:
                    Icon(Icons.delete_outline, color: VibrantColors.softPink),
                title: Text('Remove photo',
                    style: TextStyle(color: VibrantColors.softPink)),
                onTap: () =>
                    Navigator.of(context).pop(ProfileImageAction.remove),
              ),
            const SizedBox(height: 6),
          ],
        ),
      );
    },
  );
}

class ProfileEditButton extends StatelessWidget {
  const ProfileEditButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withOpacity(0.62),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withOpacity(0.55)),
          ),
          child: const Icon(
            Icons.edit_outlined,
            size: 18,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
