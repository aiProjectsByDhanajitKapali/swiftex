---
name: swiftui-missing-accessibility-ids
description: Adds stable accessibilityIdentifier to SwiftUI views missing them (without changing existing ids) and, when writing XCUITest, places tests in a dedicated UI test file for that screen if none exists, or updates the existing UI test file. Use for view ids, UI test prep, or UI test implementation.
disable-model-invocation: true
---

# SwiftUI: add missing view identifiers

## Goal

1. For SwiftUI `View` code, ensure user-visible and test-relevant elements expose a **stable string identifier** for UI automation. In SwiftUI this is **`.accessibilityIdentifier("...")`**. Do **not** add or change identifiers on any view that **already** has `.accessibilityIdentifier` (or a project-specific equivalent if the repo standardizes on a wrapper like `viewId(_:)` that sets the same underlying API—treat those as “already has id”).

2. When **adding or editing UI tests** (XCUITest), use **one UI test file per screen or feature** when no file exists yet; otherwise **extend the existing** UI test file for that screen. Do **not** duplicate parallel test classes for the same screen unless the project already does.

Do **not** use `.id(...)` for UI automation unless the project explicitly maps `.id` to XCUITest; prefer **`accessibilityIdentifier`**.

## Preconditions

1. Identify target SwiftUI files (single screen, feature folder, or whole module).
2. Follow existing naming patterns if present (e.g. `screen_element_action`, `login_submit_button`).
3. If ambiguous, prefer short, unique, stable keys: `content_kyc_status_label`, `settings_save_button`.

## Workflow

```text
View id progress
- [ ] Step 1: Read target SwiftUI file(s) and list views that need automation ids
- [ ] Step 2: For each candidate view, skip if it already has accessibilityIdentifier (or project wrapper)
- [ ] Step 3: Append .accessibilityIdentifier("unique_key") only to views missing it
- [ ] Step 4: Build the app target
- [ ] Step 5 (when UI tests are in scope): Follow “UI tests: file placement”, then add or update tests
- [ ] Step 6 (when UI tests are in scope): Enforce identifier/assertion parity (no missing id checks)
- [ ] Step 7: Run UI tests or smallest relevant test subset; fix failures
```

Skip Step 5–7 when the user only asked for identifiers with no UI tests.

## Step 1: What gets an identifier

Typically add identifiers for:

- `Button`, `NavigationLink`, toggles, pickers, `TextField`, `SecureField`
- `Text` that represents dynamic state shown to the user (counts, status strings)
- Distinct `Image` icons that are tappable or meaningful in UI tests
- Containers only when needed for disambiguation (prefer leaf controls first)

Skip:

- Pure layout-only wrappers (`Spacer`, invisible stacks) unless tests must target them
- Previews (`#Preview`) unless explicitly requested

## Step 2: Detect “already has id”

**Do not modify** a view subtree when:

- The view chain already applies `.accessibilityIdentifier(`…`)` on that element **or** on an outer modifier that clearly targets the same control the test will query (usually the innermost interactive view).

- The project uses a custom modifier; grep for `accessibilityIdentifier` and any `extension View` helpers before adding duplicate layers.

If unsure whether an outer modifier covers an inner `Text`, prefer adding the identifier on the **same view** the user interacts with or reads.

## Step 3: Apply identifiers

- Use **one identifier per logical UI element**; keys must be unique within the screen for stable XCTest queries.
- Prefer lowercase snake_case or camelCase to match the codebase.
- Append modifiers at the natural chaining position used in the file.

Example (before → after pattern only):

```swift
Text("Hello")
// becomes (only when missing identifier)
Text("Hello")
    .accessibilityIdentifier("greeting_label")
```

Never replace existing keys:

```swift
Text("Hello").accessibilityIdentifier("existing_key") // leave unchanged
```

## Step 4: Validate (app build)

- Build the app target after identifier changes.

## UI tests: file placement (XCUITest)

When implementing or extending **UI** tests for a screen (e.g. `ContentView.swift`):

1. **Discover** existing UI tests for that screen **before** adding a new file:
   - Search the UI test target folders (`*UITests`, `UITests/`) for the screen name, root view name (e.g. `ContentView`), or accessibility identifiers already used for that flow.
   - Look for an `XCTestCase` subclass named like `<Screen>UITests`, `<Feature>UITests`, or tests grouped in a file clearly scoped to that screen.

2. **If a matching UI test file/class exists**: **Update it** — add new test methods or refine queries using `accessibilityIdentifier`. Do **not** create a second file for the same screen unless the project already splits tests that way.

3. **If none exists**: **Create a new Swift file** in the UI test target, e.g. `ContentViewUITests.swift`, with `final class ContentViewUITests: XCTestCase`. Use `XCUIApplication()`, `app.launch()`, and `app.otherElements["id"]` / `app.staticTexts["id"]` etc. matching the identifiers from the SwiftUI views.

4. **Wire the file into the UI test target**: for Xcode **folder-synchronized** groups, placing the file under the UI test folder is enough; otherwise ensure membership in the UI test target (`project.pbxproj`).

5. In the final report, state whether UI tests were **added to an existing file** or **new UI test file created**.

Query elements by **`accessibilityIdentifier`** strings (use `identifier` in predicates or element queries as appropriate for the element type).

## Step 6: Identifier/assertion parity (required)

When UI tests are in scope, do not finish until test assertions are synchronized with identifiers in the target screen:

1. Build an **identifier inventory** from the target SwiftUI file(s): every `accessibilityIdentifier("...")` value that belongs to user-visible/test-relevant elements.
2. Build an **assertion inventory** from the related UI test file/class: every identifier referenced in `app.*["id"]`, `.matching(identifier:)`, predicates, and helper methods.
3. Ensure **coverage parity**:
   - Every relevant identifier from views is asserted at least once in the UI tests.
   - New identifiers added in this change are always asserted in the same update.
4. If an identifier is intentionally excluded from assertions, document why in the final report.

Minimum expectation for a screen-level presence test: assert all screen identifiers that represent visible state/controls (status, key values, buttons, text fields, toggles).

## Step 7: UI tests and run

- Prefer `@MainActor` on UI test methods if using Swift concurrency patterns the project requires.
- Run the UI test scheme (`xcodebuild test` with UI test destination, or Xcode Test). If CoreSimulator clone errors occur, use a fixed simulator UDID and `-parallel-testing-enabled NO`.

## Quality bar

- No duplicate identifiers on the same screen for distinct elements.
- No edits to views that already had an identifier.
- Identifiers stable across trivial refactors (string content can change; id should not).
- UI tests live in **one logical file per screen** unless the repo dictates otherwise; no duplicate UI test files for the same screen without cause.
- No missing UI assertions for newly added relevant identifiers (identifier/assertion parity maintained).

## Quick invocation

- "Use `swiftui-missing-accessibility-ids` on `test_app/ContentView.swift`."
- "Add missing accessibility identifiers in `Features/Profile/` and UI tests for that screen."
- "Identifiers only for `LoginView.swift` — no UI tests."
