---
name: swift-warnings-audit
description: >-
  Audit only user-listed Swift/source files for compiler warnings and optional SwiftLint output.
  Does not scan the whole project or .pbxproj. Use the warnings agent or run
  .cursor/scripts/collect_swift_warnings.sh with explicit paths. Review results in
  .cursor/agents/warnings/LATEST_WARNINGS.md after a successful build.
owner: Ram Sharma
---

# Swift warnings audit (listed files only)

## When to use

- You have **explicit file paths** (e.g. PR-touched `.swift` files) and want a **table of warnings/errors** for those files only.
- You want unused-variable / deprecation / concurrency warnings without wading through the entire target build log.

**Not for**: whole-app warning cleanup in one shot, or auditing `project.pbxproj` (out of scope).

## Required input

- **Non-empty list of paths** (repo-relative or absolute). If the user did not list files, **ask which files** before running tools.

## Step 1 — Run the collector (recommended)

From repository root:

```bash
chmod +x .cursor/scripts/collect_swift_warnings.sh
SCHEME=<YourXcodeScheme> .cursor/scripts/collect_swift_warnings.sh App/Module/Example/MyView.swift
```

Or:

```bash
TARGET_FILES="App/A.swift App/B.swift" SCHEME=<Scheme> .cursor/scripts/collect_swift_warnings.sh
```

**Outputs**

| Location | Purpose |
|----------|---------|
| **[`.cursor/agents/warnings/LATEST_WARNINGS.md`](../../../agents/warnings/LATEST_WARNINGS.md)** | **Canonical review file** — run metadata + filtered table (refreshed when `xcodebuild` succeeds; unchanged on failure if a prior successful audit exists) |
| `$OUTPUT_DIR/build_warnings.log` | Full `xcodebuild` output (default under `.cursor/tmp/swift-warnings/`) |
| `$OUTPUT_DIR/swiftlint.log` | SwiftLint `--reporter xcode` lines (or skip message) |
| `$OUTPUT_DIR/build_warnings.filtered.md` | Same table as embedded in `LATEST_WARNINGS.md` |
| `$OUTPUT_DIR/last_run.txt` | Workspace, scheme, destination, targets |

**Environment** (optional):

- `WORKSPACE` — default `App.xcworkspace`
- `SCHEME` — default: first scheme from `xcodebuild -list -json`
- `DESTINATION` — default `generic/platform=iOS`
- `FAIL_ON_XCODEBUILD=1` — fail the script when `xcodebuild` fails, not only when filtered **errors** exist
- `XCODEBUILD_EXTRA` — extra `xcodebuild` arguments before `build` (e.g. signing overrides)

## Step 2 — Or invoke the Task agent

Launch subagent **`unused-variables-methods`** (or follow) [.cursor/agents/warnings/AGENT_warnings.md](../../../agents/warnings/AGENT_warnings.md) with the same **file list**; the deliverable shape matches **`LATEST_WARNINGS.md`** when using the script.

## Step 3 — Interpret the report

- **Unused**: safe to remove or replace with `_` after confirming no dynamic use.
- **Deprecation**: plan migration to non-deprecated APIs.
- **Concurrency**: align with `MainActor` / `Sendable` team rules before silencing.
- **False positives**: `#if`, codegen, `@preconcurrency`, cross-target references—verify before deleting.

## Related

- Agent workflow: [.cursor/agents/warnings/AGENT_warnings.md](../../../agents/warnings/AGENT_warnings.md)
- Canonical report: [.cursor/agents/warnings/LATEST_WARNINGS.md](../../../agents/warnings/LATEST_WARNINGS.md)
- Filter implementation: [.cursor/scripts/filter_diagnostics_to_allowlist.py](../../../scripts/filter_diagnostics_to_allowlist.py)
- Unused **files** (different goal): [.cursor/skills/code-revamp/run-unused-files-analysis/SKILL.md](.cursor/skills/code-revamp/run-unused-files-analysis/SKILL.md)
- SwiftLint config: [`.swiftlint.yml`](../../../../.swiftlint.yml) (repo root)
