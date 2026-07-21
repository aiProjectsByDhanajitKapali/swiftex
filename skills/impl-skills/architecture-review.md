---
name: architecture-review
description: Sample architecture review checklist for module boundaries, navigation, dependency flow, and cross-cutting contracts in the iOS app. Use when assessing design of a feature, refactor scope, or PR that touches coordinators, factories, or shared layers—not line-by-file style review alone.
owner: Ram Sharma
---

# Architecture review (sample)

Use this alongside **`.cursor/skills/code-review/ios-code-review/SKILL.md`** for conformance in individual files: **architecture-review** focuses on **system shape**—how pieces connect, own state, and fail.

---

## When to use

- New feature spanning multiple screens or modules
- Moves between UIKit hosts, coordinators, SwiftUI `PView` modules, or tab flows
- Introducing shared services, caches, or global singletons
- Changes to routing, deep links, or modal presentation stacks
- “Is this layered correctly?” before or after large refactors

---

## Module and layering

- **Dependency direction**: Do domain/data UI depend inward correctly? Avoid feature modules importing “everything upward” without a clear facade.
- **Boundaries**: Are network, persistence, and analytics accessed through defined types (protocols / services / interactors), not scattered static calls?
- **Factories**: Prefer `PModuleFactory.getModule(...)` patterns for SwiftUI stacks; coordinators stay navigation-only where possible—no duplicate construction paths unless justified.

---

## Navigation and coordinators

- **Coordinator shape**: Enum-driven `CoordinatorPages`, `route(to:)`, switches exhaustive for new cases.
- **Consistency**: Prefer one path (`ScreenObjectMapper.push` + `PModuleFactory`, not ad-hoc `UIHostingController` / `BaseUIHostingController` for `PView` flows).
- **Back stack**: Dismiss paths, unwind, and re-entry (tabs, overlays) behave predictably; no orphaned presenters.

---

## State and concurrency

- **Ownership**: Prefer `PassthroughSubject` / `CurrentValueSubject` patterns from project rules over ad-hoc global mutable state for feature state machines.
- **Threading**: UI updates confined to main; background work terminates cleanly; Combine subscriptions use `[weak self]` appropriately.
- **Cross-feature state**: Shared `CurrentValueSubject` or app-level stores are intentional, documented, and have a single writer.

---

## Cross-cutting contracts

- **Errors**: Retry, cancellation, and user-visible failure paths are consistent with existing module patterns.
- **Analytics / notifications**: If the change affects events or `NotificationCenter`, align with **`.cursor/skills/analytics/event-writing/SKILL.md`** and **`.cursor/skills/new-feature/add-notification-hook/SKILL.md`**.

---

## Output format

Deliver as short narrative plus bullets:

1. **Risks (address before merge)** — coupling, layering violations, ambiguous ownership, concurrency hazards.
2. **Improvements** — clearer boundaries, smaller types, extractor candidates, duplicated navigation to consolidate.
3. **Follow-ups** — tests, diagrams, docs (knowledge collector if the feature warrants a persisted note).

---

## Reference

- Project rules: `.cursorrules`
- PView I/O reference: `@.cursor/skills/architecture-reference/pview-io-pattern/`
- New feature scaffold: `@.cursor/skills/new-feature/create-pview-feature/`
- Coordinators: `@.cursor/skills/new-feature/create-coordinator/`
