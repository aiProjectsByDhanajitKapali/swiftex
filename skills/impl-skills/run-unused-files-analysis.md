---
name: run-unused-files-analysis
description: Run the unused Swift files analysis and interpret results. Use when finding dead code, planning cleanup, or before major refactors.
owner: Ram Sharma
---

# Run Unused Files Analysis

Execute the existing unused Swift files analysis and help interpret the output.

## Location

- Scripts: `.cursor/plans/UnusedFiles/`
- Main script: `analyze_unused_files.py` or `analyze_unused_files.sh`
- Report: `unused_swift_files_report.md`
- Summary: `ANALYSIS_SUMMARY.md`

## Step 1: Run Analysis

From repo root:

```bash
cd .cursor/plans/UnusedFiles
python3 analyze_unused_files.py
# or
./analyze_unused_files.sh
```

## Step 2: Interpret Confidence Levels

- **HIGH (green)**: Strong signal; verify before delete (check for dynamic references, runtime strings)
- **MEDIUM (yellow)**: Higher false positive rate (~66% in past verification); manual review required
- **LOW (red)**: Likely used indirectly; do not delete without thorough verification

## Step 3: Safe Deletion (Optional)

When ready to remove files:

```bash
chmod +x .cursor/plans/UnusedFiles/safe_delete_files.sh
.cursor/plans/UnusedFiles/safe_delete_files.sh
```

This backs up files to Desktop before removing.

## Step 4: Verification Checklist

Before deleting any file:
1. Grep for the type/struct/class name across the repo
2. Check for string-based references (e.g. `NSClassFromString`, storyboard IDs)
3. For **assets** under `App/` (Lottie, GIF, images): grep **`R.file.<camelCase>.name`** in `App/` and check **`R.generated.swift`** at repo root (R.swift maps `InterestChipShimmer.json` → `interestChipShimmerJson`)
4. Check for protocol conformances used elsewhere
5. Review `MEDIUM_CONFIDENCE_VERIFICATION.md` for known false positive patterns

## Reference

- Full docs: `.cursor/plans/UnusedFiles/README.md`
- Plan: `.cursor/plans/skill_plans/Skills_Implementation_Plan.md`
