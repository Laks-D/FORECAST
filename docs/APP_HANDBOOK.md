# GeneralApp — App Handbook

This document is a practical, code-grounded guide to **how the app works**, its **features**, and its **UI/UX patterns**.

> Note: Some docs currently reference `src/` (see `docs/ARCHITECTURE.md`). The actual source layout in this repo is primarily under `lib/`.

---

## 1) What the app is

GeneralApp is an offline-first admin-style app for:
- managing **clients**,
- scheduling **classes/sessions**,
- scheduling & tracking **payments**,
- customizing **theme** and **modules/tabs**,
- basic **notifications** (in-app records + Firebase Messaging token registration).

**Primary persistence is local** via `SharedPreferences`. There is also **best-effort mirroring to Cloud Firestore** for cross-device survival/sync.

Key entry points:
- App bootstrap: `lib/main.dart`
- Auth gate: `lib/features/landing/ui/landing_screen.dart`
- Signed-in shell: `lib/features/dashboard/ui/widgets/dashboard_phone_frame.dart`

---

## 2) App startup & authentication

### Startup flow
1. `main()` initializes Firebase.
2. Service locator/DI is set up (`setupServiceLocator()`).
3. `NotificationService.instance.init()` runs (local-notifications init is skipped on web).
4. Root `App` builds `MaterialApp` using theme state from `AppThemeCubit`.

### Auth gate
`LandingScreen` listens to `FirebaseAuth.authStateChanges()`:
- Signed out → shows auth/signup
- Signed in → wires feature blocs and navigates into the main shell (`DashboardScreen` → `DashboardPhoneFrame`).

---

## 3) Navigation model (tabs/modules)

### Tabs
The main shell is a “phone frame” layout with a bottom-nav.
Tabs are defined in `DashboardTab` and rendered in `DashboardPhoneFrame`:
- **Home** (default)
- **Calendar**
- **Clients**
- **Payments**
- **Settings**

### Module customization
`NavModulesCubit` controls:
- the **order** of tabs
- which tabs are **enabled/visible**

Persistence:
- `SharedPreferences` key: `nav_modules_v1`
- mirrored to Firestore settings doc via `UserFirestoreSync.scheduleSettingsPatch({'navModules': ...})`

Safety rules:
- Home + Settings are always enabled
- app ensures it never ends up with “0 visible tabs”

Settings can also open “hidden modules” as standalone screens while reusing the correct blocs.

---

## 4) Data model, storage, and Firestore mirroring

### Local storage (primary)
Most app data is stored in `SharedPreferences`:
- Theme customization: `app_theme_v2`
- Navigation modules: `nav_modules_v1`
- Admin profile: `admin_profile_data_v1`
- Signup profile: `signup_profile_data_v1`
- Sessions: `sessions_data_v1`
- Clients: (client storage is also local; see client data layer)
- Notifications prefs/records: notification storage keys

### Firestore mirroring (best-effort)
`UserFirestoreSync` is explicitly described as mirroring local data:
- Settings patches → `users/{uid}/settings/app` (debounced merge)
- Clients upsert → `users/{uid}/clients/{clientId}` (debounced batch)
- Sessions upsert → `users/{uid}/sessions/{sessionId}` (debounced batch)
- Admin profile also upserts top-level `users/{uid}` profile fields

> Note: `docs/FIRESTORE_SCHEMA.md` describes Firestore as source-of-truth, but the current code treats local storage as primary and Firestore as sync/mirroring.

---

## 5) UI/UX system (design language)

### Theme primitives
The app uses a `ThemeExtension` named `AppChromeTheme` that provides:
- `frameColor` (outer frame/background)
- `surfaceColor` (cards/sheets)
- `textColor`
- `mutedColor`
- `accentBlue`

See: `lib/design_system/theme/app_chrome_theme.dart`

The runtime `ThemeData` is built by `buildAppTheme(...)`:
- Material 3 enabled (`useMaterial3: true`)
- rounded cards (default radius ~28)
- rounded input fields (default radius ~16)
- text theme comes from `GoogleFonts` (Inter / Orbitron)

See: `lib/design_system/theme/app_theme.dart`

### Recurring interaction patterns
Across the app you’ll see:
- **cards** as primary containers (rounded, low elevation)
- **pill**-like search fields and toggles
- **bottom sheets** for “add / schedule / reschedule” flows
- **compact popup menus** (e.g., payment status dropdown)
- consistent use of `mutedColor` for secondary labels and dividers

---

## 6) Feature guide (what each tab does)

### 6.1 Home (Dashboard)
The Home tab is a summary surface inside `DashboardPhoneFrame`.
It uses `SessionsCubit` to compute “today’s sessions” count and swaps between:
- a “free today” view when 0 sessions
- a middle card view when sessions exist

Key files:
- `lib/features/dashboard/ui/widgets/dashboard_phone_frame.dart`
- `lib/features/dashboard/ui/widgets/dashboard_top_card.dart`
- `lib/features/dashboard/ui/widgets/dashboard_middle_card.dart`
- `lib/features/dashboard/ui/widgets/dashboard_free_today_card.dart`

### 6.2 Calendar
Calendar supports two schedule types:

#### A) Class Schedule (Sessions)
- sessions are stored as `ScheduleSession`
- list excludes Cancelled sessions (derived status)
- sessions can be generated in batches from a frequency rule
- rescheduling checks for clashes

The “Add sessions” flow is a bottom sheet:
- pick client
- optionally pick a program template
- generate sessions via `ScheduleGenerator`
- detect clashes
- save via `SessionsCubit.addSessions`

Key files:
- `lib/features/calendar/ui/widgets/calendar_page_body.dart`
- `lib/features/calendar/ui/widgets/schedule_sessions_sheet.dart`
- `lib/features/calendar/domain/services/schedule_generator.dart`
- session local persistence: `lib/features/calendar/data/datasources/schedule_local_datasource.dart`

#### B) Payment Schedule (Client timeline payments)
- payment events live in a client’s `timeline` as type `payment`
- status is tracked via additional `statusChanged` events (per date and (preferably) per payment `refId`)

The calendar payment list supports:
- resetting status for a payment/date
- marking Paid
- marking Paid fully (bulk)
- “Will pay later” → reschedule

Key files:
- payment schedule list & sheets: `lib/features/calendar/ui/widgets/calendar_page_body.dart`
- payment actions/events: `lib/features/client/presentation/bloc/client_event.dart`

### 6.3 Clients
The Clients tab is the main CRUD surface.

Core flows:
- list + search
- add client (quick add sheet vs full registration screen)
- open a client profile for actions

Client Profile highlights:
- status picker (Active/Pending/Inactive)
- add note
- open payments
- view scheduled classes for this client (with restore/reschedule)

Key files:
- client list: `lib/features/client/presentation/pages/client_page.dart`
- registration: `lib/features/client/presentation/pages/client_registration_page.dart`
- profile: `lib/features/client/presentation/pages/client_profile_page.dart`
- personal details editing: `lib/features/client/presentation/pages/client_personal_details_page.dart`

Payments within a client:
- payments list shows scheduled payments and a summary (Paid/Upcoming/Pending)
- per-row popup allows Paid / Paid fully / Will pay later / Reset

Key file:
- `lib/features/client/presentation/pages/client_payments_page.dart`

### 6.4 Payments
The Payments tab is a “paid transactions view”, not the same as the calendar’s payment schedule.

Behavior:
- derives which payments are “Paid” by reading `statusChanged` events
- prefers `refId`-specific status changes (safe when multiple payments exist on same day)
- groups multiple payments on the same day into one row
- tapping a row opens per-client transaction history

Key files:
- `lib/features/payment/presentation/pages/payments_queue_page.dart`
- `lib/features/payment/presentation/pages/client_transactions_page.dart`

### 6.5 Settings
Settings is both a hub and the place to open hidden modules as standalone screens.

Sub-areas:
- Profile details
- Theme customization
- Module customization (tab order/visibility)
- Program management
- Notifications
- Logout

Key files:
- hub: `lib/features/settings/ui/settings_page_body.dart`

#### Profile
`ProfileDetailsScreen` edits:
- admin profile fields (saved via `DashboardCubit` → `AdminProfileStorage` → Firestore mirror)
- nationality/currency (saved via `SignupProfileStorage` → Firestore mirror)

Avatar editing:
- `ProfilePhotoScreen` allows picking an image + adjusting alignment/zoom.
- current implementation stores avatar bytes/alignment in `DashboardCubit` state (in-memory); it is not persisted in `AdminProfileStorage`.

Key files:
- `lib/features/settings/ui/profile/profile_details_screen.dart`
- `lib/features/settings/ui/profile/profile_photo_screen.dart`
- `lib/features/dashboard/bloc/dashboard_cubit.dart`
- `lib/core/storage/admin_profile_storage.dart`

#### Theme customization
Theme is driven by `AppThemeCubit` and persisted to `SharedPreferences` key `app_theme_v2`, mirrored to Firestore.

Key files:
- `lib/features/theme_customization/ui/theme_customization_screen.dart`
- `lib/features/theme_customization/bloc/app_theme_cubit.dart`

#### Program management
Program templates are CRUD’d in-app and saved to local storage, also mirrored to Firestore settings as `programCatalog`.

Key files:
- `lib/features/settings/ui/program_management_screen.dart`
- `lib/core/storage/program_catalog_storage.dart`

#### Notifications
Current implementation provides:
- in-app notification **records** (list + read/unread)
- notification **preferences** (toggles + timing fields)
- a local-notification wrapper service (`NotificationService`) that can show/schedule notifications on mobile

What is NOT currently present in code:
- a scheduler that turns “session/payment reminders prefs” into scheduled local reminders for sessions/payments.
- initialization wiring for `PushNotificationService` (FCM token registration + foreground-message handling). The service exists, but `PushNotificationService.instance.init()` is not called from startup in the current code.

Key files:
- local-notification wrapper: `lib/core/services/notification_service.dart`
- prefs + records: `lib/core/services/notification_cubit.dart`, `lib/core/services/notification_storage.dart`
- push tokens / foreground messages (not currently wired): `lib/core/services/push_notification_service.dart`

---

## 7) Key “status” concepts used across features

### Session status
Sessions have a stored status, but the UI often uses a derived status via `AppDateUtils.determineSessionStatus(...)`.
Notably, Cancelled sessions are excluded from many “upcoming/today” computations.

### Payment status
Payments are timeline events. Status is not stored on the payment event itself.
Instead, status is inferred from `statusChanged` timeline events, ideally with a `refId` that points to the payment event id.

---

## 8) Where to look when changing behavior

Common tasks:
- Add/change UI styling tokens → `AppChromeTheme` + `buildAppTheme`
- Change which tabs exist and how they render → `DashboardTab` + `DashboardPhoneFrame`
- Change scheduling rules/clash detection → `ScheduleGenerator`
- Change payment status logic → `ClientBloc` event handling + payment status derivation in calendar/payments pages
- Change sync behavior → `UserFirestoreSync`

