# Feature template

Create a new folder under `src/features/<feature_name>/`.

Suggested structure:

- `ui/`
  - `screens/` (route-level screens)
  - `components/` (feature-local UI pieces)
- `state/`
  - view model / controller / reducer
- `domain/` (optional)
  - entities, use-cases
- `data/` (optional)
  - repository implementations, DTO mapping

Guidelines:
- Feature UI can use `design_system` components.
- Feature should not import other `features/*`.
- Keep feature APIs small: expose only the entry screen or route config.
