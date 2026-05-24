# Project Analysis (Repo Evidence Only)

Date: 2026-05-24

## Scope
- Evidence is limited to what exists in the repo.
- Data sources in scope: Firebase Auth + Firestore.

## High-level architecture
- Flutter app using Bloc/Cubit and a service locator for DI.
- Entry point + Firebase init: [lib/main.dart](lib/main.dart).
- Auth gate and bootstrapping: [lib/features/landing/ui/landing_screen.dart](lib/features/landing/ui/landing_screen.dart).
- App handbook summary: [docs/APP_HANDBOOK.md](docs/APP_HANDBOOK.md).

## Data persistence model
- Primary persistence is Firestore.
- Firestore access layer: [lib/core/services/user_firestore_sync.dart](lib/core/services/user_firestore_sync.dart).
- Firestore-backed stores:
  - Admin profile: [lib/core/storage/admin_profile_storage.dart](lib/core/storage/admin_profile_storage.dart)
  - Signup profile: [lib/core/storage/signup_profile_storage.dart](lib/core/storage/signup_profile_storage.dart)
  - Theme: [lib/features/theme_customization/bloc/app_theme_cubit.dart](lib/features/theme_customization/bloc/app_theme_cubit.dart)
  - Navigation modules: [lib/features/navigation/bloc/nav_modules_cubit.dart](lib/features/navigation/bloc/nav_modules_cubit.dart)
  - Widget customization: [lib/features/widget_customization/bloc/widget_customization_cubit.dart](lib/features/widget_customization/bloc/widget_customization_cubit.dart)
  - Clients: [lib/features/client/data/datasources/client_local_datasource.dart](lib/features/client/data/datasources/client_local_datasource.dart)
  - Sessions: [lib/features/calendar/data/datasources/schedule_local_datasource.dart](lib/features/calendar/data/datasources/schedule_local_datasource.dart)
  - Notifications: [lib/core/services/notification_storage.dart](lib/core/services/notification_storage.dart)

## Firebase usage
- Firebase initialization uses dev/prod options: [lib/main.dart](lib/main.dart).
- Firestore instance accessor: [lib/core/firebase/firestore_db.dart](lib/core/firebase/firestore_db.dart).
- Auth and profile updates:
  - Login: [lib/features/auth/login/bloc/login_bloc.dart](lib/features/auth/login/bloc/login_bloc.dart)
  - Signup: [lib/features/auth/signup/ui/signup_screen.dart](lib/features/auth/signup/ui/signup_screen.dart)

## Firestore database structure (as documented)
- Schema definition and recommended fields: [docs/FIRESTORE_SCHEMA.md](docs/FIRESTORE_SCHEMA.md).
- Top-level collections:
  - users/{uid}
  - usernames/{usernameKey}
- User subcollections:
  - settings/app
  - clients/{clientId}
  - sessions/{sessionId}
  - programs/{programId}
  - notifications/{notificationId}
  - fcmTokens/{token}

## Data flow summary
- Auth
  - Email/username login uses usernames lookup, then Firebase Auth.
  - Google login checks for an existing Firestore user document.
- Profile
  - Signup writes a user document in Firestore and updates settings/profile fields.
  - Admin profile changes persist in Firestore.
- Clients and sessions
  - Read/write directly in Firestore under the signed-in user.
- Settings (theme, nav modules, signup profile, notification prefs)
  - Stored in Firestore settings document.

