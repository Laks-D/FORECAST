# Design System

- `tokens/`: design tokens (prefer semantic naming)
- `theme/`: theme assembly (light/dark) using tokens
- `components/`: shared UI components

A good workflow is:
1) export tokens from Figma (via plugin) → `tokens/*.json`
2) map tokens to your UI framework theme system
3) build components that consume the theme, not raw hex values
