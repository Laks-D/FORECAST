# Firestore Schema (GeneralApp)

This project uses **Cloud Firestore** as the source of truth for all user data.

## Important: database id
This Firebase project currently has a Firestore database with **database id** `default` (not `(default)`).

- The app must use `FirebaseFirestore.instanceFor(..., databaseId: 'default')`.
- Firebase CLI `firebase deploy --only firestore:rules` targets `(default)` and will fail unless `(default)` exists.
  - Configure rules manually in Firebase Console for the `default` database, OR create `(default)` (may require billing).

## Top-level collections

### `users/{uid}` (user root)
**Document id:** Firebase Auth UID

**Purpose:** user profile + metadata

**Recommended fields** (what the app already writes / is expected to write):
- `createdAt`: server timestamp
- `lastLoginAt`: server timestamp
- `updatedAt`: server timestamp
- `platform`: `'web' | 'android' | 'ios' | 'windows' | ...`

**Profile fields** (only if you choose to store them):
- `displayName`: string
- `photoURL`: string
- `fullName`: string
- `profession`: string
- `userName`: string
- `userNameKey`: string

> Note: If you want “no personal details”, do not store email/phone/name here.

Subcollections under each user:

#### `users/{uid}/settings/app`
**Document id:** `app`

**Purpose:** everything that is “settings / customization” for the user.

Recommended structure:
- `theme`: object (persist `AppThemeState`)
- `navModules`: object
- `notificationPrefs`: object
- `signupProfile`: object (if needed)
- `adminProfile`: object (if needed)
- `updatedAt`: server timestamp

#### `users/{uid}/clients/{clientId}`
**Document id:** `client.id` (string)

**Purpose:** client registrations + client timeline (notes / payments / status changes)

Fields based on `Client.toJson()`:
- `id`: string
- `name`: string
- `middleName`: string? 
- `primaryContact`: string
- `countryCode`: string?
- `email`: string?
- `gender`: string?
- `dateOfBirth`: string? (ISO-8601)
- `address`: string?
- `timeline`: array of objects
- `updatedAt`: server timestamp

`timeline[]` items based on `ClientTimelineEvent.toJson()`:
- `id`: string
- `type`: `'profileCreated' | 'statusChanged' | 'payment' | 'note'`
- `createdAt`: string (ISO-8601)
- `amount`: number? (only for `payment`)
- `note`: string? (for `note` and optionally for `payment`)
- `status`: string? (only for `statusChanged`)

> Scaling note: storing all timeline events inside the client document is fine initially.
> If timelines grow large, move events to `users/{uid}/clients/{clientId}/timeline/{eventId}`.

#### `users/{uid}/sessions/{sessionId}`
**Document id:** `ScheduleSession.id` converted to string (current code uses `s.id.toString()`).

Fields based on `ScheduleSession.toJson()`:
- `id`: number
- `clientId`: string
- `status`: string
- `sessionNo`: number
- `time`: string
- `date`: string (`yyyy-MM-dd`)
- `rating`: number?
- `comments`: string?
- `read`: boolean
- `notifiedTwoHour`: boolean
- `notifiedFiveMin`: boolean
- `programType`: string? (enum name)
- `courseName`: string?
- `duration`: string? (enum name)
- `programEnrollmentId`: string?
- `updatedAt`: server timestamp

#### `users/{uid}/programs/{programId}`
**Document id:** recommended: slugged name or a generated id

Fields based on `RegisteredProgram.toJson()`:
- `name`: string
- `description`: string
- `frequency`: string
- `numberOfClasses`: number
- `classDuration`: string
- `customDays`: number
- `updatedAt`: server timestamp

#### `users/{uid}/notifications/{notificationId}` (optional)
If you want notification history per user (instead of local storage), store:
- `title`: string
- `body`: string
- `scheduledFor`: timestamp?
- `createdAt`: timestamp
- `read`: boolean

#### `users/{uid}/fcmTokens/{token}` (already in code)
- `token`: string
- `platform`: string
- `updatedAt`: server timestamp

## Support collections

### `usernames/{usernameKey}` (username → identity mapping)
**Purpose:** allow logging in with username.

Current app behavior expects to read this before sign-in.
Recommended fields:
- `uid`: string
- `username`: string
- `createdAt`: server timestamp

Avoid storing `email` here if you want “no personal details in Firestore”.
If you must map username → email, prefer a **Callable Function** that resolves it server-side.

## Suggested indexes (only if/when we query)
Firestore auto-indexes single fields. Composite indexes are only needed for compound queries.
Common ones you may want later:
- `users/{uid}/sessions` order by `date` + filter by `status`
- `users/{uid}/clients` filter by `status` + order by `updatedAt`

## Minimal security rules intent (high-level)
- Only the authenticated user can read/write: `users/{uid}/**` where `request.auth.uid == uid`.
- If keeping `usernames/{usernameKey}` readable before auth, do **not** store PII in it.
