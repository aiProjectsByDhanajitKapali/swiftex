---
name: create-pview-feature
description: >-
  Plan-first PView scaffolding: after the Gate, emit a review-only architecture plan (expand/collapse
  view tree with per-PView H/S/L/E/U/A) in chat; implement Steps 1–5 only after explicit follow-up
  approval. Use for new screens, modals, or migrating legacy SwiftUI to PView (ViewModel, View+IO,
  optional ViewState, Coordinator), PUIKit state management, and parent enableStateManager.
owner: Siddharth Khanna
---

# Create PView Feature

Scaffold a **new** **`PView`** screen **or migrate an existing view** to **`PView`** following the PView architecture and PUIKit **`ViewState`** / **`StateHandleable`** patterns. **Default workflow:** **Phase A** — after the **Gate**, output the **architecture plan** (§ below) in chat and **stop** (no project file edits). **Phase B** — only after the user **approves the plan in a follow-up message**, run Steps 1–5 in order. For **migration**, read **§ Migrating an existing view to PView** first, then the same two phases apply.

## Prerequisites

Collect up front:

- Module name (e.g. `TradePage`, `Wallet`, `GSS`)
- Feature / screen name (e.g. `HoldingsView`, `OrderTypePicker`)
- Whether navigation is needed (push via Coordinator) or embedded (child view only)

### Gate — no project files until Gate satisfied and plan approved (enforced)

**Two phases**

| Phase | What happens | Project files |
|-------|----------------|---------------|
| **Phase A — Architecture plan** | After the Gate below is satisfied, output the full **§ Architecture plan (mandatory before implementation)** in the chat thread. | **Do not** create, edit, or delete any project files. |
| **Phase B — Implementation** | Steps 1–5: scaffold or migrate files as specified. | Allowed **only** after **(1)** Gate satisfied **and (2)** the user **approves** the architecture plan in a **follow-up message** (e.g. “approved”, “implement as planned”, “scaffold files now”). |

**Do not** create, edit, or delete project files for this feature (Steps 1–5) until **both** the Gate is satisfied **and** the user has approved the architecture plan in a follow-up. If something is missing for the Gate, **stop**, list what you need, and **wait** (or use **`AskQuestion`**). **Do not infer** composition or managed-state protocols from Figma or screenshots alone. If the user asks for changes to the plan, revise Phase A output and **wait again** before Phase B.

| Gate item | Requirement |
|-----------|-------------|
| **Module / feature / navigation** | Confirmed in-thread (or **explicitly** stated by the user in the same prompt they used to invoke the skill). |
| **Composition (PView boundaries)** | **Required** when the prompt includes a **Figma URL** **or** describes **multiple UI regions** / a composite layout: you **MUST** use **`AskQuestion`** (or an equivalent **numbered checklist in chat** the user must answer) so the user confirms which blocks are **separate `PView`s** vs **one parent `PView`** with plain SwiftUI subviews. **No silent defaults** (e.g. assuming “one parent `PView`” without confirmation). |
| **Managed states (per `PView`)** | After boundaries are known: for **each** `PView`, you **MUST** use **`AskQuestion`** (or a **per-`PView` checklist** in chat) so the user selects which of **H / S / L / E / U / A** apply (see table below). **Do not** pick protocols yourself (e.g. “I’ll use Hidden + Appearance only”) unless the user **explicitly** listed those protocols for that `PView` in the same prompt. If **U (Empty)** is selected for a `PView`, you **MUST** also confirm **`PEmptyStateViewModel.Mode`** (and **`height`**) per **Empty state — confirm `PEmptyStateViewModel.Mode`** below — modes are **not** inferable from “empty state” alone. |

**Narrow exception (Gate questions only):** If the user’s message **already** contains an explicit, unambiguous answer for **every** gate row (boundaries + per-`PView` protocol set, and module/feature/navigation), you may **skip** `AskQuestion` — but you **must still** run **Phase A**: **restate those choices verbatim** inside the architecture plan for traceability, emit the **full** plan (including the view tree), **stop**, and **wait** for a follow-up before Phase B. You **must not** skip Phase A or begin Step 1 in the same turn as the initial request.

### Figma and composition (before Phase B / file work)

- Prompts may include a **Figma URL**. Treat the design as a potential **composition** of several cohesive regions, not always a single screen-level `PView`. The **Gate** still applies: confirm boundaries with the user unless the **narrow exception (Gate questions only)** applies — that exception **never** skips **Phase A** or permits file edits without a follow-up approval.
- **Order for obtaining Figma context:** **(1) Figma plugin first** — use plugin exports, specs, or other plugin output already in the prompt or ask the user to run the plugin and paste results if the URL is given but context is missing. **(2) MCP second** — only if plugin-based context is absent or insufficient, fetch via **Figma MCP**. Do not skip the plugin step when a Figma URL is present and the workflow expects plugin output unless the user explicitly says to use MCP only.
- **Figma fetch / context failure:** If **plugin** output was required and is **missing or unusable**, **stop** and ask the user to re-run the plugin or paste valid output; do not guess. If you then rely on **MCP** and the fetch **errors or returns unusable data**, **stop immediately**. Do **not** continue the architecture plan or Phase B as if the design were available. Report the failure clearly, state that **Figma MCP must be fixed**, and **wait** before proceeding — do not invent layouts to replace a failed fetch.
- **Composition confirmation:** Per the **Gate**, when Figma is present **or** the layout has distinct regions, you **MUST** obtain user confirmation of **logical grouping of subviews** (separate **`PView`s** vs one parent **`PView`** with plain SwiftUI) via **`AskQuestion`** or chat checklist — **not** optional inference.
- **Parent pattern:** a **container** (SwiftUI `View` or a parent `PView`) composes child **`PView`s**. **`enableStateManager()`** is applied on each child **`PView`** from this **parent** — never inside the child `PView`’s own `body` (see Step 3).

### Per-`PView` managed states and optional Figma per state

Per the **Gate**, after groupings are known (or for a single-screen `PView` once the user confirms it is a single `PView`), **for each `PView`** you **MUST** have the user confirm which **managed states** are required (via **`AskQuestion`** or explicit inline list from the user), mapped to PUIKit protocols:

| User-facing state | Protocol |
|-------------------|----------|
| Hidden | `HiddenStateHandleable` |
| Shimmer | `ShimmerStateHandleable` (requires `ShimmeringView` on the `PView`) |
| Loader | `LoaderStateHandleable` |
| Error | `ErrorStateHandleable` |
| Empty | `EmptyStateHandleable` |
| Appearance (onAppear / first / disappear / visibility) | `AppearanceStateHandleable` |

For **each protocol the user selects** for that `PView`, **optionally** ask for **supporting Figma** (link, frame, or node) for that state (e.g. empty-state frame, error-state frame). **Figma per state is optional** — the user may skip and you implement from **PUIKit defaults**, the **main frame**, or **team patterns**, keeping **tokens/spacing** aligned with the primary Figma when available.

#### Empty state — confirm `PEmptyStateViewModel.Mode`

When **`EmptyStateHandleable`** is selected for a `PView`, you **MUST** ask which **empty presentation** to use. PUIKit defines this as **`PEmptyStateViewModel.Mode`** on **`PEmptyStateViewModel`** — see the **`Mode`** enum in **`Sources/PUIKit/SwiftUIViewModifiers/PEmptyStateModifier.swift`** (same file as `EmptyStateHandleable` / `PEmptyStateModifier`).

| Mode | Meaning | Confirm with user |
|------|---------|-------------------|
| **`text(String)`** | Centered text only | Final copy / localization key; optional Figma for typography if not on main frame. |
| **`imageAndText(title:image:size:)`** | Image + title stack (default image size 48×48 unless overridden) | Title string, **image asset name** (R image / bundle), and **`CGSize`** if not default. |

Also confirm **`height`** (`CGFloat`) for the empty region unless the user or design already fixes it. **Do not** assume `.text` vs `.imageAndText` without confirmation** (same **narrow exception** as the Gate: user already specified mode + parameters verbatim in the prompt).

## Architecture plan (mandatory before implementation — Phase A)

After the **Gate** is satisfied (and Figma/context rules where applicable), **before any Phase B file work**, output **one** consolidated **architecture plan** reply. **Stop** after posting it; do **not** run Steps 1–5 until the user approves in a **follow-up message**.

### Required sections (use these headings in the plan reply)

1. **Summary** — Module, feature / screen name, navigation (Coordinator yes/no, push vs embedded), and how the **root** is composed (single top-level `PView` vs **container** hosting multiple child `PView`s). Note that **`.enableStateManager()`** is applied by the **parent** on **each** child **`PView`** that uses managed state (never inside the child’s `body`).
2. **Per-`PView` managed states** — Table: `PView` name | **H S L E U A** (list only letters enabled for that view; use **—** for unused) | if **U**: `PEmptyStateViewModel.Mode` + `height` | if **S**: note **`ShimmeringView`** required.
3. **State letter legend** — **H** Hidden, **S** Shimmer, **L** Loader, **E** Error, **U** Empty, **A** Appearance — same order as PUIKit modifier stack **H → S → L → E → U → A** (see Step 3).
4. **`Input` / `Output` sketch** — Bullets: main user events → **`Input`** publishers; notable **`Output`** contents (`viewState`, `let` child VMs, `@Published` where justified). **Migration:** call out former **`@State`** / view-owned objects moving to **`Output`**.
5. **Files to add or change** — Paths matching Step 1 (and Step 5 if Coordinator), including **`View/<FeatureName>+IO.swift`** beside **`View/<FeatureName>.swift`**.
6. **View tree** — Hierarchical tree per **View tree format** below.

### View tree format (expand/collapse)

Use **HTML `<details>` / `<summary>`** so each node can be expanded or collapsed in typical Markdown renderers (including Cursor chat).

- **One `<details>` block per `PView`**. Nest **child `PView`s** as **inner `<details>`** inside the parent’s content.
- **`<summary>` line (required pattern):**  
  `**ViewName** (PView) — states: H, L, A`  
  List **only** the state letters the user confirmed for that `PView`. If **U** is included, add **`PEmptyStateViewModel.Mode`** and **`height`** on the same summary line or as the **first indented line** immediately after the summary (before any nested `<details>`).
- **Plain SwiftUI / non-`PView` UI** under a parent: use **markdown bullets** inside that parent’s `<details>` body (not a separate `PView` row). Prefer concrete PUIKit components when known (see **`.cursor/skills/new-feature/ui-component/SKILL.md`** for `PText`, `PAttributedText`, `PButtonView`, `PTextField`). Do **not** assign **H/S/L/E/U/A** to non-`PView` bullets — managed states apply **per `PView`** only.
- **Root:** Match the Gate — either one screen `PView` or a **named container** (e.g. hosting `NavigationStack`) listing child `PView`s in the tree.

### Example (pattern to copy)

```markdown
### View tree

<details>
<summary><strong>OrderScreenContainer</strong> (host) — wraps child PViews; applies <code>.enableStateManager()</code> per child below</summary>

<details>
<summary><strong>OrderHeader</strong> (PView) — states: H, A</summary>

- `PText` — title
- `PButtonView` — dismiss

</details>

<details>
<summary><strong>OrderList</strong> (PView) — states: S, L, E, U, A — empty: `.text("orders.empty".localized())`, height: 200</summary>

- `PText` row subtitle (plain SwiftUI region inside this PView)

<details>
<summary><strong>OrderBanner</strong> (PView) — states: H, A</summary>

- `PAttributedText` — promo body

</details>

</details>

</details>
```

### Migration

For **migrate / PView-ify** tasks, build the tree from the **target** layout (the `PView` decomposition after migration), not from legacy **`Button`/`Text`** names alone. Optionally add a short **Delta from legacy** subsection (e.g. split regions, new managed states).

## Migrating an existing view to PView

Use this path when the user asks to **refactor**, **migrate**, or **PView-ify** an **existing** SwiftUI (or hosted) screen—not only when scaffolding from scratch.

### What you add or change

- **`FeatureNameViewModel`**: **create** (or substantially extend) a type that conforms to **`PViewModelable`** with **`typealias View = FeatureName`**. The screen’s **`PView`** uses **`init(viewModel:)`** and **`output = viewModel.transform(input: .init(...))`** like greenfield flows.
- **`FeatureName+IO.swift`**: define **`Input`** (subjects → **`AnyPublisher`**) and **`Output`**: **`final class`**, **`ObservableObject`**.
- **`FeatureName`**: conform to **`PView`**; move event wiring to **`PassthroughSubject`** + **`Input`**; **`@ObservedObject var output`**.

### State → `Output` (`@Published`)

- **Migrate all existing view-owned state** that drives the UI into **`Output`** as **`@Published`** properties: e.g. **`@State`**, **`@StateObject`** / **`@ObservedObject`** when the screen owns the object, computed display fields previously stored in **`@State`**, and other persisted screen state. The **`body`** should read that data from **`output`**, not keep parallel **`@State`** for the same concern.
- **Child view models** already preferred as **`let`** on **`Output`** (see Step 2) still apply when the subtree is a nested VM; use **`@Published`** for plain values, collections, and flags that used to live on the view.
- **Gesture-only / ephemeral UI** may stay local only where **`.cursorrules`** explicitly allows (e.g. drag offset); **business** state must not stay **`@State`**.

### ViewModel responsibilities and threading

- **Move all calculations** (formatting, sorting, filtering, derived strings, decision logic, combining API results) **into the ViewModel**—not the **`PView`** **`body`** or inline **`View`** helpers.
- **Prefer heavy work off the main thread** (e.g. **`DispatchQueue.global()`** with Combine **`.receive(on:)`**, or **`Task.detached`** for async CPU work). **Always** apply **`Output`** / **`@Published`** mutations (and anything that triggers SwiftUI updates) on the **main thread** (**`MainActor.run`**, **`@MainActor`** methods, or **`DispatchQueue.main.async`** / **`runOnMainThreadIfNeeded`** per project convention).

### Gate (migration)

- Still confirm **module / feature / navigation** (and **Coordinator** if push/present changes). **Phase A** (architecture plan) and **Phase B** (approval before files) apply the same as greenfield.
- If the task is a **1:1** refactor of **one** existing view **without** splitting into multiple **`PView`s**, you may proceed without re-asking composition; **if** the user wants **multiple regions** as separate **`PView`s** or new **H/S/L/E/U/A** behavior, use the **Gate** ( **`AskQuestion`** ) as for greenfield.

## Step 1: Create folder structure

**Phase B only** — the user **approved** the **§ Architecture plan** in a **follow-up message** after Phase A. **Only after the Gate is satisfied** (see Prerequisites).

```
App/Module/<Module>/<FeatureName>/
├── View/
│   ├── <FeatureName>.swift
│   └── <FeatureName>+IO.swift
├── ViewModel/
│   └── <FeatureName>ViewModel.swift
└── Coordinator/          # Only if navigation needed
    └── <FeatureName>Coordinator.swift
```

Place **`<FeatureName>+IO.swift` in the same `View/` folder** as **`<FeatureName>.swift`**. Do **not** create a separate `View+IO/` directory.

Nested **`ViewState`** lives in **`<FeatureName>+IO.swift`** alongside the view (see Step 2).

## Step 2: Create `FeatureName+IO.swift` (under `View/`)

Define three nested types under `extension FeatureName` when using PUIKit managed UI state (otherwise **`Input`** + **`Output`** only).

### Types

| Type | Role |
|------|------|
| **`Input`** | `AnyPublisher` per **user/event** only. **Do not** add `onAppear` / `onFirstAppear` here when using **`AppearanceStateHandleable`** — lifecycle comes from **`viewState.appearanceState`** (see Step 4). |
| **`Output`** | `final class`, `ObservableObject`. **Greenfield:** **prefer avoiding `@Published` on `Output`** — keep **`let`** **non-optional** child view models and `viewState` on `Output`. **Do not** use **`Optional` child view models** to mean “not shown”: **always initialize** every child VM in the feature ViewModel / `Output` path; if a subtree starts hidden, use **`PHiddenViewModel`** (or the subtree’s hidden path) **`hidden == true` by default**. Each nested VM should default to an **idle / not shown** state where applicable (e.g. not loading, not error). **`@Published` on `Output`** is acceptable when needed (e.g. **arrays, pagination, collection-driven UI**). **Migration from an existing view:** treat former view state as **`@Published`** on **`Output`** (see **§ Migrating an existing view to PView**). When using PUIKit state stack: conform **`StateHandleable`** and hold **`let viewState = ViewState()`**. |
| **`ViewState`** | `final class` conforming to the **subset** of `*StateHandleable` protocols this screen needs. |

### Protocol checklist (PUIKit)

| Protocol | Requirement |
|----------|-------------|
| `HiddenStateHandleable` | `hiddenViewModel: PHiddenViewModel` |
| `ShimmerStateHandleable` | `shimmerState: ShimmerState`; screen also **`ShimmeringView`** with `shimmerView` |
| `LoaderStateHandleable` | `loaderState: PLoaderViewModel` |
| `ErrorStateHandleable` | `errorViewModel: PErrorViewModel` |
| `EmptyStateHandleable` | `emptyStateViewModel: PEmptyStateViewModel` — **`Mode`** (`.text` vs `.imageAndText`) and **`height`** must be **user-confirmed** (see Prerequisites § **Empty state — confirm `PEmptyStateViewModel.Mode`**). |
| `AppearanceStateHandleable` | `appearanceState: AppearanceState` |

**`transform(input:)`** in the ViewModel **only** binds **`Input`** publishers into `cancellables`. **Do not** put lifecycle on `Input` when using **`AppearanceStateHandleable`**.

### Snippet A — `ViewState`, `Output`, and non-optional child VMs (illustrative)

```swift
extension MyFeature {
    final class ViewState: HiddenStateHandleable, AppearanceStateHandleable {
        let hiddenViewModel: PHiddenViewModel = false // or true when section starts hidden
        let appearanceState: AppearanceState = .init()
    }

    struct Input {
        let primaryAction: AnyPublisher<Void, Never>
    }

    final class Output: ObservableObject, StateHandleable {
        let viewState: ViewState = .init()
        // Prefer `let` child VMs here; avoid Optional VMs for visibility.
        // @Published var rows: [Row] = []  // OK when lists/pagination need it

        init() {}
    }
}
```

## Step 3: Create `FeatureName.swift`

- Conform to **`PView`** (which refines SwiftUI `View`): **`struct MyFeature: PView`** with `associatedtype` `Input` / `Output` supplied by the `PView` generic pattern used in the project.
- **`@ObservedObject var output: Output`**
- **`PassthroughSubject`** for each **`Input`** publisher; **`init(viewModel: ViewModel)`** assigns **`output = viewModel.transform(input: .init(...))`**
- **`body`**: real UI + wiring subjects only. **Do not** call **`.enableStateManager()`** inside this `PView`’s `body`.
- **Shimmer:** when `ViewState: ShimmerStateHandleable`, declare **`MyFeature: PView, ShimmeringView`** and implement **`shimmerView`**.
- **Accessibility:** `.accessibilityIdentifier("ModuleName_FeatureName_Element")` on key elements.
- **Buttons:** **`ButtonView`** only — never SwiftUI **`Button`**.

### Snippet B — Parent applies `enableStateManager()`

The **parent** (container or host) wraps each child `PView`. Swift picks the **`enableStateManager()`** overload from the child’s **`ViewState`** protocol conformance set.

```swift
// Parent container — not inside MyFeature.body
MyFeature(viewModel: myFeatureViewModel)
    .enableStateManager()
```

For shimmer-capable children:

```swift
MyFeature(viewModel: myFeatureViewModel)
    .enableStateManager() // requires MyFeature: ShimmeringView when ViewState includes shimmer
```

Modifier stacking order inside PUIKit is **H → S → L → E → U → A** (hidden → shimmer → loader → error → empty → appearance).

## Step 4: Create `FeatureNameViewModel.swift`

- Conform to **`PViewModelable`** with **`typealias View = FeatureName`**
- **`private var cancellables: Set<AnyCancellable> = []`**
- **`private var viewModelCancellables: Set<AnyCancellable> = []`** for subscriptions started in **`init`** (not from `Input`)
- **`private let output`** — **do not** use **`lazy var output`**. Build **`FeatureName.Output()`** (or **`Output(childVMs: …)`**) in **`init`** after any stored properties the `Output` (or its child VMs) needs. If child VMs are required first, declare them as **`private let`** and assign them in **`init`** in dependency order, then **`self.output = FeatureName.Output(...)`**.
- **`transform(input:)`**: **only** bind **`Input`** publishers; **`cancellables = []`** at the start of `transform`; **`.store(in: &cancellables)`**
- **All other bindings** (API, internal subjects, **appearance streams**) in **`init`** → **`viewModelCancellables`**
- Use **`[weak self]`** in closures
- **Do not** clear `cancellables` in **`deinit`**

### `StateHandleable` and appearance

When **`Output: StateHandleable`** and **`ViewState: AppearanceStateHandleable`**, extend the ViewModel with **`StateHandleable`** so **`setHidden()`**, **`viewBody()`**, **`onAppear`**, etc. are available on **`self`**.

### Snippet C — `StateHandleable` + `bindAppearance()` in `init`

```swift
extension MyFeatureViewModel: StateHandleable {
    var viewState: MyFeature.Output.ViewState {
        output.viewState
    }
}

final class MyFeatureViewModel {
    private let output: MyFeature.Output = .init()
    private var cancellables: Set<AnyCancellable> = []
    private var viewModelCancellables: Set<AnyCancellable> = []

    init() {
        bindAppearance()
    }

    private func bindAppearance() {
        isVisible
            .sink { [weak self] visible in
                // handle visibility if needed
            }
            .store(in: &viewModelCancellables)
        onAppear
            .sink { [weak self] in
                // every appear
            }
            .store(in: &viewModelCancellables)
        onDisappear
            .sink { [weak self] in
            }
            .store(in: &viewModelCancellables)
        onFirstAppear
            .sink { [weak self] in
                // first appear only
            }
            .store(in: &viewModelCancellables)
    }
}

extension MyFeatureViewModel: PViewModelable {
    typealias View = MyFeature

    func transform(input: MyFeature.Input) -> MyFeature.Output {
        cancellables = []
        input.primaryAction
            .sink { [weak self] in
                // ...
            }
            .store(in: &cancellables)
        return output
    }
}
```

### Snippet D — State transitions

**`setShimmer()`**, **`viewBody()`**, **`setError()`**, **`setEmpty()`**, **`setLoader()`**, **`setHidden()`** come from **`StateHandleable`** extensions in PUIKit when the corresponding **`ViewState`** protocols are satisfied.

## Step 5: Coordinator (if navigation needed)

When navigation is in scope (per Prerequisites / Gate), **read and follow** the **`create-coordinator`** skill end-to-end:

**`.cursor/skills/new-feature/create-coordinator/SKILL.md`**

It defines folder layout, `CoordinatorPages`, `GenericCoordinator`, `PModuleFactory.getModule` + `ScreenObjectMapper.push`, and rules such as not using **`BaseUIHostingController`** directly for these flows.

**From this skill (PView only):** after wiring push/present from the coordinator, ensure the **pushed root** or an **outer container** applies **`.enableStateManager()`** on each child **`PView`** that uses managed state, if that is not already handled higher in the tree.

## Critical rules

- **Plan-first:** **Phase A** — after the **Gate**, output the full **§ Architecture plan** (including the **view tree**) and **stop**; **no** project file edits until the user **approves** in a **follow-up**. **Phase B** — Steps 1–5 only after that approval. Never skip composition or per-`PView` state confirmation by inferring from design alone. **Exception:** **§ Migrating an existing view to PView** (1:1 refactor, no split) still requires **Phase A**; it only relaxes **re-asking composition** when not splitting into multiple `PView`s.
- **Never** create ViewModels inside views; expose VMs through **`Output`** (and feature ViewModel).
- **Never** mutate **`Output`** from views for business state; use **`PassthroughSubject`** into **`Input`** (gesture-only exceptions per `.cursorrules`).
- **Parent-only `enableStateManager()`:** the **parent** applies **`.enableStateManager()`** on the child **`PView`**. **Never** call **`.enableStateManager()`** inside the **`PView`’s own `body`**.
- **Shimmer:** **`ShimmeringView`** + **`ViewState: ShimmerStateHandleable`**.
- **Lifecycle:** prefer **`AppearanceStateHandleable`** + **`bindAppearance()`** in the ViewModel **`init`** (**`viewModelCancellables`**), not **`Input.onAppear`** / **`Input.onFirstAppear`** for new screens.
- **`Output`:** **strong preference to avoid `@Published`**; use **`let`** child VMs + **`viewState`**; **no `Optional` child VMs** for visibility — use **default hidden / idle** on those VMs (**`PHiddenViewModel`** etc.). **`@Published`** on **`Output`** only when justified (**lists, pagination**).
- **Feature ViewModel `output`:** **`private let`**, constructed in **`init`** — **never `lazy var output`** (avoid **`lazy`** for values only used to build **`output`**; use explicit **`init`** ordering instead).
- **Migration:** add **`PViewModelable`** **`ViewModel`**; move **all** former view-driven state to **`Output`** **`@Published`**; move **calculations** to the ViewModel; **heavy work** off main thread, **`Output`** updates on **main**.
- **Navigation:** **`PModuleFactory.getModule`** + **`ScreenObjectMapper.push`** for **`PView`** flows.
- **Buttons:** **`PButtonView`** only (see [ui-component](../ui-component/SKILL.md)).
- **Images:** **`PImageView` + `PImageViewViewModel`** only — no SwiftUI `Image`, `RemoteImageView`, or `NWImageView` in the view layer (see [ui-component § Images](../ui-component/SKILL.md)). Nav icons use **`PButtonView`** `.iconOnly`, not `PImageView`.

## Reference

- **Architecture plan (Phase A):** § **Architecture plan (mandatory before implementation — Phase A)** in this file.
- **UI primitives for Phase B `body`:** `.cursor/skills/new-feature/ui-component/SKILL.md` — `PButtonView`, `PText`, `PTextField`, **`PImageView`**, Lightning tokens.
- **Coordinator (when Step 5 applies):** `.cursor/skills/new-feature/create-coordinator/SKILL.md`
- **Project:** `.cursorrules` — sections 1.1 (Input/Output), 1.4 (appear / `appearSubject` pattern superseded by **AppearanceStateHandleable** for new PUIKit-managed screens), 2.1 (Coordinator), 2.2 (PView navigation).
- **PUIKit** (Swift package dependency): **do not assume** these files are on disk in the current Cursor workspace. PUIKit may be resolved only via SPM (e.g. under Xcode **DerivedData**), a **different git repo**, or an unopened multi-root folder — path-based references may fail. Prefer **Jump to Definition** / **symbol search** in the IDE, or open the PUIKit package alongside the app when you need to read sources. When PUIKit *is* available as a checked-out package, implementations commonly live under paths like:
  - `PView`, `PViewModelable`, `StateHandleable`, `*StateHandleable` protocols — search under the package’s `SwiftUICoreViews` (e.g. `PView.swift`, `StateHandleable.swift`, `PView+StateHandleable.swift`, `PView+Shimmer.swift`).
  - State modifiers — search under `SwiftUIViewModifiers` (e.g. `PAppearanceModifier`, `PHiddenModifier`, `PLoaderModifier`, `PErrorModifier`, `PEmptyStateModifier`).
