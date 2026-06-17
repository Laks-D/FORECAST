# COMPREHENSIVE APPLICATION REPORT — "S-Now" (Generic App)

---

## 1. PROJECT OVERVIEW

| Attribute | Value |
|---|---|
| **App Name** | S-Now (code-named "snow") |
| **Display Names** | "S-Now" (Android), "Gendral App" (iOS) |
| **Package/ID** | com.snow.app (Android), com.snow.app (iOS bundle ID) |
| **Version** | 1.0.0+1 |
| **Type** | Two-sided tutoring management platform |
| **Primary Users** | Tutors (admin) and Students (clients) |
| **Entry Points** | lib/main.dart (tutor), lib/main_client.dart (student, forced client mode) |
| **Target Platforms** | Android, iOS, Web, Windows |
| **Firebase Projects** | snow-appifybiz (default), genericapp-dev (dev), genericapp-prod (prod) |

### What the App Does

A two-sided platform connecting tutors with students:

- **Tutors**: Manage student roster, schedule sessions/classes, track payments, generate QR invite codes, customize dashboard and theme
- **Students**: Join tutors via QR code, view scheduled sessions, view payment history, edit profile
- **Dual-role**: A user can be both tutor and student simultaneously, switching by signing in via the respective tab

---

## 2. TECHNOLOGY STACK

| Layer | Technology | Version |
|---|---|---|
| **Framework** | Flutter | SDK >=3.3.0 <4.0.0 |
| **Language** | Dart | 3.x |
| **State Management** | flutter_bloc + bloc | 8.1.6 / 8.1.4 |
| **DI** | get_it | 7.6.0 |
| **Backend** | Firebase (Auth, Firestore, Messaging, Hosting) | Various |
| **Auth** | Firebase Auth (email/password + Google Sign-In) | firebase_auth 6.3.0 |
| **Database** | Cloud Firestore | cloud_firestore 6.2.0 |
| **Push Notifications** | Firebase Cloud Messaging + flutter_local_notifications | 16.1.3 / 20.1.0 |
| **QR** | qr_flutter + mobile_scanner | 4.0.0 / 7.2.0 |
| **Deep Links** | app_links | 6.4.0 |
| **Theme/Fonts** | google_fonts, flex_color_picker | 6.2.1 / 3.7.0 |
| **Image** | image_picker | 1.1.2 |
| **Local Storage** | shared_preferences | 2.2.3 |
| **Share** | share_plus | 7.2.1 |
| **Android** | AGP 8.9.1, Kotlin 2.1.0, Firebase BOM 33.8.0, GMS 4.3.15 | Min SDK = flutter default |
| **iOS** | Standard Flutter Podfile, multiple GoogleService-Info.plist | iOS 13.0+ |
| **Web** | Firebase Hosting, PWA manifest, service worker | — |
### Key Dependencies

| Package | Version | Purpose |
|---|---|---|
| bloc | ^8.1.4 | State management foundation |
| flutter_bloc | ^8.1.6 | Flutter BLoC integration |
| equatable | ^2.0.5 | Value equality for state objects |
| get_it | ^7.6.0 | Dependency injection |
| google_fonts | ^6.2.1 | Custom fonts (Inter, Orbitron) |
| flex_color_picker | ^3.7.0 | Theme color picker UI |
| shared_preferences | ^2.2.3 | Local key-value storage |
| image_picker | ^1.1.2 | Camera/gallery access |
| flutter_local_notifications | ^20.1.0 | Local notification scheduling |
| timezone | ^0.10.1 | Timezone database |
| flutter_timezone | ^5.0.0 | Device timezone detection |
| firebase_core | ^4.6.0 | Firebase core |
| firebase_auth | ^6.3.0 | Authentication |
| cloud_firestore | ^6.2.0 | Cloud Firestore database |
| firebase_messaging | ^16.1.3 | Push notifications |
| google_sign_in | ^7.2.0 | Google authentication |
| flutter_slidable | ^3.1.2 | Swipe-to-dismiss actions |
| share_plus | ^7.2.1 | Share sheet integration |
| qr_flutter | ^4.0.0 | QR code generation |
| mobile_scanner | 7.2.0 | QR code scanning |
| app_links | ^6.4.0 | Deep linking |


---

## 3. APPLICATION ARCHITECTURE

### Directory Structure (lib/)

```
---
## 3. APPLICATION ARCHITECTURE
### Directory Structure (lib/)
---
## 3. APPLICATION ARCHITECTURE

### Directory Structure (lib/)

`
lib/
+-- main.dart                          # Tutor entry point
+-- main_client.dart                   # Student entry point (forced client mode)
+-- firebase_options.dart              # Firebase per-platform config
+-- core/
|   +-- app/                           # App mode, role management, enrollment resolver
|   +-- auth/                          # Google auth, login/signup controllers, username key
|   +-- dev/                           # Dev bootstrap (skip-auth for testing)
|   +-- di/                            # Service locator (GetIt)
|   +-- firebase/                      # Firestore instance accessor
|   +-- platform/                      # Web online status detection
|   +-- profile/                       # User profile cubit (currency)
|   +-- services/                      # Notifications, deep links, Firestore sync
|   +-- storage/                       # Admin profile, signup profile, program catalog
|   +-- utils/                         # Date utilities
+-- design_system/
|   +-- theme/                         # AppChromeTheme, buildAppTheme, AppVisualStyle
|   +-- tokens/                        # Spacing, radii, example tokens
|   +-- widgets/                       # Card, EmptyState, Loading, Neumorphic buttons
+-- features/
|   +-- audit/                         # Append-only audit logging
|   +-- auth/                          # Signup, login, role selection, password reset
|   +-- calendar/                      # Session scheduling, calendar UI, recurrence
|   +-- client/                        # Client CRUD, profiles, events, QR invite
|   +-- course/                        # Program management, course profile
|   +-- dashboard/                     # Home screen, widgets, bottom nav
|   +-- join_request/                  # QR join flow, real-time request handling
|   +-- landing/                       # App entry router (auth state routing)
|   +-- navigation/                    # Customizable bottom nav tabs
|   +-- notifications/                 # In-app notification history & settings
|   +-- payment/                       # Payment tracking, invoices, transactions
|   +-- settings/                      # Profile, theme, programs, deleted clients
|   +-- theme_customization/           # Theme editor (colors, fonts, mode)
|   +-- widget_customization/          # Widget style preferences
+-- utils/
|   +-- app_links.dart                 # OnboardingLink generation & parsing
+-- widgets/
    +-- simple_qr_painter.dart         # QR code rendering widget
`
### Architecture Pattern

**Feature-first architecture** with a shared core layer and design system:

`
app/ (composition layer)
  |
  v
features/ (vertical slices - each owns UI, BLoC, domain, data)
  |                 |
  v                 v
design_system/   core/ (cross-cutting: DI, Firebase, auth, services, storage)
`

**Rules:**
- Features don't import other features (shared code in core/ or design_system/)
- Design system widgets are presentational, no business logic
- Core is framework-agnostic where possible

### src/ Directory (Architectural Blueprint)

The src/ directory serves as a structural reference / architectural guide - not executable code. It mirrors lib/ in structure and provides READMEs explaining the intended layer responsibilities.

---

## 4. CORE LAYER (lib/core/)

### 4.1 app/ - Application Mode & Role (9 files)

**AppMode & AppRole Enums:**
- AppMode: admin (tutor), client (student)
- AppRole: tutor, client
- AppModeConfig: Static process-wide config with mode, isClient, isAdmin, oppositeMode, isDualRole

**Cubits:**
- AppModeCubit: Manages current app mode, persists via AppModeStorage
- AppRoleCubit: Manages user role

**Key Resolvers:**
- StudentEnrollmentResolver: Resolves which tutor a student reads. Has in-memory cache, uses collection group queries for orphan matching
- TargetUidProvider: Typedef callback resolving current target UID (own for tutor, enrolled tutor for student)
- AppModeScope: InheritedWidget propagating current mode down widget tree

**Widgets:**
- AppModeSelector: Toggle pill for dual-role users

### 4.2 auth/ - Authentication Utilities (4 files)

| File | Key Export | Description |
|---|---|---|
| google_auth.dart | GoogleAuth.signIn() | Shared Google sign-in helper |
| login_controller.dart | LoginController | Records last used login tab for dual-role routing |
| signup_controller.dart | SignupController | Prevents race condition between authStateChanges and role write |
| username_key.dart | usernameKeyFromInput() | Sanitizes username to safe Firestore doc ID |

### 4.3 dev/ - Development Bootstrap (1 file)

DevBootstrap: Enables skip-login when SKIP_AUTH=true. Signs in anonymously, seeds dev user.

### 4.4 di/ - Dependency Injection (1 file)

service_locator.dart: GetIt instance registering all major repositories, BLoCs, and data sources.

### 4.5 firebase/ - Firebase Config (1 file)

firestoreDb: Getter returning FirebaseFirestore.instance

### 4.6 platform/ - Platform Abstractions (3 files)

- web_online_status.dart: Conditional export for browser online status
- web_online_status_stub.dart: Returns null (non-web)
- web_online_status_web.dart: Returns window.navigator.onLine

### 4.7 profile/ - User Profile (1 file)

UserProfileCubit: Loads user profile data (currency) from SignupProfileStorage. Default currency is INR.

### 4.8 services/ - Business Services (6 files)

**DeepLinkService:** Listens for Android App Links / iOS Universal Links via app_links package. Navigates to InviteLandingPage when app opened via invite URL.

**NotificationService:** Local notification scheduling using flutter_local_notifications. Timezone-aware, supports exact alarms for session/payment reminders.

**NotificationCubit:** Manages in-app notification preferences and records. Controls session/payment reminders, tracks read/unread state.

**NotificationOrchestrator:** Wires SessionsCubit + ClientBloc into NotificationService with debouncing.

**NotificationStorage:** AppNotification model and persistence for preferences, records, dismissed IDs.

**UserFirestoreSync:** Singleton for Firestore-backed user data access. Manages users/{uid} document and settings sub-collection with debounced writes.

### 4.9 storage/ - Data Storage Models (3 files)

| File | Model | Purpose |
|---|---|---|
| signup_profile_storage.dart | SignupProfileData | Full name, profession, username, email, nationality, currency |
| program_catalog_storage.dart | RegisteredProgram | Name, description, frequency, duration, classes |
| admin_profile_storage.dart | - (static methods) | Name, handle, email, phone, gender, DOB |

### 4.10 utils/ - Utilities (1 file)

AppDateUtils: Comprehensive date/time parsing and formatting including parseTimeLabel(), formatTimeLabelFromMinutes(), determineSessionStatus().

---

## 5. FEATURES LAYER (lib/features/)

### 5.1 AUDIT (3 files)

**Purpose:** Append-only audit logging for compliance

- AuditEntry: Immutable record with logId, actorUid, action, entity, entityId, before/after snapshots
- FirestoreAuditLogRepository: Stores at users/{actorUid}/audit_log/{logId}
- AuditService: Singleton, fire-and-forget logging, never throws

### 5.2 AUTH (9 files)

| File | Purpose |
|---|---|
| ui/auth_gate.dart | Container for unauthenticated flow |
| ui/new_login_screen.dart (~489 lines) | Login for specific role |
| ui/new_signup_screen.dart (~672 lines) | Signup for specific role |
| ui/role_selection_screen.dart (~454 lines) | Entry screen with Sign In / Sign Up tabs |
| repository/auth_repository.dart (~453 lines) | All Firebase Auth + Firestore auth calls |
| data/username_repository.dart | Maps username to UID via usernames collection |
| profile_completion/ui/complete_profile_screen.dart (~238 lines) | Post-auth profile completion |
| forgot_password/ui/forgot_password_screen.dart (~178 lines) | Email-based password reset |

### 5.3 CALENDAR (12 files) - Largest Feature

**Domain Entities:** ScheduleSession, SessionDuration enum, RecurrenceRule

**Repositories:** ScheduleRepository (abstract), ScheduleRepositoryImpl, ScheduleLocalDataSource (~444 lines, in-memory + Firestore sync), FirestoreRecurrenceRuleRepository

**Services:** ScheduleGenerator (~129 lines) - generates sessions from recurrence rules

**BLoCs:**
- CalendarCubit: Selected date, view mode (weekly/monthly), navigation
- SessionsCubit: Full CRUD + recurrence management

**UI:**
- CalendarPageBody (~3548 lines - **largest file in project**): Main calendar with weekly/monthly views
- ScheduleSessionsSheet (~1079 lines): Bottom sheet for scheduling sessions

### 5.4 CLIENT (18 files) - Most Files

**Entities:** Client, ClientEvent

**Repositories:** FirestoreClientRepository, FirestoreClientEventRepository

**BLoC:** ClientBloc (~327 lines) with events: Load, Search, AddNote, AddPayment, Update, Delete, Restore, Pin, Unpin

**Pages:**
- ClientPage (~913 lines): Client list with search, Slidable actions
- ClientProfilePage (~2225 lines): Full profile with timeline, payments, sessions
- ClientRegistrationPage (~350 lines): Detailed registration form
- MyProfilePage (~245 lines): Current user client profile
- ClientPersonalDetailsPage (~465 lines): Editable details

**Invite/QR:**
- ScanInvitePage (~218 lines): Student QR scanner
- InviteQrPage (~115 lines): Tutor QR code display
- InviteLandingPage (~261 lines): Post-scan landing, 15-min QR validation

### 5.5 COURSE (4 files)

Program entity, FirestoreProgramRepository, CoursesPage (~613 lines), CourseProfilePage (~316 lines)

### 5.6 DASHBOARD (10 files)

**BLoC:** DashboardCubit - tab selection, avatar bytes, user info, class counters

**Widgets:**
- DashboardScreen (~90 lines): Main shell
- DashboardBottomNav (~158 lines): Customizable bottom nav
- DashboardTopCard (~313 lines): Greeting, meter, notification bell
- DashboardMiddleCard (~788 lines): Today's sessions
- DashboardMeter (~178 lines): Circular progress meter
- DashboardFreeTodayCard (~107 lines): Empty state
- DashboardProgressRing (~139 lines): Single progress ring
- DashboardPhoneFrame (~165 lines): Phone-shaped frame

### 5.7 JOIN_REQUEST (6 files)

JoinRequestModel, JoinRequestService (QR validation, accept/reject with enrollment), buildEnrollmentPayload(), JoinRequestListenerCubit, JoinRequestWaitingPage (~448 lines), JoinRequestBanner (~359 lines)

### 5.8 LANDING (2 files)

LandingScreen (~264 lines): Top-level entry routing based on auth state

### 5.9 NAVIGATION (3 files)

NavModulesCubit: Tab order/visibility, persists to Firestore. ModuleCustomizationScreen (~186 lines): ReorderableListView + switches

### 5.10 NOTIFICATIONS (5 files)

NotificationsPage, NotificationSettingsPage, FcmTokenRepository, FcmTokenService, NotificationRecordRepository

### 5.11 PAYMENT (10 files)

**Entities:** Payment (with PaymentStatus enum), Invoice/InvoiceItem

**Repositories:** FirestorePaymentRepository, InMemoryPaymentRepository (tests), FirestoreInvoiceRepository

**Pages:** PaymentsPage, PaymentsQueuePage (~710 lines), ClientTransactionsPage (~400 lines)

### 5.12 SETTINGS (8 files)

SettingsPageBody (~1034 lines), DeletedClientsScreen, AddProgramScreen (~563 lines), ProgramManagementScreen (~868 lines), ProfileDetailsScreen (~583 lines), ClientProfileDetailsScreen (~583 lines), ProfilePhotoScreen (~241 lines)

### 5.13 THEME_CUSTOMIZATION (3 files)

AppThemeCubit - full theme state (colors, fonts, mode). ThemeCustomizationScreen (~1114 lines) with flex_color_picker.

### 5.14 WIDGET_CUSTOMIZATION (3 files)

WidgetCustomizationCubit - calendar selection style, meter style/colors

---

## 6. DESIGN SYSTEM

### 6.1 Theme
- AppChromeTheme: Custom ThemeExtension with frameColor, accentBlue, surfaceColor, textColor, mutedColor
- AppVisualStyle: Neumorphism flag + neumorphicShadows() helper
- ThemeCubit: Light/dark toggle
- buildAppTheme(): Builds full ThemeData with Google Fonts (Inter/Orbitron), Material 3, neumorphism support

### 6.2 Tokens
- AppRadii: sm=12, md=18, lg=28, pill=999
- AppSpacing: xxs=4, xs=8, sm=12, md=16, lg=20, xl=24, xxl=32

### 6.3 Widgets
AppCard, AppEmptyState, AppLoading, AppNeumorphicIconButton, AppNeumorphicPillButton, AppNeumorphicFieldContainer, AppSearchField

### 6.4 Shared Widgets
SimpleQr: QR code renderer using qr Dart package with CustomPainter

---

## 7. UTILITIES

### app_links.dart - OnboardingLink

| Method | Description |
|---|---|
| generateLink(tutorId, ts) | Generates invite URL |
| parse(input) | Extracts (tutorId, timestamp) from URL, query string, or bare ID |
| parseTutorId(url) | Convenience wrapper |
| parseTimestamp(url) | Convenience wrapper |

---

## 8. DATABASE - FIRESTORE SCHEMA

### 8.1 Collections Overview

Firestore Database ID: default (not (default))

Top-level collections:
- users/{uid} - User root document + subcollections
- join_requests/{id} - Invite join requests
- usernames/{key} - Username to UID lookup

### 8.2 User Subcollections

| Subcollection | Path | Purpose |
|---|---|---|
| settings | users/{uid}/settings/app | All user preferences (theme, nav, notifications, profile, programs) |
| sessions | users/{uid}/sessions/{id} | Scheduled classes |
| deleted_sessions | users/{uid}/deleted_sessions/{id} | Soft-deleted sessions |
| clients | users/{uid}/clients/{id} | Student roster |
| deleted_clients | users/{uid}/deleted_clients/{id} | Soft-deleted clients |
| payments | users/{uid}/payments/{id} | Payment records |
| client_events | users/{uid}/client_events/{id} | Notes/status changes |
| programs | users/{uid}/programs/{id} | Course templates |
| recurrence_rules | users/{uid}/recurrence_rules/{id} | Recurring session definitions |
| enrollment | users/{studentUid}/enrollment/{tutorId} | Student enrolled tutors |
| audit_log | users/{actorUid}/audit_log/{id} | Append-only action log |
| fcmTokens | users/{uid}/fcmTokens/{token} | FCM device tokens |
| notifications | users/{uid}/notifications/{id} | Notification history |
| invoices | users/{tutorUid}/invoices/{id} | Invoice records |

### 8.3 Security Rules (207 lines)

Key rules:
- users/{uid}: Read any signed-in, Write owner only
- sessions/clients/payments/client_events: Owner RW, enrolled student read (self only via firebaseUid)
- programs/recurrence_rules: Tutor-only
- audit_log: Owner create+read only
- join_requests: Create student (self), Read involved parties, Update tutor (accept/reject) or student (expire)
- usernames: Get public, Create auth-only + unique + no PII

---

## 9. STATE MANAGEMENT

| BLoC/Cubit | Type | Key Responsibility |
|---|---|---|
| AppModeCubit | Cubit | Tutor/student mode toggle |
| AppRoleCubit | Cubit | User role management |
| UserProfileCubit | Cubit | Profile currency |
| NotificationCubit | Cubit | Notification prefs + records |
| ThemeCubit | Cubit | Light/dark toggle |
| AppThemeCubit | Cubit | Full theme customization |
| DashboardCubit | Cubit | Dashboard state, profile, tabs |
| NavModulesCubit | Cubit | Nav tab order/visibility |
| WidgetCustomizationCubit | Cubit | Widget style prefs |
| CalendarCubit | Cubit | Calendar date/view |
| SessionsCubit | Cubit | Sessions CRUD + recurrence |
| JoinRequestListenerCubit | Cubit | Real-time join requests |
| ClientBloc | Bloc (event-driven) | Clients CRUD |

---

## 10. DEPENDENCY INJECTION (GetIt)

All major services registered as singletons or factories in service_locator.dart.

---

## 11. AUTHENTICATION FLOW

### Signup Flow
1. Role selection on RoleSelectionScreen
2. Enter email + password on NewSignupScreen
3. Firebase Auth creates account
4. Firestore user doc created with roles array
5. SignupController sets pending state
6. User signed out, redirected to login

### Login Flow
1. Role selection determines login tab
2. Email + password or Google Sign-In
3. Role validation, FCM token registration
4. LandingScreen routes to DashboardScreen

### Dual-Role Switching
Sign out and sign in via the other role tab.

---

## 12. NOTIFICATIONS SYSTEM

### Local Notifications
- NotificationService via flutter_local_notifications
- Android notification channels, timezone-aware
- Session reminders, payment reminders, overdue alerts

### Push Notifications (FCM)
- FcmTokenService registers tokens on auth
- Web service worker handles background messages
- Remote push sender not yet implemented

### In-App
- NotificationCubit manages read/unread
- NotificationsPage: History view
- NotificationSettingsPage: Per-category toggles

---

## 13. PLATFORM CONFIGURATION

### Android (AGP 8.9.1, Kotlin 2.1.0)
- App ID: com.snow.app (dev: .dev suffix)
- Permissions: CAMERA, POST_NOTIFICATIONS, RECEIVE_BOOT_COMPLETED, SCHEDULE_EXACT_ALARM
- Deep Links: genericapp-prod.web.app/join
- Flavors: dev/prod

### iOS
- Deployment target: 13.0+
- Permissions: Camera, Photo Library
- Separate GoogleService-Info files for dev/prod

### Web
- PWA with manifest.json and icons
- FCM service worker
- Firebase Hosting with custom invite landing page

---

## 14. WEB HOSTING & DEEP LINKS

### Firebase Hosting
- Rewrites: /join to /join/index.html
- Custom 404 page
- Android App Links verification (.well-known/assetlinks.json)

### Deep Link Service
- Uses app_links package
- Handles cold-start and warm-start links
- Routes to InviteLandingPage with tutorId + timestamp

### OnboardingLink Utility
- Generate: https://genericapp-prod.web.app/join?tutorId=X&ts=Y
- Parse: Robust handling of URLs, query strings, bare IDs

---

## 15. TESTS

### Schema Tests (test/schema/) - 8 files, 47+ tests

All use fake_cloud_firestore for mocking:

| Test File | Coverage |
|---|---|
| payment_repository_test.dart | Model serialization, CRUD, student scoped, streaming |
| client_event_repository_test.dart | Model, CRUD, chronological sort, student scoped |
| sessions_recurrence_test.dart | Session enrichment, legacy JSON, recurrence CRUD |
| auth_lookup_repository_test.dart | Username registration, FCM token CRUD |
| program_repository_test.dart | Slug generation, CRUD, replaceAll |
| notification_record_repository_test.dart | Upsert, markRead, delete, idempotent |
| audit_log_repository_test.dart | Append, getRecent, null-uid no-op |
| enrollment_payload_test.dart | Payload fields, backward compatibility |
| onboarding_link_test.dart | URL parsing, round-trip, edge cases |

### Other Tests
- widget_test.dart: Smoke test only
- profile_fullscreen_navigation_test.dart: SKIPPED (needs Firebase harness)

---

## 16. KNOWN ISSUES & LIMITATIONS

### Active Bugs
1. Join-request accept writes clientName as tutorName in enrollment
2. Client records created in UI after accept, not in transaction
3. Session IDs from local timestamps - collision risk
4. Join-request timeout doesn't update status
5. Client list not live-synced
6. Notification prefs stored but no scheduler
7. Role selection vs auto-routing confusing for dual-role

### Database Issues
1. Username collection stores email (PII)
2. Dev Firestore rules are open

### Schema Migration (Phase 9 NOT DONE)
1. Read cutover from legacy timeline not complete
2. Backfill scripts not run
3. Recurrence generator not wired
4. Username-login UI not implemented
5. FCM remote push sender missing
6. Rules unverified (tested with fake only)

### Code Quality
- Largest file: CalendarPageBody at ~3,548 lines
- 28 Python fix scripts in project root
- API keys hardcoded in firebase_options.dart

---

## 17. DEVELOPMENT SCRIPTS

### dev_env.ps1
Sets up PATH for portable Node/NPM, FlutterFire tools.

### run_chrome.ps1
Runs Flutter web in Chrome with TEMP/PUB_CACHE redirection.

---

## 18. FIX SCRIPTS

28 Python scripts in project root for one-off fixes (bloc, calendar, profile, sessions, etc.)

---

## 19. FILE SIZE SUMMARY

| Largest Files | Lines | Location |
|---|---|---|
| calendar_page_body.dart | ~3,548 | features/calendar/ui/widgets/ |
| client_profile_page.dart | ~2,225 | features/client/presentation/pages/ |
| theme_customization_screen.dart | ~1,114 | features/theme_customization/ui/ |
| schedule_sessions_sheet.dart | ~1,079 | features/calendar/ui/widgets/ |
| settings_page_body.dart | ~1,034 | features/settings/ui/ |

**Total lib/: ~130 files**

---

## 20. DOCUMENTATION

| File | Lines | Content |
|---|---|---|
| APP_FLOW_AUDIT.md | 20 | Fixed issues + remaining bugs |
| APP_HANDBOOK.md | 283 | Code-grounded guide to app features |
| ARCHITECTURE.md | 47 | Architectural blueprint |
| DB_PROBLEMS.md | 20 | Database risks |
| FIREBASE_SETUP.md | 172 | Firebase project setup |
| FIRESTORE_SCHEMA.md | 150 | Firestore schema docs |
| PROJECT_ANALYSIS.md | 59 | Project analysis |
| SCHEMA_MIGRATION.md | 112 | Migration status |
| figma/ | ~81 total | Figma handoff guides |
| flutter/ | ~71 total | BLoC rendering + structure guides |

---
