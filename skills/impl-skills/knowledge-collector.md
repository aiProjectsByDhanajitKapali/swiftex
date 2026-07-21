---
name: knowledge-collector
description: >-
  Collects app feature or screen knowledge from the repo and writes **one**
  repo-local **technical** Markdown document: **full flow** (root PView + child VMs,
  coordinators, ScreenObjectMapper pushes, interactors, **API** services/endpoints
  used by the flow), not only a single file. Same gated UX as
  export-prompt-history:
  always questions first (GATE 1 then GATE 2; AskQuestion when discrete); if
  uncleared, reply **Gate not cleared** + labeled GATE question; no repo tooling until
  gates clear; then discovers, creates the knowledge subfolder if needed, then writes
  the .md. Use when documenting a feature for Cursor, capturing screen context,
  building a knowledge base entry, or saying run this skill / knowledge-collector.
  Optional inline invocation: `on`/`for` title clears GATE 1; `of <path>` anchors scope (see skill).
owner: Ram Sharma
disable-model-invocation: true
---

# Knowledge collector (gated technical doc)

Produce **one** focused **technical** Markdown document under [`.cursor/knowledge/`](../../../knowledge/)—repo-local reference for engineers and agents. Cover the **full flow**: root `PView` / hosting entry, **child** view models surfaced in `Output`, **coordinator** routes and tab/app navigation, **interactors**, and **network** layer (service types + key endpoints) tied to the feature—not only the single file the user might @mention. **Gates** collect the **feature or screen name** and **repo scope** before any discovery or writes — same rhythm as [export-prompt-history](../export-prompt-history/SKILL.md) (mandatory questions, **Cursor UX** / **already satisfied** per gate). After **GATE 1** and **GATE 2** clear (and **GATE 3** when needed): **discover** (read-only), **create** `.cursor/knowledge/<ModuleOrArea>/` if missing, **write** the agreed `.md` only.

## Suggested invocation (optional)

Users may pass the **screen or feature name** on the same line as the skill mention so **GATE 1** clears without a follow-up. Examples (paths are illustrative):

- `@.cursor/skills/documentation/knowledge-collector/ on Home Screen` — supplies the **doc title** only; agent proceeds to **GATE 2** (scope) unless scope is also in the message.
- `@.cursor/skills/documentation/knowledge-collector/ for USDT margin detail` — same pattern with **`for`** instead of **`on`**.
- `@.cursor/skills/documentation/knowledge-collector/ on Home Screen — scope App/Module/HomeV5/HomeScreenView` — **title + scope** in one message.
- `@.cursor/skills/documentation/knowledge-collector/ of App/Module/HomeV5/HomeScreenView/View/HomeScreenView.swift` — **primary file anchor**; treat **GATE 2** as the **parent feature folder** (e.g. `…/HomeScreenView`) unless the user specifies otherwise. For **GATE 1** (doc title), use a user-supplied phrase such as **`on Home Screen`** in the same or previous message, or derive a neutral title from the type name (e.g. `HomeScreenView`) and offer one-line rename—prefer explicit **on …** for product names like **Home Screen**.

Treat text after **`on`** / **`for`** (trimmed) as the verbatim **feature or screen title intent** when it is a single clear phrase; if ambiguous, use **GATE 3**.

### Full flow (required depth)

The written `.md` must document the **end-to-end technical flow** for that screen/feature, including where reasonable under scope:

| Area | Include |
|------|--------|
| **UI** | Root `PView` / `UIViewController`, major child views (by file + role). |
| **State** | Root `ViewModel` (`transform`, interactors), **each** child VM exposed on `Output`, `*+IO.swift` paths. |
| **Navigation** | Coordinators (`route`, pages enum), `ScreenObjectMapper` / tab pushes relevant to the flow. |
| **Data / API** | Service types (e.g. façade `*NetworkService`), protocols, and **representative** `*EndPoint` / paths used by VMs in this flow (table or bullet list—not full dump). |
| **Side channels** | Important `NotificationCenter` names, sockets, managers if central. |

If the user names only one file, still **expand** discovery to the **folder** and **shared** services the flow uses.

## Before any gate clears (global)

Until **GATE 1** (feature or screen name) **and** **GATE 2** (scope) are satisfied — and **GATE 3** when ambiguity applies — **do not**:

- Run **`codebase_search`**, **`grep`**, or **reads under `App/`** for discovery (exception: **one** minimal lookup under **GATE 2** only when the user says they are **unsure** of scope, to propose a single path — not full discovery).
- Create directories under **`.cursor/knowledge/`** or write or update any file there.
- Infer missing name or scope by exploring the repo; treat `@knowledge-collector`, `@.cursor/skills/documentation/knowledge-collector/`, “run this skill”, etc. with **no** feature name, **no** **`on`/`for`** inline title, and **no** **`of <path>`** / `@App/...` file anchor (see **Suggested invocation**) as **gate not cleared** and respond using **Reply format when gate is not cleared** below.

Treat “run this skill”, `@knowledge-collector`, or similar with **no** feature title and **no** path anchor as **gate not cleared** — stop and ask **in gate form**.

### Gate protocol (mandatory)

- **Questions are the gate.** Clear gates **only by asking** the user — not by searching or reading the repo “to decide what to document.”
- **When the gate is not cleared,** your user-facing reply **must** ask the next question **as the gate**: use **Reply format when gate is not cleared** below. Do not reply with only informal prose, tangents, or “next I will…” — the **labeled gate + exact question** is the body of the reply (plus optional one-line context).
- **Order:** Satisfy **GATE 1** before **GATE 2**. In one assistant turn, ask **only** the next uncleared gate (or the single missing piece if the user already supplied part of a gate). Do **not** bundle GATE 1 and GATE 2 in the same message unless the user’s message already answered one and you **only** lack the other.
- **GATE 1–only replies:** When you are asking **only** GATE 1 (name missing), you may add **one** optional neutral line (e.g. “Reply when ready.”). Do **not** quote, paraphrase, or preview the **GATE 2** question or example path in that same assistant message — wait until GATE 1 clears, then ask GATE 2.
- **Pre-gate tooling (recap):** No **`codebase_search`**, **`grep`**, or **`App/`** reads for discovery; no `.cursor/knowledge/` writes. **Exception (GATE 2 only):** User **unsure** of scope → **one** minimal search to propose **one** path; present as proposal; wait for **yes** or a corrected path — **not** discovery and must not broaden into scanning the tree.

### Reply format when gate is not cleared

Use this shape so the user always sees **which gate** is blocking and **what to answer**:

```markdown
**Gate not cleared**

**GATE N — Short title from sections below**

Exact gate question as specified for that GATE (include the GATE 2 example path only when asking GATE 2 in chat).
```

- **GATE 1 title:** Feature or screen name — question: *What screen or feature should I document?*
- **GATE 2 title:** Scope (repo root for this doc) — question: *Which folder or module should I treat as the root for discovery?* (include the example path line from **Gate 2** when using chat.)
- **GATE 3:** **Gate not cleared** then **GATE 3 — Ambiguity** and either **`AskQuestion`** options or a numbered list.

Do **not** omit the **Gate not cleared** line when any of GATE 1–3 is still blocking. After all gates clear, do **not** use this header for normal discovery updates unless the user re-opens ambiguity.

When the **only** missing gate is **GATE 1**, the reply body is **only** the GATE 1 block (plus one optional neutral line per **Gate protocol**); do **not** include the GATE 2 question in that reply.

---

## Gate 1 — Feature or screen name (mandatory — block knowledge write)

Until the **feature or screen name** is confirmed, **do not**:

- Ask **GATE 2** in the same assistant turn unless the user’s message already supplied the name and you **only** lack scope.
- Use repo tooling to “pick” a feature on the user’s behalf (see **Before any gate clears (global)**).

### Cursor UX — prefer AskQuestion when available

- **Default:** Free text — use **one blocking chat question** with **exactly** this wording: *What screen or feature should I document?* wrapped in the **Reply format when gate is not cleared** (title **GATE 1 — Feature or screen name**).
- **`AskQuestion`:** Use only when you have **real discrete choices** (e.g. the user or context already listed a small set of features). Do **not** invent fake multiple-choice.
- If **`AskQuestion`** is unavailable or skipped, use the chat question + reply format above.

### Gate 1 already satisfied

If the user’s message already contains a clear **feature or screen name** you will use verbatim in the doc title and slug, **do not** re-ask GATE 1; proceed to GATE 2 (or confirm under **Narrow exception** if both name and scope appeared in the **first** message).

- **Inline after the skill mention:** If the message includes this skill (or `@knowledge-collector`) **and** a clear trailing phrase **`on <Feature>`** or **`for <Feature>`** (case-insensitive keyword, one phrase), treat **`<Feature>`** (trimmed) as the **name** for GATE 1 and **do not** re-ask GATE 1. If the same message also includes an explicit scope tail (e.g. `— scope <path>` or `scope: <path>`), use **`<path>`** for GATE 2 and keep **`on`/`for`** text for the name only.
- **Primary file anchor (`of` / `@App/`):** If the message includes **`of`** (or a workspace file ref) followed by a **repo path** to a `.swift` (or similar) file under `App/`, treat **GATE 2** as the **smallest feature folder** that owns that file (typically the directory named after the feature, e.g. `…/HomeScreenView` for `…/HomeScreenView/View/…swift`). Treat **GATE 1** as cleared only when the user also supplies a **doc title** via **`on <Title>`** / **`for <Title>`** in the same thread, **or** you restate a default title from the type name and the user confirms (see **Narrow exception**). Prefer the user’s product name (e.g. **Home Screen**) when they state it.

**Satisfied when:** The user gives that **name** (initial message **or** reply, including **`on` / `for`** inline per **Suggested invocation**, or confirmed title with path anchor per above).

---

## Gate 2 — Scope (repo root for this doc) (mandatory — block knowledge write)

Until **GATE 1** is cleared **and** a **scope** is confirmed (folder/module path, **yes** to your single proposal, or agreed **entire `Module/X` overview**), **do not**:

- Run broad discovery or create/update anything under **`.cursor/knowledge/`** (see **Before any gate clears (global)**).
- Ask GATE 2 before GATE 1 is satisfied.

### Cursor UX — prefer AskQuestion when available

- **After GATE 1 is cleared**, ask with **one blocking chat question** using **exactly**: *Which folder or module should I treat as the root for discovery?* (Example: `App/Module/Wallet/CryptoWallet`.) Use the **Reply format when gate is not cleared** (title **GATE 2 — Scope (repo root for this doc)**).
- **`AskQuestion`:** Use when you have **two or more concrete folder/module options** (e.g. two plausible roots, or user must pick between your proposed path and an alternative they named).
- **If the user is unsure of scope:** You may do **one** minimal search to propose a **single** best path (see **Before any gate clears (global)**); restate it and wait for **yes** or a corrected path before broad exploration.
- If **`AskQuestion`** is unavailable or skipped, use the chat question + reply format above.

### Gate 2 already satisfied

If the user’s message (with GATE 1 already satisfied) already gives a **folder or module path**, **yes** to your prior single proposal, or an explicit **entire `Module/X` overview** with `X` agreed, **do not** re-ask GATE 2.

**Satisfied when:** Path, **yes** to proposal, or agreed module overview as above.

---

## Gate 3 — Ambiguity (mandatory — block discovery when ambiguous)

When the **name** could refer to **multiple unrelated** areas under the agreed scope (or before scope is tight enough), until the user picks **one** focus, **do not**:

- Begin **discovery** for the knowledge doc (see **Before any gate clears (global)**).

### Cursor UX — prefer AskQuestion when available

- Prefer **`AskQuestion`** when choices are discrete.
- Otherwise use a short **numbered list in chat** and wait for **one** picked focus.
- If **`AskQuestion`** is unavailable, use the numbered list in chat.

### Gate 3 already satisfied

If the name maps to **one** clear area or the user’s reply disambiguated, **do not** run GATE 3.

**Satisfied when:** User picks one area / path.

---

## Narrow exception (first message has both name and scope)

If the user’s **first** message already states an unambiguous **feature or screen name** **and** **scope** (path, `— scope …`, “entire `Module/X` overview”, **or** a primary file path anchor per **Suggested invocation** from which you derive scope), restate both **title** and **discovery root** verbatim once and **wait for explicit confirmation** (e.g. “yes”, “correct”, or approval in Plan mode). Do **not** treat silence or lack of objection as confirmation. After the user confirms and it is still unambiguous, proceed **without** re-asking GATE 1–2.

| Gate | Question / rule | Cleared when |
|------|-----------------|--------------|
| **1** | *What screen or feature should I document?* | Name received (verbatim use). |
| **2** | *Which folder or module should I treat as the root for discovery?* | Path or **yes** to your single proposal, or agreed module overview. |
| **3** | Multiple matches | User picks one area / path. |

## After the gate (workflow)

1. **Discover (read-only)** — Under agreed scope, follow **Discovery steps** below. Do not create or edit anything under `.cursor/knowledge/` during discovery.
2. **Create knowledge folder** — Ensure **`.cursor/knowledge/<ModuleOrArea>/`** exists (see **Conventions**).
3. **Write** — **`.cursor/knowledge/<ModuleOrArea>/<feature-slug>.md`** using the template below.

## Conventions

- **Output path:** `.cursor/knowledge/<ModuleOrArea>/<feature-slug>.md`
  - **Folder:** `.cursor/knowledge/<ModuleOrArea>/` must exist before the file is written; **create it** if missing.
  - `<ModuleOrArea>`: default from `App/Module/<Name>/` → use `<Name>` (e.g. `Wallet`). For cross-cutting flows use `cross-cutting` **only** if the user confirms.
  - `<feature-slug>`: lowercase, hyphenated ASCII (e.g. `usdt-margin-detail`).
- **One doc per invocation** unless the user explicitly asked for a **module overview** (then one overview file; link out to future slugs as TODOs).
- Respect [`.cursorrules`](../../../../.cursorrules) when describing patterns (PView, `ButtonView`, `+IO` beside view, coordinators, `ScreenObjectMapper`).

## Discovery steps (read-only)

Gather facts for the **technical document** (accurate paths, roles, navigation). After the **gate** is cleared, perform discovery **before** creating the knowledge folder and writing the file (**After the gate** workflow steps **1** then **2–3**).

1. **Navigation:** Search for `*Coordinator*`, `ScreenObjectMapper`, `PModuleFactory`, `route(to`, tab / hosting setup (`BasePViewModelHostingController`, `mainTabBarController`), storyboard instantiate strings tied to the feature.
2. **UI:** Locate main `PView` / SwiftUI `View` / `UIViewController` entry files; list **child** views embedded in the root body (file + role).
3. **State:** Root `ViewModel` (`transform`, internal subjects), **child** VMs passed into `Output`, `*+IO.swift` (`Input` / `Output`); interactors used by the root VM.
4. **Data / API:** Service façade(s) and protocols used by VMs in scope; grep or open `*EndPoint` / `NW.request` usage and summarize **key HTTP paths** in a small table. Interactors, sockets, `NotificationCenter` names, `EventManger` keys if central.
5. **Interface Builder:** If `customClass`, segue IDs, or nib names appear for this flow, add a short **IB** subsection.
6. **Cross-links:** Other docs under `.cursor/knowledge/` that overlap (relative links).

Deep patterns: read [`../../architecture-reference/pview-io-pattern/SKILL.md`](../../architecture-reference/pview-io-pattern/SKILL.md) and [`../../new-feature/create-coordinator/SKILL.md`](../../new-feature/create-coordinator/SKILL.md) when navigation or coordinator code is unclear.

## Output: write exactly this structure

The file is **technical documentation**: factual, structured, concise; prefer tables and bullets over narrative fluff; no marketing language.

Create parent dirs under `.cursor/knowledge/` as needed (at minimum **`<ModuleOrArea>/`** for the new `.md`). Use **today’s date** from the environment for **Last updated**.

```markdown
# <Feature or screen title>

**Last updated:** YYYY-MM-DD  
**Scope:** <path or module>  
**Summary:** <one or two sentences>

## User-visible entry points

- <tab, deeplink, settings row, etc.>

## Navigation

<!-- Prefer bullets; optional mermaid flowchart if it stays small -->

- <e.g. CoordinatorX → push → SomeHostingController>

## Primary files

| Path (from repo root) | Role |
|----------------------|------|
| App/... | ... |

## View models and I/O

- **ViewModel:** …
- **Input / Output:** … (file path to `+IO`)

## Key user actions

- <action → brief outcome / side effect>

## Dependencies

- <other modules, managers, packages>

## API surface (if applicable)

| Endpoint / path (relative to base) | Used for (caller / VM area) |
|-----------------------------------|----------------------------|
| … | … |

## Interface Builder (if applicable)

- <storyboard/xib + what they host>

## Related knowledge

- [Other doc](../ModuleOrArea/other-slug.md)

## Notes for agents

- <pitfalls, threading, feature flags>
```

## After writing

- Tell the user the **exact path** of the new file (and confirm the **folder** under `.cursor/knowledge/<ModuleOrArea>/` was created if it was new).
- Remind: commit knowledge with the **feature PR** when behavior changes, or as a small docs-only PR.

## Out of scope (v1)

- No edits to `App/` or `App.xcodeproj` as part of this skill.
- Do not paste full Figma or large API payloads; link or name only.
