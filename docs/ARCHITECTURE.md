# Architecture & modularization (general)

This project is organized **feature-first** with a small **core** layer and a shared **design system**.

## Layers

### `src/app/` (composition)
Owns app-wide wiring only:
- Navigation/routing setup
- Dependency injection/service registration
- App bootstrap, environment/config selection

Rule: `app/` should not contain business rules; it should compose features.

### `src/features/` (vertical slices)
Each feature owns everything needed to deliver a user-facing capability (screen/flow).

A feature can contain:
- `ui/`: screens, feature-specific widgets
- `state/`: view model / controller / state machine
- `domain/`: use-cases, entities (optional for simple features)
- `data/`: repositories, API adapters (optional if shared in core)

Rule: features should not import from other features (use shared `core/` or `design_system/`).

### `src/design_system/` (shared UI)
- `tokens/`: colors, typography, spacing, radii, shadows
- `theme/`: light/dark themes, mapping tokens to runtime theme
- `components/`: shared UI components (Button, TextField, Card, etc.)

Rule: design system components are **presentational**; they should not depend on features.

### `src/core/` (cross-cutting)
- `networking/`: HTTP client, interceptors, retry
- `storage/`: local persistence abstractions
- `errors/`: typed errors + mapping
- `utils/`, `logging/`

Rule: core is framework-agnostic where possible.

## Dependency rules (simple)
- `app` -> `features`, `design_system`, `core`
- `features` -> `design_system`, `core`
- `design_system` -> `core` (optional), but never `features`
- `core` -> nothing else in `src/`

If you enforce this with tooling later (ESLint boundaries, Dart imports lint, etc.), keep it strict.
