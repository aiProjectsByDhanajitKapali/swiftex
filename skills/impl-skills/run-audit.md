---
name: run-audit
description: Execute the Rules, Skills, and Hooks audit from the plan. Use when auditing the codebase for rules, skills, and hooks inventory.
owner: Ram Sharma
---

# Run Rules/Skills/Hooks Audit

Execute the audit described in Rules_Skills_Hooks_Audit_Plan and produce inventory outputs.

## Reference Plan

`.cursor/plans/skill_plans/Rules_Skills_Hooks_Audit_Plan.md` (canonical)

Duplicate (legacy): `.cursor/plans/Rules_Skills_Hooks_Audit_Plan.md`

## Scripts to Run (from repo root)

### 1. Rules Inventory

```bash
find . -name ".cursorrules" -o -name "*CursorRules*" -o -name ".swiftlint.yml" -o -name "*.xcconfig" 2>/dev/null | grep -v Pods | grep -v DerivedData
```

Output: list of rule-like config files.

### 2. Skills inventory

Skills live under category folders: `.cursor/skills/<category>/<skill-name>/SKILL.md`. The `find` below lists every `SKILL.md`.

```bash
find . -path "*/.cursor/skills/*" -name "SKILL.md" 2>/dev/null
find . -path "*/.cursor/plans/*" -name "*.py" -o -name "*.sh" 2>/dev/null | grep -v Pods
find . -path "*/scripts/*" -name "*.py" -o -name "*.sh" 2>/dev/null | head -50
```

Output: list of skills and scripts.

### 3. Agents inventory

```bash
find . -path "*/.cursor/agents/*" -name "AGENT.md" 2>/dev/null
```

Output: list of agent workflow definitions (`AGENT.md` under `.cursor/agents/`).

### 4. Hooks - Notifications

```bash
grep -rn "extension Notification.Name" App/extnNotification/ 2>/dev/null
grep -rn "\.post(name:" App/ 2>/dev/null | wc -l
grep -rn "publisher(for:" App/ 2>/dev/null | wc -l
```

Output: notification names and approximate post/observe counts.

### 5. Hooks - Delegates

```bash
grep -rn "protocol.*Delegate" App/ 2>/dev/null | head -30
```

Output: delegate protocols.

### 6. Lifecycle Hooks

```bash
grep -rn "onAppear\|onDisappear\|didMoveToWindow\|viewDidAppear\|scene(_:willConnectTo)" App/ 2>/dev/null | head -50
```

Output: lifecycle hook locations.

## Output Directory

Create `audit_output/` (or `.cursor/plans/audit_output/`) and save results with timestamp.

## Summary to Produce

1. **Rules**: Table of paths and types
2. **Skills / Agents**: Tables of `SKILL.md` / `AGENT.md` paths and scripts entry points
3. **Hooks**: Counts for notifications, delegates, lifecycle; top 10 notification names by usage

## Reference

- Full plan: `.cursor/plans/Rules_Skills_Hooks_Audit_Plan.md`
- Skills plan: `.cursor/plans/skill_plans/Skills_Implementation_Plan.md`
