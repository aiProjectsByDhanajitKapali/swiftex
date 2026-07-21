---
name: thread-handling
description: >-
  iOS threading for view models and PView I/O. Two modes: (1) audit an
  existing file or PR—writes `.cursor/skills/project-ops/thread-audits/THREAD_AUDIT_*.md` with
  PROP-* proposals (Accept/Reject) and an implementation prompt for accepted
  items; (2) implementation guide for structuring new code—global queue work,
  setPublished for Output, input receive(on:), runOnMainThreadIfNeeded for UI
  hops (not raw MainActor.run / DispatchQueue.main), @ThreadSafe for non-Output
  stored state touched from multiple threads. Use when migrating or auditing
  queues, Combine schedulers, MainActor, thread-checker work, or when the user
  mentions threads, setPublished, or background work in ViewModels.
owner: Siddharth Khanna
---

# Thread handling (iOS)

This skill functions in **two modes**. Pick the mode that matches the task; the rules below apply to both.

## Mode 1 — Audit

Use when reviewing an **existing** file, diff, or PR.

**Workflow**

1. Read the touched `transform` / `init` bindings and any coordinator or toast calls.
2. Cross-check PView structure with `.cursor/skills/architecture-reference/pview-io-pattern/SKILL.md` if the screen uses PView Input/Output.
3. Walk the **Verification checklist** (below) line by line and note gaps or false positives.
4. **Write an audit artifact file** (required): copy `.cursor/skills/project-ops/thread-audits/TEMPLATE.md`, save as  
   `.cursor/skills/project-ops/thread-audits/THREAD_AUDIT_YYYY-MM-DD_<slug>.md`  
   (`<slug>` = short feature name, primary type name, or ticket id; use only safe filename characters).
5. Fill **Metadata**, **Summary**, and one **`PROP-*` block per proposed fix**. Each proposal must include a concrete **Proposed change** (steps or snippet), not vague advice. Optional **Checklist trace** table links checklist rows to `PROP-*` ids.
6. Leave each proposal’s **Decision:** checkboxes **empty** for the human reviewer unless the auditor is certain and the user asked for auto-resolution.

**Accept / reject → implementation prompt**

1. The reviewer marks **`[x] Accept`** or **`[x] Reject`** on each `PROP-*` block (only one of the two per proposal).
2. **Generate the implementation prompt** by completing the **Implementation prompt** section at the bottom of the audit file so it lists **only** accepted `PROP-*` summaries (or paste that filled block into a new chat).
3. Run implementation using **Mode 2** (implementation guide): point the agent at `.cursor/skills/code-review/thread-handling/SKILL.md` Mode 2 and attach the audit file plus the Swift files to edit.

**Deliverable:** The markdown file under `.cursor/skills/project-ops/thread-audits/` as above; optionally a short chat summary that links to that path. Do not substitute an unstructured chat-only audit when a file was feasible.

## Mode 2 — Implementation guide (for other skills)

Use when **authoring or extending** view models, `transform(input:)`, or related services—your own work or instructions embedded in another skill (for example create-pview-feature, api-integration, or implementing fixes after an audit).

**Workflow**

1. Apply the **Rules** section when designing subscriptions and state updates.
2. Prefer this document over ad-hoc threading so new code stays consistent with project conventions and `AGENTS.md`.
3. Other skills should reference this file for “how to wire queues and `setPublished`” instead of duplicating long threading prose.

**Deliverable:** Code that satisfies the same invariants the audit checklist verifies.

---

## Rules

### Computation

- Run **heavy work and business logic** on a **global background queue** (for example `DispatchQueue.global(qos:)`), not on the main thread, unless the API is main-thread-only.

### Output (`@Published` / `Output` observable state)

- Update **SwiftUI-bound / published properties on `Output`** only via **`setPublished`**, so mutations use `runOnMainThreadIfNeeded` and the `Equatable` overload can skip redundant `objectWillChange` traffic.

- Source: `App/Module/Wallet/WalletView/View/Balance/WalletDetailView/CombineSubject+Extension.swift` — `ObservableObject.setPublished(_:_:)`.

### Input publishers (View → ViewModel)

- **Receive** input-driven Combine chains on **`DispatchQueue.global()`** by default, for example `.receive(on: DispatchQueue.global())`, unless a documented exception needs another scheduler. Note exceptions beside the subscription.

### APIs that already marshal to main (no extra main-queue hops)

- **`PTextViewModel`** and similar project “UI sink” helpers that internally hop to main.
- **PView output helpers** such as `output.viewBody`, **set error**, **set shimmer**, **set loader**, **set hidden**, and related output APIs: safe to call from **any** thread.

Do **not** add redundant **`runOnMainThreadIfNeeded`** or other main-queue wraps around these unless you have confirmed a specific implementation is not thread-safe.

### Main-queue UI work (imperative hops)

When you must **schedule UIKit / presentation / toast / coordinator work on the main queue** from a background or unknown thread, use **`runOnMainThreadIfNeeded`** (`App/Utility/Helpers/MainThreadUtils.swift`). It runs synchronously if already on the main thread and otherwise dispatches asynchronously—matching project conventions and avoiding useless nested async hops.

**Do not** use **`DispatchQueue.main.async { ... }`**, **`MainActor.run { ... }`**, or **`Task { @MainActor in ... }`** for that “hop to main and run this closure” pattern in app code. Prefer **`runOnMainThreadIfNeeded { ... }`** instead.

**Exceptions (rare, document inline):** Swift APIs that **require** `await MainActor.run` inside **`async`** code, generated/UIKit callbacks already documented as main-only, or third-party APIs that mandate `MainActor`. `@MainActor` **isolation on a type or method** is separate from ad-hoc hops—follow existing module patterns; still prefer **`runOnMainThreadIfNeeded`** inside non–`async`/Combine closures when you only need a main-queue UI block.

### Main thread required (explicit)

- **Toast** and similar overlay services if they do not document main-thread safety.
- **Coordinator** navigation and **UIKit** presentation.
- **View** and **view controller** **creation** and **presentation**.

Wrap those bodies in **`runOnMainThreadIfNeeded { ... }`** when the caller may be off main. When unsure, perform UI creation and presentation on main via **`runOnMainThreadIfNeeded`**.

### Multi-thread stored state (`@ThreadSafe`)

- **`Output` is out of scope here:** SwiftUI-bound **`Output`** fields must be updated **only on the main thread** via **`setPublished`**—do **not** mark those properties **`@ThreadSafe`** instead of fixing threading; cross-thread `Output` mutations are invalid.

- For **any other stored property** on a **view model**, **interactor**, or similar type that can be **read or written from more than one thread** (for example a cache or flag updated from **`DispatchQueue.global()`** callbacks **and** from main-thread code without a single serialization point), declare it with **`@ThreadSafe`** from **`App/Module/CustomComponents/ThreadSafe.swift`**.

- **`@ThreadSafe`** is an acceptable choice whenever multi-thread access applies; you do **not** need to prefer refactoring to “single-thread ownership” first.

- Optional **`@ThreadSafe(queue:)`** when multiple related fields should share one queue—see comments in **`ThreadSafe.swift`**.

### View model lifetime

- **View models may be initialized on any queue** unless the type is `@MainActor` or its initializer documentation requires main.

## Verification checklist (Mode 1)

Copy and use when auditing a file or PR:

- [ ] Non-trivial work off main where appropriate.
- [ ] Every `Output` published-field change goes through `setPublished` (from `CombineSubject+Extension.swift`).
- [ ] Input pipelines use `.receive(on: DispatchQueue.global())` unless an exception is documented inline.
- [ ] Toasts, coordinators, new VCs/views: created and presented on main via **`runOnMainThreadIfNeeded`** when the call site may be off main—not ad-hoc **`DispatchQueue.main.async`** / **`MainActor.run`** / **`Task { @MainActor ... }`** for the same pattern (unless a documented exception applies).
- [ ] No duplicate main dispatches around `setPublished`, `PTextViewModel`, or documented thread-safe output helpers.
- [ ] Non-**`Output`** stored properties that are **mutated or read from multiple threads** use **`@ThreadSafe`** (`ThreadSafe.swift`); **`Output`** stays main-only via **`setPublished`**, not **`@ThreadSafe`**.

## Reference

- **`runOnMainThreadIfNeeded`:** `App/Utility/Helpers/MainThreadUtils.swift`.
- **`@ThreadSafe`:** `App/Module/CustomComponents/ThreadSafe.swift`.
- Repository **`AGENTS.md`** — **Thread dispatch — migration and checker** (same policy, root-level for agent tools).
- **PView I/O:** `.cursor/skills/architecture-reference/pview-io-pattern/SKILL.md`.
- **Thread-checker agent:** `.cursor/agents/thread-checker/AGENT.md` (invokes this skill in **audit mode / Mode 1**).
- **Audit artifact template:** `.cursor/skills/project-ops/thread-audits/TEMPLATE.md`.

## After applying this skill

If the change touches PView boundaries, confirm alignment with `.cursor/rules/pview-io-pattern.mdc` where relevant. Prefer Thread Sanitizer or targeted tests for non-obvious concurrency.
