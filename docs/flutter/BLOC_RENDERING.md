# BLoC rendering: only rebuild what changed

Goal: when a user interacts with **one element**, only that element (or its small subtree) rebuilds — not the whole screen.

## Core techniques

### 1) Split widgets aggressively
Keep the screen widget mostly static and push dynamic parts into small widgets.

Bad: one giant `BlocBuilder` wrapping the whole page.
Good: multiple small `BlocBuilder`/`BlocSelector` around only the interactive areas.

### 2) Prefer `BlocSelector` for small slices
`BlocBuilder` rebuilds when the full state changes.
`BlocSelector` rebuilds only when the selected value changes.

Example:
- A “Like” button selects `isLiked`
- A badge selects `count`

### 3) Use `buildWhen` (BlocBuilder)
If you must use `BlocBuilder`, add `buildWhen: (prev, next) => prev.someField != next.someField`.

### 4) Use `context.select` inside leaf widgets
Inside a tiny widget, use `context.select((MyBloc b) => b.state.someField)` to rebuild only that widget.

### 5) Keep state immutable + comparable
Use immutable state objects and equality (commonly `Equatable`) so Flutter can efficiently decide changes.

### 6) Avoid page-level `setState`
If you use `setState` at the screen level, the whole screen rebuilds.
Use BLoC for domain/UI state, or (for purely visual micro-state like animation controller) local state in a small widget.

## Practical pattern for a list
If you have a list of items and only one item toggles:
- Keep state as a map keyed by item id.
- Create a list item widget that selects only its own item state.

## Quick checklist (what I’ll follow when implementing your frame)
- Screen: mostly `const` widgets
- Each interactive element: its own widget
- Interaction state: BLoC state sliced per element
- `BlocSelector` or `context.select` at leaf nodes
