---
name: decodable-migrator
description: >-
  Migrates existing Swift Codable models to AppMacros `@Decodable` so synthesized
  decoding replaces manual `CodingKeys`, `init(from:)`, and redundant boilerplate.
  Use when refactoring Decodable structs, converting legacy decode implementations,
  or matching `WalletOverviewData`-style macro usage. Ask which model to migrate first
  and whether to include nested child models before changing code. Builds the affected
  target and fixes compile errors after changes; clarify with the user when migration
  steps are ambiguous.
---

# Decodable macro migrator (AppMacros)

Migrate hand-written `Decodable` types to `@Decodable` / `@Decodable()` from `AppMacros` so the macro expands decoding logic instead of maintaining `enum CodingKeys` and `init(from decoder: Decoder)`.

## Agent behavior

### Before any edits (mandatory)

1. **Which model first?** Do **not** start migrating until the user names the **exact type** (and ideally file path) to migrate first — e.g. `WalletOverviewData` in `WalletOverviewData.swift`. If they only point at a file, confirm which `struct`/`enum` in that file is the first target.

2. **Child / nested models?** After inspecting that type, if it has **nested decoded types** in the same file or strongly coupled child structs used only as properties (child models in the migration sense), **ask again**:
   - Whether to migrate **only** the user-chosen root/parent type in this pass, **or**
   - Whether to **also** migrate the nested child types (same session, typically inside-out: children before or with parent per steps below).

   If the user opts **out** of child migration, leave children on manual `Decodable` / existing pattern until they ask to migrate those types separately.

3. Only after (1) and, when applicable, (2) are answered, proceed with file changes.

### During the migration

- **Ask the user** whenever a step is unclear (ambiguous JSON shape vs property types, conflicting patterns in the same file, whether defaults should stay vs become optionals, macro unsupported cases, etc.). Do not guess past reasonable inference.
- After each substantive change set, **build the relevant Xcode target** for the touched files (typically the main app workspace/scheme used for daily development — e.g. `App.xcworkspace` / the scheme that includes the app and **`AppMacros`**), **resolve all compiler errors** before moving on or declaring the migration done.

## Canonical examples in this repo

- **Macro style with nested types and memberwise inits**: `App/Module/Wallet/WalletView/Service/Models/WalletOverviewData.swift`
- **Legacy pattern to migrate away from**: manual `CodingKeys` + `init(from:)` with `decodeIfPresent` and defaults — e.g. `App/Module/Wallet/WalletView/Service/Models/IDRWalletBalancesData.swift`

For **new** API models from JSON, prefer workflow and attribute rules in [.cursor/skills/new-feature/api-integration/SKILL.md](../new-feature/api-integration/SKILL.md) (`@CodingKey`, `@DefaultValue`, optionals).

## What the migration replaces

For each type where the macro applies, you can **remove** when they only duplicate what synthesis (or the macro) already provides:

- `enum CodingKeys: String, CodingKey` that only lists properties 1:1 with JSON keys matching property names
- `init(from decoder: Decoder) throws` that only decodes keys into stored properties with no extra rules

The macro (with project conventions) is intended to cover that same ground, similar to relying on compiler-synthesized `Decodable` but with project-specific extensions (e.g. key mapping attributes — see api-integration skill).

## Preconditions

1. Target type must live in a target that already links **`AppMacros`** (same as `WalletOverviewData`).
2. Add at the top of the file if missing:

   ```swift
   import AppMacros
   ```

3. Apply the macro **per type** that should use generated decoding in this session — the root (and **each** nested `struct` that was `Decodable` **only if** the user agreed to migrate children in **Before any edits**).

## Attribute style (match the file you touch)

This codebase uses both forms; **stay consistent within the file**:

- `@Decodable` on the root struct (see `WalletOverviewData`)
- `@Decodable()` on nested structs

If the surrounding module already standardized on only `@Decodable()`, follow that instead.

Keep or drop explicit `: Decodable` to match nearby models in the same module (root `WalletOverviewData` keeps `struct X: Decodable`).

## Migration steps

Scope each session to what the user confirmed in **Before any edits**: only the named type, or the named type plus agreed nested types. If the user chose **parent only**, do not add `@Decodable` to nested children they excluded.

Work **one struct at a time**, inside-out for nested types **when the user agreed to migrate children** (migrate leaves first so parent decoders still see macro-enabled children). If only the parent is in scope, migrate that type alone and leave nested types unchanged.

1. **Classify `init(from:)`**
   - **A — Trivial**: only `decode` / `decodeIfPresent` assignments, keys match property names, no transforms. → Safe to delete `init(from:)` and `CodingKeys` after adding `@Decodable` / `@Decodable()`.
   - **B — Defaults**: uses `??` for non-optional properties (e.g. missing JSON → `"-"` or `[:]`). → Do **not** delete until you encode those rules using supported macro features (e.g. `@DefaultValue` if the team uses it — see api-integration skill) **or** keep a **minimal** custom decode path if the macro cannot express it.
   - **C — Non-trivial**: date formats, unknown keys iteration, conditional branches, flattening nested JSON, `try` custom containers. → **Do not migrate** that type with a blind delete; leave manual `Decodable` or split into smaller DTO + mapping.

2. **Classify `CodingKeys`**
   - Only cases that match Swift property names → remove with the manual `init(from:)` once the macro is applied.
   - JSON name ≠ Swift name → remove `CodingKeys` and use **`@CodingKey("json_key")`** on the property (per api-integration skill).

3. **Apply the macro** above each migrated `struct`.

4. **Memberwise initializers**
   - If the type keeps `init(...)` for previews/tests/manual construction (like `WalletOverviewData`), **retain** them. The macro generates decoding; memberwise `init` is separate (same pattern as existing wallet models).

5. **Enums / protocols / classes**
   - If the type is `enum ... Decodable`, generic wrappers, or uses inheritance quirks, **verify** the macro supports it before stripping manual decoding; fallback to manual conformance when unsure.

6. **Build, fix errors, then decode check**
   - Run a full compile of the app target(s) affected by the model file; **fix every build error** the migration introduces (missing imports, macro expansion issues, duplicated `Decodable`, wrong nested attributes) until the scheme builds cleanly.
   - If possible, decode a **real or fixture JSON** used by tests or the feature and confirm defaults and optional handling match **before** removing branches from `init(from:)`.

## Quick decision table

| Situation | Action |
|-----------|--------|
| Straight property decode, keys match names | `@Decodable` / `@Decodable()`, delete `CodingKeys` + `init(from:)` |
| Rename JSON key only | `@CodingKey("...")`, macro on type, drop custom `CodingKeys` if redundant |
| Default when key missing | `@DefaultValue` (if project uses) or keep custom `init(from:)` |
| Complex logic in `init(from:)` | Keep manual decoding or refactor to DTO + mapper |

## What NOT to do

- Do not strip `init(from:)` until behavior is preserved (defaults and optionals).
- Do not migrate types you cannot compile-test in this branch.
- Do not contradict module conventions documented in [.cursor/skills/new-feature/api-integration/SKILL.md](../new-feature/api-integration/SKILL.md) for **new** models (optionals, nesting under `data`, etc.); migrator focus is **existing** types.

## Verification checklist

- [ ] `import AppMacros` present
- [ ] Every nested decoded struct that lost manual `init(from:)` has `@Decodable()` (or file-consistent variant)
- [ ] No orphaned `CodingKeys` enums
- [ ] **Project/target builds with zero compile errors** from this migration
- [ ] Decoding smoke-tested where fixtures exist
