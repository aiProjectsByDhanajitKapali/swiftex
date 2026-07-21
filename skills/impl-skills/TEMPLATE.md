# Thread audit — [short scope or feature name]

## Metadata

| Field | Value |
| --- | --- |
| **Date** | YYYY-MM-DD |
| **Scope** | Branch, PR link, or ticket |
| **Files reviewed** | List paths or “see Proposals” |

## Summary

One short paragraph: overall risk, main themes (e.g. missing `setPublished`, UI off main).

---

## Proposals

Each proposal is independently **Accept** or **Reject**. Only **Accepted** items should appear in the implementation prompt below.

### PROP-001 — [short title]

- **File:** `path/to/File.swift`
- **Region:** Symbol name or approximate line range
- **Rule / checklist:** e.g. Output → `setPublished`; main thread for coordinator
- **Finding:** What is wrong today (fact-based).
- **Proposed change:** Concrete edit (steps, pseudocode, or snippet—not vague “fix threading”).

**Decision:** [ ] Accept [ ] Reject

---

### PROP-002 — [short title]

- **File:** `path/to/File.swift`
- **Region:**
- **Rule / checklist:**
- **Finding:**
- **Proposed change:**

**Decision:** [ ] Accept [ ] Reject

---

_(Add more `PROP-*` blocks as needed.)_

---

## Checklist trace (optional)

Map skill checklist rows to PROP ids or “none”:

| Checklist item | PROP ids / notes |
| --- | --- |
| Non-trivial work off main | |
| Output via `setPublished` | |
| Input `.receive(on: DispatchQueue.global())` | |
| Toast / coordinator / VC on main | |
| No redundant main around safe helpers | |

---

## Implementation prompt

**After** marking **Accept** / **Reject** on each proposal above, fill this section (or replace it in a follow-up chat). Include **only** proposals marked **Accept**.

```text
Implement threading fixes per `.cursor/skills/code-review/thread-handling/SKILL.md` (Mode 2 — implementation guide).

Audit artifact: `.cursor/skills/project-ops/thread-audits/[THIS_FILENAME].md`

Apply **only** these accepted proposals (do not implement any proposal marked Reject in that file):

- PROP-___: [one-line summary]
- PROP-___: [one-line summary]

Constraints:
- Follow existing patterns in the touched files; no unrelated refactors.
- Re-verify against the Mode 1 checklist after edits.
```

If you prefer, open a **new** Composer chat and paste the filled block above—optionally `@`-mention the audit file and the touched Swift files.
