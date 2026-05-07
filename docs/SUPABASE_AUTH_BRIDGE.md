# Supabase Auth Bridge

This app uses Firebase Auth as the sign-in source of truth. After a Firebase
sign-in or sign-up succeeds, the Flutter app mirrors the Firebase user into
Supabase by upserting a row in `public.profiles`.

The app-side mirror call is implemented in:
- `lib/services/supabase_service.dart`
- `lib/features/auth/login/bloc/login_bloc.dart`
- `lib/features/auth/signup/ui/signup_screen.dart`

Important:
- Supabase credentials are now supplied via `--dart-define` values named `SUPABASE_URL` and `SUPABASE_ANON_KEY`.
- `public.profiles.id` is the Firebase `uid`.
- The repo now includes an immediate-write schema for `profiles`,
  `organizations`, `students`, and `activities` so the existing Flutter client
  can persist data straight to Supabase.
- The client now writes `display_name` and `photo_url` for profiles, and
  `profession` for students.
- If you later want stronger access control, move these writes behind a trusted
  bridge layer such as a Supabase Edge Function or backend API.

Recommended flow:
1. Firebase Auth signs the user in.
2. The app calls `syncFirebaseUserWithSupabase()`.
3. The client writes directly to the app tables in Supabase.
4. If you later harden access, move the writes behind a trusted bridge.
