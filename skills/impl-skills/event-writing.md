---
name: event-writing
description: Implement CleverTap/Firebase analytics from a Machine_Ready_Events CSV (with figma_node_id for UI placement), following TradePageEventManager and EventManger.trackWithDictAll. Swift files use `<Feature>EventManager` only—never paste the spreadsheet export name into Swift type or file names. Use when adding events from a spreadsheet, mapping Figma nodes to Swift call sites, or scaffolding a feature EventManager.
owner: Hitendra Dubey
---

# Event Writing (CSV → iOS)

Implement analytics the same way **Trade Page** does: a small **feature EventManager** builds `[String: Any]` payloads and forwards them through **`EventManger.shared.trackWithDictAll`**. Use a **Machine_Ready_Events**-style CSV as the contract; only implement rows approved for release unless explicitly asked to scaffold pending specs.

## Canonical code references

- **Global sink:** `EventManger.shared.trackWithDictAll(with:dict:)` in `App/Manager/EventManger.swift` — adds `custom_user_id`, `datetime`, `logged_In`, `user_Type`, fans out to CleverTap, Firebase, AppsFlyer (unless `isOnlyFirebase`).
- **Feature pattern:** `App/Module/TradePage/Event/TradePageEventManager.swift`
  - `final class` + `static let shared` + `private init()`
  - **`EventActionTab`** — nested enums (`ButtonClick`, `ElementClick`, …) whose `.params` build **`action`** + **`action_tab`** (and related fixed keys). Call sites pass only **runtime** fields (`activity` is fixed by enum case; `value`, `sub_tab`, `asset_symbol`, … go in the trailing `params` dict).
  - **`staticParams()` / `baseParams()`** — keys shared by every call in that feature (e.g. `page_title`, `user_ID` via `EventMangerParam`).
  - **Landing:** dedicated method per landing bucket (e.g. `tradePageLanding`, `expertSignalLanding`) — not a raw `track(bucket:params:)` from ViewModels.
  - **Actions:** one entry point per actions bucket (e.g. `tradePageAction(_:params:)`, `expertSignalActions(_:source:params:)`) that merges base + `eventActionTab.params` + caller `params`, then `trackWithDictAll`.
  - Reference implementation for the events CSV: `ExpertSignalsEventManager` (`expertSignalLanding`, `expertSignalActions`, `exploreActions`, …).

Mirror this shape for new features: **`YourFeatureEventManager`** under `App/Module/<Feature>/Event/`, not ad-hoc `trackWithDictAll` or hand-built `["action": "button_click", …]` dicts in views.

## File and type naming (CSV spec vs Swift)

**`Machine_Ready_Events` is only the name of the CSV / spreadsheet export** — it describes the *spec format*, not a Swift module prefix.

| Use in CSV / docs | Use in Swift (file + types) |
|-------------------|-----------------------------|
| `Machine_Ready_Events` sheet | **Never** derive Swift files or types from the export filename (use `<Feature>EventManager` only) |
| `event_group`: `expert_signal` | `ExpertSignalsEventManager.swift` under `Module/SignalsRevamp/Event/` (or the real feature folder) |
| Trade Page events | `TradePageEventManager.swift` |
| EIPO events | `EIPOEventManager.swift` |

**Naming rule:** `<Feature>EventManager` where `<Feature>` matches the product area / module (PascalCase), same as `TradePageEventManager`. Do not concatenate the spreadsheet title, workbook name, or export slug into Swift identifiers.

```text
✅ ExpertSignalsEventManager.swift     final class ExpertSignalsEventManager
✅ TradePageEventManager.swift
❌ Names that embed the CSV workbook or export string in the Swift type (e.g. copying `Machine_Ready_Events` into a class name)
```

Comments may reference the CSV (`// Machine_Ready_Events row …`) — that is fine. **Do not** copy spreadsheet naming into filenames, class names, or enum names unless product explicitly requires that exact string in an analytics *payload* value.

## CSV schema (Machine_Ready_Events)

Expected columns:

| Column | Use |
|--------|-----|
| `event_group` | Module / folder (e.g. `expert_signal` → `Module/ExpertSignal/…`). |
| `event_name` | **Bucket** sent as top-level `trackWithDictAll` `with:` argument when product maps 1:1; often matches `EventMangerParam` / Firebase name. Multiple CSV rows can share one `event_name` (different `activity` / `action`). |
| `operation` | Sheet workflow (`add` / `update`) — track in PR description; does not change runtime payload. |
| `trigger` | **Where** to call the logger (ViewModel `onAppear`, tap handler, scroll callback, API completion). |
| `event_type` | Product taxonomy (`Impression`, `Click`, `Scroll`) — usually maps to payload `action` or documentation only. |
| `params_json` | **Authoritative parameter schema** for that row. |
| `condition` | **Guard** before logging (`guard` / `if`); must not be skipped. |
| `figma_node_id` | **Design anchor** for the exact frame/component where the event belongs (see next section). May list multiple nodes separated by `\|` when Plus vs Regular (or similar) differ. |
| `pm_approved` | **Gate:** implement only **`Approved`** rows for production. For `Pending`, generate stubs or a checklist and stop short of shipping. |

## `figma_node_id` → code placement

The sheet’s `figma_node_id` is the **primary locator** from spec → UI → Swift. Use it **together** with `trigger`; if they conflict, resolve with design/PM before shipping.

### Format rules (as exported from sheets)

- **Single node:** e.g. `10795:38:00` or `10015:46838` — Figma’s node id (fileKey comes from the feature’s Figma file URL).
- **Figma URL encoding:** In browser URLs, node ids often use `-` (e.g. `10795-3800`). For **Figma MCP / Dev Mode**, normalize to **`:`** between segments (replace the first `-` group separator pattern per Figma docs: typically `10795:38:00` style from `10795-38-00` in URL — match the project’s usual `fileKey` + `nodeId` convention).
- **Multiple nodes in one cell:** e.g. `10015:46838 (Plus) \| 10015:44148 (Regular)` — **variant-specific frames**; implement the same analytics row on **each** Swift surface that implements that variant (or one shared component if both variants use the same view). The parenthetical label is a hint for which user state maps to which build.
- **Empty / placeholder:** e.g. `(Research Team page — new static page to be built)` — no stable id yet; fall back to **`trigger` + `event_group`** and search the repo; leave a `// TODO(figma):` with the cell text for when the node exists.

### Agent resolution workflow (per CSV row)

1. **Read** `figma_node_id` + `trigger` + `event_group`.
2. **If a numeric/colon node id is present** and Figma MCP is available: call **`get_design_context`** (or equivalent) with **fileKey** from the user’s Figma link + **nodeId** from the row to load frame name, component names, and annotations. Use that to name the Swift screen (e.g. “Smart Picks listing” → grep module / `PView` / coordinator).
3. **If MCP is unavailable:** build a Figma deep link from the team’s file URL + node id for the user to open manually, then use **`trigger`** to `SemanticSearch` / `Grep` in `App/Module/<event_group>/` (or the path implied by the frame name).
4. **Place the log call** in the **same layer as other business logic** for that UI: prefer **ViewModel** `transform` / input handlers (PView pattern) or the coordinator callback that owns navigation — **not** raw SwiftUI `Button` actions when `ButtonView` wraps the control.
5. **Optional traceability:** In a dense PR, add a one-line comment above the call site: `// Analytics: CSV row — figma 10795:38:00` (only if the team wants file-level audit; otherwise the PR mapping table is enough).

### PR / checklist output

For each implemented row, record **`figma_node_id` → Swift file + symbol** (type / method) so QA and design can verify the correct control without diff archaeology.

## `params_json` interpretation

1. **Pipe-separated values** (`"crypto | us_stocks"`) — allowed set; log **exactly one** string matching app state. In Swift: nested `enum` with `String` raw values **equal to the CSV token** (snake_case as in sheet).
2. **Angle brackets** (`"<asset_symbol>"`, `"<depth_percentage>"`) — **runtime inputs**; become method parameters, a small `struct` argument, or merged dict keys built by the caller.
3. **Unquoted JSON types** — preserve `Bool` / `Int` in `[String: Any]` when the sheet uses JSON literals.
4. **Reserved words in quotes** (`"inherited"`, `"batch_page_id"`, `"initial_visibility_depth"`, `"generated_on_landing"`, `"retained_from_…"`) — **not** sent as literals to production unless PM confirms; map to real session id, measured depth, uuid lifecycle (document mapping in code comments next to `staticParams` or a private helper).
5. **`page_id` / `batch_page_id` / `access_state` gate:** If `params_json` lists **`page_id`**, **`batch_page_id`**, or **`access_state`**, **do not** silently invent values (e.g. random UUID, assumed `full_access` / `gated`). **Stop** and ask the user to either (a) **provide** how each key should be sourced / computed (with PM alignment), or (b) **explicitly skip** omitting the key from the app payload. Record the decision in the PR / code comment next to the event manager.
6. **Composite `value` fields** (e.g. `"<asset_symbol>,<signal_id>,<conviction_tag>"`) — one analytics string unless PM splits keys; build with a small formatter: `"\(symbol),\(id),\(tag)"`.
7. **Piped placeholders** (e.g. two uuid strategies) — **branch in code**; only one value in the outgoing dict per send.

## Keys registry

- **New parameter keys** — extend `EventMangerParam` in `EventManger.swift` when keys are stable and reused across calls (same pattern as `trade_page_landing`, `asset_symbol`, `event_name`).
- **Standard payload keys** (`action`, `action_tab`, `sub_tab`, `activity`, `value`, `page_title`, `asset_type`, `asset_symbol`, `UUID`) — **never** use string literals at ViewModel call sites. Inside the feature `EventManager`:
  - Map each key once via a private `PayloadKey` enum (or `EventMangerParam.<case>.rawValue` directly in `EventActionTab.params`).
  - Expose **`static func runtimeParams(subTab:value:assetType:assetSymbol:uuid:extra:)`** for call-site runtime fields (see `ExpertSignalsEventManager.runtimeParams`).
  - ViewModels pass only runtime values: `params: FeatureEventManager.runtimeParams(subTab: …, value: …, assetType: …)`.
- **`baseParams()` local dict** — initialize with `var baseParam: [String: Any] = [:]` and populate `baseParam[…]`; **do not** use terse names like `d` or `dict` in `baseParams()` (see `ExpertSignalsEventManager.baseParams()`).
- **`source` payload values** — key is `EventMangerParam.Source` (`"source"`). **Never** use string literals (`"qab"`, `"deep_link"`, `"expert_signal_landing"`, …) at call sites. Add a case to **`EventMangerSource`** in `EventManger.swift` (raw value = exact CSV token), then merge via the feature manager helper (e.g. `ExpertSignalsEventManager.sourceParams(.qab)`). Navigation / coordinators pass `EventMangerSource`, not `String` (e.g. `openSignalsV5List(..., landingSource: .qab)`).
- **New `event_name` / bucket values inside payload** — extend `EventMangerKeys` when the payload carries a nested `event_name` (see `TradePageEventManager` using `EventMangerKeys.trade_page_landing` / `trade_page_actions`).
- **New top-level CleverTap/Firebase event string** — must align with `trackWithDictAll(with: …)` first argument; often reuse `EventMangerParam.<case>.rawValue` for consistency with Trade Page.

Avoid duplicating user segmentation that `performTrackWithDictAll` already injects (`user_Type`, etc.) unless the CSV explicitly requires a different shape. For payloads that require CSV snake_case **`user_type`**, centralize it in the feature event manager (e.g. merge `userAccessParams` in one `track` helper) instead of repeating literals at every call site. **`access_state`** is **not** added by default — use the same **ask / skip** gate as `page_id` when the sheet requires it.

## Agent workflow: user attaches a CSV

Execute in order:

1. **Parse** all rows; normalize multiline `params_json` if the export breaks lines.
2. **Filter** to `pm_approved == Approved` (or list Pending rows separately as “not for prod”).
3. **`page_id` / `batch_page_id` / `access_state`:** If any approved row’s `params_json` includes these keys, **pause** and ask the user for sourcing / rules vs **skip** (omit key) before implementation; document in PR.
4. **Group** rows by `event_name`, then by `event_group` for file placement.
5. **Per group**, decide API surface:
   - **Landing-style** rows (e.g. `activity`: `page_land`) → dedicated `func <feature>Landing(...)` methods.
   - **Interaction rows** → nested enums similar to `EventActionTab` (`buttonClick`, `elementClick`, …) **or** a single method with a `enum Activity: String` if the sheet is flat and large.
6. **Emit Swift:**
   - `<Feature>EventManager.swift` in `App/Module/<Feature>/Event/` — **feature name only** (see [File and type naming](#file-and-type-naming-csv-spec-vs-swift)).
   - `final class <Feature>EventManager` with `static let shared` (mirror `TradePageEventManager`).
   - **`enum EventActionTab`** with nested `String` enums for closed CSV sets; each case exposes `var params: [String: Any]` for `action` / `action_tab` (see `TradePageEventManager.EventActionTab` / `ExpertSignalsEventManager.EventActionTab`).
   - **Per-bucket public methods** (e.g. `expertSignalActions(_ event: EventActionTab, …)`) — **no** public `track(bucket:params:)` from ViewModels.
   - Enums for every piped field used in more than one row (`SmartPicksListingActionTab`, `ExpertSignalSubTab`, …).
   - Private `PayloadKey` (or direct `EventMangerParam`) for dict keys; private `baseParams()` + private `send(bucket:event:params:source:)` calling `EventManger.shared.trackWithDictAll`.
   - `static func runtimeParams(...)` for ViewModel runtime fields (`sub_tab`, `value`, `asset_type`, `asset_symbol`, `uuid`).
   - `static func sourceParams(_ source: EventMangerSource)` when the CSV uses `source` — merge via optional `source:` on bucket methods, not string literals.
7. **Resolve placement** using `figma_node_id` (Figma context → screen name) **then** `trigger` (exact handler); wrap with `condition` from the sheet.
8. **Wire call sites** — one `FeatureEventManager` call per row after placement is confirmed.
9. **Register in Xcode** — add the file to `App.xcodeproj` / target membership.
10. **Verify** DEBUG toast / notification flags if using local event QA (`shouldShowLogsPopUp`).

## Scenario: “Drop CSV, implement full feature events”

**Goal:** Treat the CSV as the single spec so a future session can implement everything without re-reading Figma.

**Logic the agent must apply:**

```text
FOR each row R in CSV sorted by (event_group, event_name, trigger):
  IF R.pm_approved != "Approved" AND user did not ask to implement Pending:
    CONTINUE with comment-only stub or checklist item
  PARSE R.params_json → keys K
  FOR each key k in K:
    IF k IN {page_id, batch_page_id, access_state}:
      RESOLVE with user: sourcing / rules vs explicit OMIT; document in PR
    IF value contains "|" AND NOT placeholders:
      ENSURE Swift enum E_k with raw values == split tokens
    IF value matches "<...>":
      ENSURE caller passes value OR context provider supplies it
  MAP R.event_name → top_level_track_name (confirm with existing EventMangerParam / product)
  MAP R.figma_node_id → Figma frame (MCP or manual) → target Swift module / ViewModel / handler
  MAP R.condition → guard statement text in Swift above the log call
  MAP R.trigger → refine search within that module; inject ONE call to FeatureEventManager
```

**Deliverables per feature PR:**

- `<Feature>EventManager.swift` (pattern parity with `TradePageEventManager`).
- Minimal extensions to `EventMangerParam` / `EventMangerKeys` / `EventName` only when required.
- Call-site diffs tied to `trigger` text (ViewModels preferred; avoid SwiftUI `Button` — use `ButtonView` per project rules).
- Short mapping table in PR description: **`figma_node_id`** + CSV `event_name` + `activity` → Swift file + method / enum case.

## Anti-patterns

- **Prefixing Swift files/types with the spreadsheet export name or workbook title** — use `<Feature>EventManager` only.
- **`"source": "qab"` / `"deep_link"` string literals** — add `EventMangerSource` case + `sourceParams(_:)`; use `EventMangerParam.Source` for the key only inside the helper.
- **Hand-building `action` / `action_tab` in ViewModels** — use `EventActionTab` + `featureEventManager.expertSignalActions(.buttonClick(.listing(…)), params: …)` (see `TradePageEventManager.tradePageAction`).
- **`"sub_tab"`, `"asset_type"`, `"value"` string literals in `params:` dicts** — use `FeatureEventManager.runtimeParams(...)` or `EventMangerParam.<case>.rawValue` inside the event manager only.
- **`var d:` / `var dict:` in `baseParams()`** — use `var baseParam: [String: Any] = [:]` instead.
- **Public `track(bucket:params:)` on feature EventManagers** — keep `send` private; expose typed bucket methods only.
- Guessing call sites from `trigger` alone when `figma_node_id` is present — always cross-check the frame in Figma (or MCP) before wiring.
- Calling `trackWithDictAll` directly from SwiftUI views for feature-specific events.
- Hard-coding pipe lists as loose `String` without enums when the CSV defines a closed set.
- Ignoring `condition` or sending `Pending` spec to production analytics.
- Using different snake_case than `params_json` keys unless an existing `EventMangerParam` case intentionally differs (prefer alignment with the sheet).

## Quick diff vs Trade Page

| Concern | Trade Page reference | Expert Signals reference |
|--------|----------------------|---------------------------|
| Top-level event name | `trackWithDictAll(with: EventMangerParam.trade_page_actions.rawValue, …)` | `send(bucket: .expert_signal_actions, …)` → `bucket.rawValue` |
| Payload `event_name` | `EventMangerKeys.trade_page_actions` in dict | `bucket.rawValue` in dict |
| Typed actions | `tradePageAction(.buttonClick(.miniExplore), params: ["value": x])` | `expertSignalActions(.elementClick(.listing(…)), params: […])` |
| `action` + `action_tab` | From `EventActionTab.params` only | Same — never set in ViewModel dicts |
| `source` | String param on landing (legacy) | `EventMangerSource` + optional `source:` on bucket methods |
| Merge order | `staticParams()` → `eventActionTab.params` → caller `params` | `baseParams()` → `event.params` → caller `params` → `source?` → `userAccessParams` |

When in doubt, open `TradePageEventManager.swift` and `ExpertSignalsEventManager.swift`; copy the **EventActionTab + per-bucket method** shape, then map CSV tokens to nested enum cases.
