import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../design_system/theme/app_chrome_theme.dart';
import '../../../dashboard/bloc/dashboard_cubit.dart';
import '../../../dashboard/bloc/dashboard_state.dart';
import 'profile_media.dart';

class ProfilePhotoScreen extends StatefulWidget {
  const ProfilePhotoScreen({super.key});

  @override
  State<ProfilePhotoScreen> createState() => _ProfilePhotoScreenState();
}

class _ProfilePhotoScreenState extends State<ProfilePhotoScreen> {
  late double _x;
  late double _y;
  double _scale = 1.0;
  double _baseScale = 1.0;

  Alignment get _alignment => Alignment(_x, _y);

  void _handleScaleStart(ScaleStartDetails details) {
    _baseScale = _scale;
  }

  void _handleScaleUpdate(ScaleUpdateDetails details, Size size) {
    // Pinch zoom
    if (details.pointerCount >= 2) {
      setState(() {
        _scale = (_baseScale * details.scale).clamp(1.0, 4.0);
      });
      return;
    }

    // Single-finger drag (pan)
    if (size.width <= 0 || size.height <= 0) return;
    final nextX = (_x - (details.focalPointDelta.dx / (size.width / 3.2))).clamp(-1.0, 1.0).toDouble();
    final nextY = (_y - (details.focalPointDelta.dy / (size.height / 3.2))).clamp(-1.0, 1.0).toDouble();

    setState(() {
      _x = nextX;
      _y = nextY;
    });
    context.read<DashboardCubit>().setUserAvatarAlignment(_alignment);
  }

  @override
  void initState() {
    super.initState();
    final current = context.read<DashboardCubit>().state.userAvatarAlignment;
    _x = current.x;
    _y = current.y;
  }

  Future<void> _setAvatar(BuildContext context, ImageSource source) async {
    try {
      final file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 900,
        maxHeight: 900,
        imageQuality: 88,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!context.mounted) return;
      context.read<DashboardCubit>().setUserAvatarBytes(bytes);
      context.read<DashboardCubit>().setUserAvatarAlignment(_alignment);
    } catch (_) {
      // Ignore picker failures.
    }
  }

  @override
  Widget build(BuildContext context) {
    final chrome = AppChromeTheme.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        top: true,
        child: BlocBuilder<DashboardCubit, DashboardState>(
          buildWhen: (p, n) =>
              p.userAvatarBytes != n.userAvatarBytes ||
              p.userAvatarAlignment != n.userAvatarAlignment,
          builder: (context, state) {
            final avatarBytes = state.userAvatarBytes;
            final Widget blurredSource = avatarBytes == null
                ? DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          chrome.accentBlue.withOpacity(0.55),
                          chrome.frameColor.withOpacity(0.55),
                        ],
                      ),
                    ),
                  )
                : Image.memory(
                    avatarBytes,
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                  );

            return Stack(
              fit: StackFit.expand,
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    key: const Key('profile_photo_blur_pop'),
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.of(context).maybePop(),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ImageFiltered(
                          imageFilter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                          child: blurredSource,
                        ),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.10),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Center(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: () => Navigator.of(context).maybePop(),
                              icon: const Icon(Icons.close, color: Colors.white),
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: () => Navigator.of(context).maybePop(),
                              child: Text(
                                'Done',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      color: chrome.accentBlue,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final diameter = (constraints.maxWidth < constraints.maxHeight
                                    ? constraints.maxWidth
                                    : constraints.maxHeight) *
                                0.88;

                            return Center(
                              child: SizedBox.square(
                                dimension: diameter,
                                child: Stack(
                                  children: [
                                    Positioned.fill(
                                      child: GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onScaleStart: _handleScaleStart,
                                        onScaleUpdate: (d) => _handleScaleUpdate(d, Size(diameter, diameter)),
                                        child: ClipOval(
                                          child: avatarBytes == null
                                              ? DecoratedBox(
                                                  decoration: BoxDecoration(
                                                    color: chrome.mutedColor.withOpacity(0.35),
                                                  ),
                                                  child: Center(
                                                    child: Icon(
                                                      Icons.person_outline,
                                                      size: diameter * 0.26,
                                                      color: chrome.surfaceColor.withOpacity(0.95),
                                                    ),
                                                  ),
                                                )
                                              : Transform.scale(
                                                  scale: _scale,
                                                  child: Image.memory(
                                                    avatarBytes,
                                                    fit: BoxFit.cover,
                                                    alignment: _alignment,
                                                  ),
                                                ),
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      right: 10,
                                      bottom: 10,
                                      child: ProfileEditButton(
                                        onTap: () async {
                                          final action = await showProfileImageSourceSheet(
                                            context,
                                            showRemove: avatarBytes != null,
                                          );
                                          if (action == null || !context.mounted) return;
                                          if (action == ProfileImageAction.remove) {
                                            context.read<DashboardCubit>().setUserAvatarBytes(null);
                                            return;
                                          }
                                          final source = action == ProfileImageAction.camera
                                              ? ImageSource.camera
                                              : ImageSource.gallery;
                                          await _setAvatar(context, source);
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
