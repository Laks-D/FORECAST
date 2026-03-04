# Component mapping template (fill from your Figma)

Use this table to decide what becomes a shared component vs feature-local.

## Shared components (Design System)

| Figma component | Code component | Props | Notes |
|---|---|---|---|
| Button / Primary | Button | variant, size, disabled, loading, icon | includes hover/focus states |
| Text field | TextField | label, value, onChange, error, helperText | supports leading/trailing icons |
| Card | Card | elevation, padding, onClick | |
| Section header | SectionHeader | title, subtitle, align | |

## Page sections (Feature-local)

| Figma frame/section | Code component | Ownership | Notes |
|---|---|---|---|
| Hero | HeroSection | features/<feature>/ui | composition only |
| Features grid | FeaturesSection | features/<feature>/ui | uses Card |
| Footer | Footer | design_system or feature | shared if reused |
