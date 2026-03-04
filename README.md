# gendral_app

This repo contains a modular, feature-first code organization scaffold intended for building UI from Figma designs.

## Folder layout (high-level)
- `src/app/`: app composition (navigation/routing, DI, global config)
- `src/core/`: cross-cutting utilities (networking, storage, errors, logging)
- `src/design_system/`: UI tokens + shared components (from Figma)
- `src/features/`: feature modules (each owns its UI + state + data)
- `docs/`: architecture and Figma handoff guidance

Start with: `docs/ARCHITECTURE.md` and `docs/figma/HANDOFF.md`.
