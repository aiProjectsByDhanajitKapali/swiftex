---
name: pre-commit-staged
description: >-
  Fast pre-commit checks on staged Swift files only (SwiftLint + ui-component-usage
  script). No full LLM review. Use before commit or to debug hook failures.
owner: Ram Sharma
---

# Pre-commit staged checks (fast)

## Goal

Run **deterministic** checks on **staged** `.swift` files in seconds. Do **not** load full **ios-code-review**, **architecture-review**, **thread-handling**, or **xcodebuild** unless the user explicitly asks.

## Pipeline

1. **SwiftLint** — per staged file (blocks if `swiftlint` installed)
2. **UI component usage** — [ui-component-usage/run-checks.sh](../ui-component-usage/run-checks.sh) via `.cursor/hooks/pre-commit-check.sh`

## When to use

- Verify commit readiness
- Debug pre-commit failures
- Install git hooks

## Step 1 — Install hook

```bash
chmod +x .cursor/skills/code-review/ui-component-usage/run-checks.sh
./scripts/install-git-hooks.sh
```

## Step 2 — Run checks

```bash
./scripts/run-pre-commit-checks.sh
```

UI component rules only:

```bash
git diff --cached --name-only --diff-filter=ACM | grep '\.swift$' \
  | bash .cursor/skills/code-review/ui-component-usage/run-checks.sh
```

## Step 3 — Interpret output

| Symbol | Meaning |
|--------|---------|
| ❌ | Blocking — fix or `git commit --no-verify` |
| ⚠️ | Warning — does not block |
| ✅ | No blocking issues |

Rule details: [ui-component-usage/SKILL.md](../ui-component-usage/SKILL.md)

## Step 4 — Deep review (optional)

Only if the user asks:

- **ios-code-review** — full project + iOS checklist
- **swift-warnings-audit** — compiler warnings for listed paths
- **thread-handling** (Mode 1) — `.cursor/skills/project-ops/thread-audits/`

## Reference

- Hooks: [`.cursor/hooks/README.md`](../../../hooks/README.md)
- UI checks skill: [ui-component-usage](ui-component-usage/SKILL.md)
