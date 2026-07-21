---
name: pview-io-pattern
description: Reference for the PView Input/Output architecture. Use when modifying PView screens, understanding View-ViewModel flow, or debugging bindings. Covers Input, Output, transform, PassthroughSubject, and cancellables.
owner: Siddharth Khanna
---

# PView I/O Pattern

Quick reference for the PView architecture.

## Flow

```
View (UI)  →  PassthroughSubject.send()  →  Input (AnyPublisher)  →  transform()  →  Output (@Published)  →  View (UI)
```

## View (View.swift)

- Conform to `PView`
- `@ObservedObject var output: Output`
- One `PassthroughSubject` per user event (e.g. `onAppearSubject`, `onButtonTappedSubject`)
- `init(viewModel:)` → `output = viewModel.transform(input: .init(onAppear: onAppearSubject.eraseToAnyPublisher(), ...))`
- In body: `.onAppear { onAppearSubject.send() }`, `ButtonView(...) { buttonTappedSubject.send(.buy) }`
- NEVER mutate `output` directly; always use subjects

## View+IO (View+IO.swift)

- `struct Input { let onAppear: AnyPublisher<Void, Never>; let onButtonTapped: AnyPublisher<ButtonType, Never> }`
- `final class Output: ObservableObject { @Published var isLoading = false; @Published var title = "" }`

## ViewModel

- `PViewModelable` with `typealias View = FeatureName`
- `private var cancellables`, `private var viewModelCancellables`
- `transform(input:)` → bind ONLY Input publishers; store in `cancellables`
- `init` → bind API, internal subjects, etc.; store in `viewModelCancellables`
- **`output` must be `private let`, not `lazy var`.** Construct `output` in `init` (e.g. `private let output = FeatureName.Output()` or `Output(...)` after any child VMs it needs). Order `init` assignments so dependencies exist before `Output(...)`; do not use `lazy var output` to work around ordering—fix the initialization order instead.
- Use `[weak self]` in closures; do NOT clear cancellables in deinit

## Critical Rules

- NEVER create ViewModels inside views
- NEVER mutate Output from views; use PassthroughSubject
- transform = Input bindings only; init = everything else
- ALWAYS use ButtonView (never SwiftUI Button)
- Feature ViewModel: **`private let output`**, built in **`init`** — not **`lazy var output`**

## Reference

Example: `App/Module/TradePage/CommonView/TradePageHoldingsView/`

## After applying this skill

Verify compliance with the rule in `.cursor/rules/pview-io-pattern.mdc` (no ViewModels in views, no Output mutation from View, ButtonView only, transform vs init binding split, `output` as `let` not `lazy`).
