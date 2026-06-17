# Schema Migration — Status & Handoff

Branch: `feat/full-schema-migration` · Implements Phases 0–8 of `update_plan.docx`.

## What this is

Makes the app actually **read/write every collection** in `tables.docx`. Done
**additively**: new first-class collections are populated via dual-write while
the legacy shapes stay the source of truth for reads. Nothing was deleted, so
every change is reversible. Phase 9 (destructive cleanup / read cutover) is
**not** included — it is gated on tomorrow's Firebase wiring + a production soak.

> ⚠️ **Cannot be run-verified yet.** The collections don't exist until you
> create them + deploy `firestore.rules`. "Tested" here means logic + Firestore
> datasources against `fake_cloud_firestore` (45 unit tests). Real end-to-end
> verification happens after the tables + rules are live.

## Before you wire Firebase tomorrow

1. Create the collections (or let first writes create them — Firestore is
   schemaless).
2. **Deploy `firestore.rules` to the correct database id.** Per
   `docs/FIRESTORE_SCHEMA.md` the db id is `default` (not `(default)`). Wrong
   target ⇒ every read/write fails silently.
3. **#1 smoke test — rules are UNVERIFIED.** `fake_cloud_firestore` does not
   enforce `firestore.rules`, so the unit tests prove query *logic* but say
   nothing about access control. The ~6 new rule blocks have not been run.
   First thing to verify (emulator or live): **a student can read their own
   payment, and CANNOT read another student's.** The student-facing reads
   (`getForStudent(firebaseUid)`) are written to match the rule (filter by
   `firebaseUid`, never `clientId`) — but that pairing is unproven until rules
   actually run.

## Collections and how they get populated

| Collection | Path | How it's written now | Status |
|---|---|---|---|
| payments | `users/{tutorUid}/payments/{id}` | dual-write from `ClientLocalDataSource` (add / status / reschedule) | mirror; timeline[] still read source |
| client_events | `users/{tutorUid}/client_events/{id}` | dual-write from `addNote` / non-payment `addStatusChange` | mirror |
| programs | `users/{tutorUid}/programs/{slug}` | dual-write from `ProgramCatalogStorage.saveRegisteredPrograms` | mirror; settings array still read source |
| notifications | `users/{uid}/notifications/{id}` | dual-write from `NotificationStorage.saveRecords` | mirror |
| fcm_tokens | `users/{uid}/fcmTokens/{token}` | `FcmTokenService` on auth (new) | live write |
| usernames | `usernames/{key}` | claimed on signup (new, guarded) | live write |
| audit_log | `users/{actorUid}/audit_log/{id}` | `AuditService` on payment/client create+delete, login | live, append-only |
| enrollments | `users/{studentUid}/enrollment/{tutorId}` | enriched (`source`, `studentUid`) | live |
| sessions | `users/{tutorUid}/sessions/{id}` | enriched (`programId`, `recurrenceId`, `durationMins`) | live, backward-compatible |
| recurrence_rules | `users/{tutorUid}/recurrence_rules/{id}` | repository ready; generator not wired yet | infra only |

All new datasources take an injectable `FirebaseFirestore` + `targetUid`
callback (`core/app/target_uid_resolver.dart`) so they unit-test without
Firebase/Auth. Every repository ships a Firestore impl **and** an in-memory fake.

## Tests

`test/schema/` — 47 tests, all green (`flutter test test/schema/`):
payments, usernames, fcm_tokens, notifications, client_events, programs,
sessions+recurrence, enrollment payload, audit_log. Each covers model
round-trip, repository semantics, null-uid no-op, in-memory parity, and the
tutor- vs student-scoped query split.

> These prove query **logic** only. `fake_cloud_firestore` does not run
> `firestore.rules`, so access control is unverified (see Known limitations).

Legacy `test/widget_test.dart` (rotted Flutter template) replaced with a smoke
test; `test/profile_fullscreen_navigation_test.dart` skipped (needs a Firebase
test harness — pre-existing, unrelated).

## Rules added (`firestore.rules`)

`payments`, `client_events` (owner RW + enrolled-student scoped read by
`firebaseUid`); `programs`, `recurrence_rules` (tutor-only); `audit_log`
(owner create+read, no update/delete). `notifications`/`fcmTokens` already
covered by existing owner rules.

## Remaining work (Phase 9 + follow-ups — NOT done)

1. **Read cutover.** Switch UI/BLoC reads from `timeline[]` → `payments` +
   `client_events`, from settings arrays → `programs`/`notifications`. Behind a
   feature flag, after a soak. This is where the risk lives.
2. **Backfill.** One-time scripts to copy existing `timeline[]` payments/notes,
   `programCatalog[]`, and `notificationRecords[]` into the new collections.
3. **Recurrence generator.** Wire `schedule_generator` to write a
   `recurrence_rules` doc + stamp `recurrenceId` on generated sessions.
4. **Username-login UI.** `usernames` is populated + `resolveUid` exists, but
   login is still email-only (no username field in the signup/login UI, and no
   email is stored in `usernames` by design — PII). Add UI if username login is
   wanted.
5. **FCM remote push.** Tokens are now collected; a sender (Cloud Function /
   server) is still needed to actually push. App remains local-notification-first.
6. **Phase 9 cleanup.** Remove dual-write branches + legacy array code, trim
   `Client.timeline[]`, prune dead rules (`scheduledNotifications`), update docs.
   Only after 1–5 are stable in prod.

## Known limitations (read before cutover)

- **Rules unverified** (see "Before you wire", #1). Highest-priority gap.
- **Student query path correctness depends on rules.** Tutor reads filter by
  `clientId`; student reads MUST filter by `firebaseUid` (`getForStudent`).
  Firestore evaluates list-query rules against the query constraints, so a
  student querying by `clientId` would be denied. The repos now expose the
  right method, but it is only logic-tested, not rules-tested.
- **Orphan payment docs.** `_mirrorPaymentStatus` does `set(merge:true)`; if a
  status change references a payment created *before* the migration (no payment
  doc yet), it creates a partial doc with only `status`+`updatedAt`. Harmless
  (mirror only) and resolved by the timeline→payments backfill.

## markPaidFully / revertPaidFully

These aggregate-payment operations are intentionally **not** mirrored to the
`payments` collection (they would double-count against the per-payment docs).
The legacy timeline handles them correctly; the full read cutover (item 1) will
re-express them as real payment-status transitions.
