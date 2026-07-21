# Lightning typography tokens (Figma → Swift)

**Library:** published text styles in [Lightning Design System]

**Swift:** `Lightning.<Category>.<Size>` from **Utils_iOS** — apply on **`PText`** / **`PAttributedText`** (or legacy `Text` during migration) via **`.setFont(Lightning.…)`**. Add `import Utils_iOS` with `PUIKit` as needed.

**Naming:** Figma `Category/Size` → `Lightning.<Category>.<Size>` (e.g. Figma `Body/M` → `Lightning.Body.M`). Figma `Heading/Special` → `Lightning.Heading.Special` if exposed in Utils_iOS.

**Metrics:** Font family, weight, size, and line height live in Figma (Dev Mode → text style) and in **Utils_iOS** implementations. This table lists **semantic mapping**; do not pick tokens by point size alone.

---

## Heading

| Figma style | Swift | Typical UI role | Legacy hint (verify role) |
|-------------|-------|-----------------|---------------------------|
| `Heading/XL` | `Lightning.Heading.XL` | Hero / marketing headline | `.Medium, 28+` |
| `Heading/L` | `Lightning.Heading.L` | Screen title, large section title | `.Medium, 24` |
| `Heading/M` | `Lightning.Heading.M` | Nav bar title, sheet title, section header | `.Medium, 20` |
| `Heading/S` | `Lightning.Heading.S` | Subsection title, emphasized row title | `.Medium, 16` |
| `Heading/XS` | `Lightning.Heading.XS` | Small heading, compact group label | `.Medium, 14` |
| `Heading/XXS` | `Lightning.Heading.XXS` | Micro heading, dense UI chrome | `.Medium, 12` |
| `Heading/Special` | `Lightning.Heading.Special` | Brand / one-off heading (per Figma) | — |

## Body

| Figma style | Swift | Typical UI role | Legacy hint (verify role) |
|-------------|-------|-----------------|---------------------------|
| `Body/L` | `Lightning.Body.L` | Large body, intro paragraph | `.Regular, 18` |
| `Body/M` | `Lightning.Body.M` | Primary body, labels, list primary line | `.Regular, 16` |
| `Body/S` | `Lightning.Body.S` | Secondary body, descriptions, helper text | `.Regular, 14` |
| `Body/XS` | `Lightning.Body.XS` | Caption, metadata, timestamps, legal fine print | `.Regular, 12` |

---

## Role → token (quick pick)

Use when Figma does not label a layer but the **role** is clear (same rules as revamp screens such as `IDSSKycStatusScreen`):

| Role | Token |
|------|-------|
| Screen title (below nav, full width) | `Lightning.Heading.L` |
| Compact nav / toolbar title (inline with back) | `Lightning.Heading.M` |
| Section header in a list or timeline | `Lightning.Heading.M` |
| Primary body, form labels | `Lightning.Body.M` |
| Description, secondary copy | `Lightning.Body.S` |
| Step counter, metadata, fine print | `Lightning.Body.S` or `.XS` |

---

## Migration from legacy `.setFont`

### Do

1. Open the screen in Figma (or a revamp reference like KYC IDSS) and note the **text style name** on each text layer.
2. Map Figma `Category/Size` → `Lightning.<Category>.<Size>`.
3. Replace **`.setFont(.Regular, N)`** / **`.setFont(.Medium, N)`** and **`Font.regularH*`** on revamped / **PView** screens.
4. Prefer **`PText`** / **`PAttributedText`** instead of raw **`Text`**.

### Do not

- Map by **point size only** (e.g. all `14` → `Body.S`) — same size can be caption, label, or description.
- Copy legacy tokens from unrelated screens without checking Figma role.

### Worked example: `EmailVerifyViewRevamp`

| Element | Legacy | Lightning |
|---------|--------|-----------|
| Screen title | `.setFont(.Medium, 24)` | `.setFont(Lightning.Heading.L)` |
| Description | `.setFont(.Regular, 14)` | `.setFont(Lightning.Body.S)` |

Reference: `IDSSKycStatusScreen` — compact header `Heading.M`, page title `Heading.L`, body lines `Body.M` / `Body.S` / `Body.XS`.

---

## UIKit `Font.regularH*` (legacy)

UIKit **`Font.regularH5`**, **`Font.mediumH4`**, etc. are **not** 1:1 with Lightning sizes. When migrating UIKit or old SwiftUI:

1. Find the matching **Figma text style** for that control in the design spec.
2. Use the **Heading/Body** table above, not H-number alone.

Approximate starting points only (always confirm in Figma):

| UIKit | Often near Lightning |
|-------|----------------------|
| `Font.regularH4` / `mediumH4` | `Body.M` or `Heading.S` |
| `Font.regularH5` / `mediumH5` | `Body.S` |
| `Font.regularH6` | `Body.XS` |
| `Font.regularH2` / `mediumH2` | `Heading.L` or `Heading.M` |
