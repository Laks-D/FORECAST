# App Flow Audit

Date: 2026-05-27

## Fixed in this pass
- Login mode selection could be overwritten by the async load of saved mode, forcing Tutor even when Client was selected. Fixed by preventing `_load()` from overriding a manual selection. See [lib/core/app/app_mode_cubit.dart](lib/core/app/app_mode_cubit.dart).
- Login tab label said Student; updated to Client to match the app wording. See [lib/core/app/widgets/app_mode_selector.dart](lib/core/app/widgets/app_mode_selector.dart).
- Join-request accept now links created client records with `firebaseUid` to avoid client data mixing. See [lib/features/join_request/ui/join_request_banner.dart](lib/features/join_request/ui/join_request_banner.dart).

## Issues still present (need decision or follow-up)
- Role selection vs auto-routing conflict: Landing logic forces mode for single-role users. Dual-role switching is supported only when roles indicate both. This can still be confusing for users who expect the login tab to always decide mode. See [lib/features/landing/ui/landing_screen.dart](lib/features/landing/ui/landing_screen.dart).
- Join-request acceptance writes incorrect `tutorName` into the client enrollment (uses clientName). See [lib/features/join_request/join_request_service.dart](lib/features/join_request/join_request_service.dart).
- Client records are created in UI after accept, not in the accept transaction itself. If the banner flow fails, the client can be enrolled but missing in the tutor’s list. See [lib/features/join_request/ui/join_request_banner.dart](lib/features/join_request/ui/join_request_banner.dart).
- Join-request timeout does not update the request status, leaving stale pending records. See [lib/features/join_request/ui/join_request_waiting_page.dart](lib/features/join_request/ui/join_request_waiting_page.dart).
- Client list is not live-synced; it loads once and then mutates locally. Cross-device updates require reload. See [lib/features/client/data/datasources/client_local_datasource.dart](lib/features/client/data/datasources/client_local_datasource.dart) and [lib/features/client/presentation/bloc/client_bloc.dart](lib/features/client/presentation/bloc/client_bloc.dart).
- Session IDs are generated from local timestamps and can collide across devices. See [lib/features/calendar/domain/services/schedule_generator.dart](lib/features/calendar/domain/services/schedule_generator.dart).
- Notification preferences are stored, but there is no scheduler that turns them into real notifications. See [lib/core/services/notification_cubit.dart](lib/core/services/notification_cubit.dart).

## Blank-screen note
If the blank screen persists after the login-mode fix above, collect the exact step sequence and any runtime logs. The likely cause was the mode selection being overwritten during the first login flow.
