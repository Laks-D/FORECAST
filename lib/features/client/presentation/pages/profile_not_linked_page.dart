import 'package:flutter/material.dart';

import '../../../../design_system/widgets/app_empty_state.dart';

class ProfileNotLinkedPage extends StatelessWidget {
  const ProfileNotLinkedPage({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bgColor = scheme.surface;
    final onSurface = scheme.onSurface;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        foregroundColor: onSurface,
        elevation: 0,
        title: const Text('My profile'),
      ),
      body: const Center(
        child: AppEmptyState(
          message: 'No profile linked to this account',
          icon: Icons.person_outline,
        ),
      ),
    );
  }
}
