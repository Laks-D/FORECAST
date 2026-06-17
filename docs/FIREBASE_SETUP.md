## Step 6 — Running the App

```bash
# Dev — runs against genericapp-dev Firebase
flutter run --flavor dev --dart-define=FLAVOR=dev

# Prod — runs against genericapp-prod Firebase
flutter run --flavor prod --dart-define=FLAVOR=prod

# Build APK
flutter build apk --flavor dev  --dart-define=FLAVOR=dev
flutter build apk --flavor prod --dart-define=FLAVOR=prod

# Build IPA
flutter build ipa --flavor dev  --dart-define=FLAVOR=dev
flutter build ipa --flavor prod --dart-define=FLAVOR=prod
```

## Overview

Two completely separate Firebase projects, each with its own Gmail account:

| Environment | Firebase Project ID | Gmail |
|-------------|-------------------|-------|
| **Dev** | `generic-app-dev-XXXX` | your-dev@gmail.com |
| **Prod** | `generic-app-prod-XXXX` | your-prod@gmail.com |

---

## Step 1 — Create Firebase Projects

### Dev Project
1. Open [https://console.firebase.google.com](https://console.firebase.google.com)
2. Sign in with **dev Gmail**
3. Click **Add project** → name it e.g. `GenericApp Dev`
4. Disable Google Analytics (or enable — your choice)
5. Note the **Project ID** shown (e.g. `genericapp-dev-abc12`)

### Prod Project
1. **Sign out**, sign in with **prod Gmail**
2. Click **Add project** → name it e.g. `GenericApp Prod`
3. Note the **Project ID** (e.g. `genericapp-prod-abc12`)

---

## Step 2 — Enable Firebase Services (both projects)

In each project's Firebase Console:

### Authentication
- Go to **Authentication → Sign-in method**
- Enable: **Email/Password** ✅
- Enable: **Google** ✅ (set support email)

### Firestore
- Go to **Firestore Database → Create database**
- Choose **Start in test mode** (we'll lock rules later)
- Region: `asia-south1` (Mumbai) — closest to India
- Database ID: leave as `(default)` — **important**: update `firestore_db.dart` to use `(default)` OR create a named one called `default`

### Cloud Messaging (for push notifications)
- Already enabled when you create the project

---

## Step 3 — Register Apps in Firebase

### Android (both projects)
- Package name: `com.yourcompany.genericapp.dev` (dev) / `com.yourcompany.genericapp` (prod)
- Download `google-services.json` → place in `android/app/`

### iOS (both projects)
- Bundle ID: `com.yourcompany.genericapp.dev` (dev) / `com.yourcompany.genericapp` (prod)
- Download `GoogleService-Info.plist` → place in `ios/Runner/`

---

## Step 4 — Install FlutterFire CLI

```bash
dart pub global activate flutterfire_cli
```

---

## Step 5 — Generate firebase_options.dart

### For DEV (run this when developing):
```bash
cd /Users/rohiththayalan/development/generic_app

flutterfire configure \
  --project=genericapp-dev-XXXX \
  --out=lib/firebase_options.dart \
  --platforms=android,ios,web
```

### For PROD (run before production build):
```bash
flutterfire configure \
  --project=genericapp-prod-XXXX \
  --out=lib/firebase_options.dart \
  --platforms=android,ios,web
```

> ⚠️ `lib/firebase_options.dart` is gitignored — never commit it with real keys.

---

## Step 6 — Running the App

```bash
# Dev (default)
flutter run

# Prod
flutter run --dart-define=FLAVOR=prod
```

---

## Step 7 — Firestore Security Rules

Once you're done testing, replace the default rules in both projects:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // Users can only read/write their own profile
    match /users/{uid} {
      allow read, write: if request.auth != null && request.auth.uid == uid;
    }

    // Username lookup (read-only for auth)
    match /usernames/{key} {
      allow read: if request.auth != null;
      allow write: if false; // managed server-side only
    }

    // Organisations — owner can read/write
    match /organizations/{orgId} {
      allow read, write: if request.auth != null &&
        resource.data.ownerId == request.auth.uid;

      // Students subcollection — owner can write, student can read their own
      match /students/{studentId} {
        allow read, write: if request.auth != null;
      }
    }
  }
}
```

---

## Firestore Database ID Note

The codebase uses `firestore_db.dart` which explicitly sets `databaseId: 'default'`.

- If you create your Firestore DB with the **default name** `(default)`, change this to:
  ```dart
  FirebaseFirestore.instance  // uses (default) automatically
  ```
- If you create a **named database** called `default`, keep the current code as-is.

**Recommendation**: Create the Firestore DB with the default name and update `firestore_db.dart`:

```dart
FirebaseFirestore get firestoreDb => FirebaseFirestore.instance;
```
