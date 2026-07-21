---
name: ios-code-review
description: Reviews Swift/iOS code for project architecture compliance and iOS best practices. Use when the user asks for code review, PR review, or to check Swift/SwiftUI/UIKit code.
owner: Ram Sharma
---

# iOS Code Review (project + iOS)

When performing a code review, apply the checklists below and report findings in the specified output format.

---

## Architecture Checklist

- **PView**
  - Input/Output: View has `Input` (AnyPublisher) and `Output` (ObservableObject with @Published); ViewModel implements `transform(input:) -> Output`.
  - PassthroughSubject: User events go through subjects (e.g. `onAppearSubject`, `onButtonTappedSubject`), not direct Output mutation.
  - No ViewModels in views: ViewModels (including child VMs like SlideButtonViewModel, PHtmlTextViewModel) are created in the ViewModel and exposed via Output; never instantiate ViewModels inside views.
  - `init(viewModel:)` pattern: PView screens use `init(viewModel: ViewModel)` and `output = viewModel.transform(input: .init(...))`.
- **ButtonView**
  - Never use SwiftUI `Button`; always use `ButtonView` (e.g. `ButtonView(varient: .primary, size: .large, ...) { ... }`).
- **Coordinator**
  - Use `GenericCoordinator` with a `CoordinatorPages` enum; navigation via `route(to:)` with a switch.
  - PView screens: `ScreenObjectMapper.push(PModuleFactory.getModule(viewModel: viewModel, rootView: view))`; never use `BaseUIHostingController` directly.
- **Extensions**
  - Properties used in extension files should have `internal` (or appropriate) access so extensions can use them.
- **File organization**
  - View+IO in separate `View+IO.swift`; ViewBuilders in extensions with clear comments; meaningful accessibility identifiers (e.g. `GSSADPView_BuyButton`).

---

## General iOS Checklist

- **Memory**
  - Use `[weak self]` in closures to avoid retain cycles; avoid `unowned` unless ownership is guaranteed.
  - Do not clear cancellables in `deinit` (ARC handles `Set<AnyCancellable>`).
- **Threading**
  - UI updates on main thread; use `@MainActor` for UI-related code; proper use of async/await and Task.
- **Error handling**
  - Use `do`/`catch`, `Result`, or meaningful error types; provide clear error messages.
- **SwiftUI**
  - Prefer `@State` for local UI state, `@StateObject` for owned ObservableObjects; use `LazyVStack`/`LazyHStack` for long lists; `.setFont` instead of `.font` per project rules.
- **Security**
  - No hardcoded secrets; validate and sanitize user input where relevant.

---

## Output Format

Report findings in three levels:

1. **Critical (must fix)**  
   Violations of project rules or serious iOS issues (e.g. SwiftUI Button instead of ButtonView, ViewModels created in views, direct Output mutation, retain cycle risks, UI off main thread).

2. **Suggestion (consider)**  
   Improvements that align with project conventions or best practices (e.g. missing accessibility identifiers, inconsistent spacing, better error messages).

3. **Nice to have (optional)**  
   Minor style or clarity improvements.

---

## Reference

- Fast staged checks (git hook, no LLM): `.cursor/skills/code-review/pre-commit-staged/SKILL.md`
- UI component grep rules (SwiftUI `Button` → `PButtonView`; `ButtonView` ignored; PView host, etc.): `.cursor/skills/code-review/ui-component-usage/SKILL.md`
- Project rules: `.cursorrules` (View Model pattern, Coordinator, UI components, Input/Output, ViewBuilders).
- Feature / module architecture (sample checklist): `.cursor/skills/code-review/architecture-review/SKILL.md`.
- PView I/O: `.cursor/skills/architecture-reference/pview-io-pattern/SKILL.md`.
- New screens: `.cursor/skills/new-feature/create-pview-feature/SKILL.md`.
