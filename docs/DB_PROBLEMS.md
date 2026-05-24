# Database Problems and Data-Flow Risks (Repo Evidence Only)

Date: 2026-05-24

## High impact
- None found after the Firebase-only refactor.

## Medium impact
- Firestore security posture is very open in dev window. Rules allow broad reads and writes during the dev window and allow unauthenticated reads of usernames, which can expose stored emails. Evidence: [firestore.rules](firestore.rules), [lib/features/auth/login/bloc/login_bloc.dart](lib/features/auth/login/bloc/login_bloc.dart).
- Username login relies on storing email in usernames documents. The schema doc recommends not storing PII there, but login resolves email from usernames. This creates a privacy and rules conflict. Evidence: [docs/FIRESTORE_SCHEMA.md](docs/FIRESTORE_SCHEMA.md), [lib/features/auth/login/bloc/login_bloc.dart](lib/features/auth/login/bloc/login_bloc.dart).

## Low impact / inconsistency
- None noted in current Firestore-only flow.

## Suggested next steps (if you want fixes later)
1. Decide the true source of truth (local vs Firestore) and implement one-direction or bidirectional sync accordingly.
2. Review Firestore settings schema and prune any unused fields.
3. Add Firestore delete propagation and a simple conflict policy.
4. Align Firestore database id usage with the configured Firebase project.
5. Tighten Firestore rules and remove unauthenticated access to PII.
