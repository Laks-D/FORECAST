# Flutter structure (feature-first + BLoC)

## Recommended layout

- `lib/app/`
  - `router/` navigation setup
  - `di/` dependency injection / registrations
- `lib/core/`
  - `networking/`, `storage/`, `errors/` cross-cutting utilities
- `lib/design_system/`
  - `tokens/` exported values from Figma (colors, type, spacing)
  - `theme/` ThemeData built from tokens
  - `widgets/` shared UI widgets (Button, TextField, Card, etc.)
- `lib/features/`
  - `landing/`
    - `ui/` screen + feature-local widgets
    - `bloc/` BLoC files for this screen/flow

## Rules
- Features don’t import other features.
- Shared UI is in `design_system`.
- Keep a BLoC scoped to the smallest part of UI that needs it.

## Mapping Figma (iPhone 16 - 1)
- Frame → a route-level screen (e.g. `LandingScreen`)
- Each section group → a widget under `features/landing/ui/widgets/`
- Reused controls → `design_system/widgets/`
- Colors/type/spacing → `design_system/tokens/`
