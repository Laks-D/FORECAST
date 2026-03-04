import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gendral_app/features/dashboard/bloc/dashboard_cubit.dart';
import 'package:gendral_app/features/settings/ui/profile/profile_details_screen.dart';
import 'package:gendral_app/features/settings/ui/profile/profile_photo_screen.dart';

void main() {
  testWidgets('Profile photo fullscreen opens and pops on blur tap', (tester) async {
    final cubit = DashboardCubit();

    await tester.pumpWidget(
      BlocProvider.value(
        value: cubit,
        child: const MaterialApp(home: ProfileDetailsScreen()),
      ),
    );

    await tester.tap(find.byKey(const Key('profile_avatar_tap')));
    await tester.pumpAndSettle();

    expect(find.byType(ProfilePhotoScreen), findsOneWidget);

    // Tap a corner of the screen to ensure we hit the blurred background,
    // not the centered avatar/edit button.
    await tester.tapAt(const Offset(10, 300));
    await tester.pumpAndSettle();

    expect(find.byType(ProfileDetailsScreen), findsOneWidget);
  });
}
