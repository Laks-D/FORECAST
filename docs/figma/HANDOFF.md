# Figma → code handoff checklist

## What to share (so I can build an accurate module/component map)

1. **Frame screenshots**
   - Desktop (e.g., 1440px) + Mobile (e.g., 375px)
   - Include hover/active states if present

2. **Component inventory** (from Figma)
   - Buttons, inputs, cards, nav/header, modals, etc.
   - Variants: size, hierarchy, state (default/hover/disabled/loading)

3. **Tokens**
   - Colors (semantic names if you have them)
   - Typography scale (font family, sizes, weights, line heights)
   - Spacing scale (4/8/12/16…)
   - Radius/shadow scale

4. **Layout rules**
   - Grids, max-width container, section paddings
   - Breakpoints you want (example: 1440/1024/768/375)

## How I translate Figma into modules

### A) Design System
- Everything reused across multiple screens becomes a `design_system/components/*` component.
- Tokens go in `design_system/tokens/` (JSON or code constants).

### B) Feature modules
- Each route/screen = a feature, e.g. `features/landing`, `features/auth`, `features/profile`.
- Each feature owns its screen composition, local UI helpers, and state.

### C) Page sections
For a single marketing page, sections typically become **feature-local components** unless reused:
- `HeroSection`
- `FeaturesSection`
- `PricingSection`
- `FAQSection`
- `Footer`

## If you can’t share the Figma file publicly
This environment can’t reliably open Figma interactive pages.

Use one of these:
- Export frames to PNG and upload here
- Or share a **public** Figma prototype link with view access + exported specs
- Or paste the text content + a few key measurements (container width, paddings)
