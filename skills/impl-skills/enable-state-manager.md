# enableStateManager()

`.enableStateManager()` wires a component's managed states (hidden / shimmer / loader /
error / empty / appearance) from its `Output.ViewState`. It is a **PView modifier** that
returns `some PView`.

## Order is critical
Apply it IMMEDIATELY on the component — right after its initializer — and BEFORE any SwiftUI
modifier like `.setFont` or `.accessibilityIdentifier`. Those modifiers return `some View`
(not a `PView`), so `enableStateManager` cannot follow them.

- ✅ `PTextField(viewModel: vm).enableStateManager().accessibilityIdentifier("…")`
- ❌ `PTextField(viewModel: vm).accessibilityIdentifier("…").enableStateManager()`

## When to apply it
- Only on components/PViews that actually manage state. If a component has no managed states,
  omit it (applying it requires `Output.ViewState` to conform to the matching `*StateHandleable`).
- `PText`, `PTextField`, `PImageView`, and child PViews are all PViews — a parent applies
  `.enableStateManager()` on the child PView, never inside the child's own body.
