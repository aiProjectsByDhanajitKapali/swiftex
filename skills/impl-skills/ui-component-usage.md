---
name: ui-component-usage
description: >-
  Fast, deterministic checks for UI component conventions on listed Swift
  files (PButtonView, PView navigation, ViewModel placement, PText/PTextField/PImageView).
  Used by git pre-commit. No LLM. For authoring see new-feature/ui-component.
owner: Ram Sharma
---

# UI component usage (pre-commit)

Enforces **grep-based** rules aligned with `.cursorrules` and [ios-code-review](../ios-code-review/SKILL.md). Implementation: [`run-checks.sh`](run-checks.sh).

For **how to build** screens (PButtonView, PText, PView folders), use [new-feature/ui-component](../../new-feature/ui-component/SKILL.md) — different scope.

## When to use

- Git pre-commit / pre-push on staged Swift files
- Manual check before commit: `@ui-component-usage` or run script below
- Interpreting blocking vs warning output from the hook

Do **not** use this skill for full architecture or threading review.

**Buttons:** Pre-commit blocks **SwiftUI `Button`** only. **`ButtonView` is not checked** (legacy code may keep it). New / revamp UI should use **`PButtonView`** per [ui-component](../../new-feature/ui-component/SKILL.md).

## Rules

| ID | Tier | Scope | Pattern / rule | Fix |
|----|------|-------|----------------|-----|
| `btn-swiftui` | Error | All staged `.swift` | SwiftUI `Button` only (`Button(`, `Button {`, `Button(action:`) | Use `PButtonView`; **`ButtonView` is ignored** (not flagged) |
| `host-pview` | Error | App code (not Pods) | `BaseUIHostingController` | `PModuleFactory.getModule` + `ScreenObjectMapper.push` |
| `lazy-output` | Warn | `*ViewModel` types / `*ViewModel.swift` | `lazy var output` | `private let output` in `init` |
| `vm-in-view` | Warn | `*View.swift` + PView | `*ViewModel(` in view body | Child VMs on parent `Output` |
| `text-swiftui` | Warn | `*View.swift` + PView | `\bText(` not `PText` / `PAttributedText` | `PText` / `PAttributedText` |
| `textfield-swiftui` | Warn | `*View.swift` + PView | `\bTextField(` not `PTextField` | `PTextField` |
| `image-swiftui` | Warn | `*View.swift` + PView | `\bImage(` not `PImageView` / remote helpers | `PImageView` + `PImageViewViewModel` |

**Environment**

| Variable | Default | Effect |
|----------|---------|--------|
| `APP_PRECOMMIT_STRICT` | `1` | Exit `1` on errors |
| `APP_PRECOMMIT_WARNINGS` | `1` | Print warnings |

## Run checks

**Stdin:** one repo-relative `.swift` path per line.

```bash
git diff --cached --name-only --diff-filter=ACM | grep '\.swift$' \
  | bash .cursor/skills/code-review/ui-component-usage/run-checks.sh
```

Or full pre-commit pipeline (SwiftLint + this skill):

```bash
./scripts/run-pre-commit-checks.sh
```

## Git hook wiring

| Layer | Path |
|-------|------|
| Skill script (canonical) | `.cursor/skills/code-review/ui-component-usage/run-checks.sh` |
| Hook wrapper | `.cursor/hooks/pre-commit-check.sh` → execs skill script |
| Git entry | `.cursor/hooks/pre-commit` |

Install: `./scripts/install-git-hooks.sh`

## Sample catalog

Test files under [`.cursor/hooks/samples/`](../../../hooks/samples/) — **do not** add to app targets.

| Rule ID | File | MARK / location | Notes |
|---------|------|-----------------|-------|
| `btn-swiftui` | `PreCommitViolationsSample.swift` | `btn-swiftui` | Three `Button` syntax variants |
| `host-pview` | `PreCommitViolationsSample.swift` | `host-pview` | Coordinator `BaseUIHostingController` |
| `lazy-output` | `PreCommitViolationsSample.swift` | `lazy-output` | Inline `PreCommitViolationsSampleViewModel` |
| `lazy-output` | `PreCommitViolationsSampleViewModel.swift` | whole file | `*ViewModel.swift` filename path |
| `vm-in-view` | `PreCommitViolationsSample.swift` | `vm-in-view` | `SlideButtonViewModel`, `PHtmlTextViewModel`, `CustomBannerViewModel` |
| `text-swiftui` | `PreCommitViolationsSample.swift` | `text-swiftui` + inside `Button` labels | Static and `Text(output.title)` |
| `textfield-swiftui` | `PreCommitViolationsSample.swift` | `textfield-swiftui` | SwiftUI `TextField` |
| `image-swiftui` | `PreCommitViolationsSample.swift` | `image-swiftui` | Asset + `systemName` |
| (none) | `PreCommitViolationsSampleView+IO.swift` | — | `vm-in-view` skipped by `*View+IO.swift` exclusion |
| (none) | Comments in main sample | `Valid patterns` | `PButtonView`, `ButtonView` (ignored), `PText`, `// Button` — must not flag |

### Expected output (approximate)

Run on all sample Swift files (line numbers drift; counts are indicative):

```bash
ls .cursor/hooks/samples/PreCommitViolationsSample*.swift \
  | bash .cursor/skills/code-review/ui-component-usage/run-checks.sh
```

| Tier | Typical count | Rule IDs |
|------|---------------|----------|
| Error | 2 | `btn-swiftui` (one report per file), `host-pview` |
| Warn | 6+ | `lazy-output` (×2 files), `vm-in-view`, `text-swiftui`, `textfield-swiftui`, `image-swiftui` |

Exit code **1** when `APP_PRECOMMIT_STRICT=1` (errors present). Warnings alone do not block.

**Per-file smoke tests**

```bash
# Only lazy-output
printf '%s\n' .cursor/hooks/samples/PreCommitViolationsSampleViewModel.swift \
  | bash .cursor/skills/code-review/ui-component-usage/run-checks.sh

# No vm-in-view (should pass or only unrelated warns if file changed)
printf '%s\n' .cursor/hooks/samples/PreCommitViolationsSampleView+IO.swift \
  | bash .cursor/skills/code-review/ui-component-usage/run-checks.sh
```

## Extending rules

1. Add a `check_*` function in `run-checks.sh` (use `is_pview_swift_file` for PView-only UI primitives).
2. Document the rule in the table above.
3. Add a MARK block to the sample file(s).

Keep checks **fast** (grep only); no `xcodebuild` in this skill.

## Related

- [pre-commit-staged](../pre-commit-staged/SKILL.md) — SwiftLint + hook orchestration
- [ios-code-review](../ios-code-review/SKILL.md) — full LLM review checklist
- [new-feature/ui-component](../../new-feature/ui-component/SKILL.md) — PButtonView, PText, PView scaffolding
