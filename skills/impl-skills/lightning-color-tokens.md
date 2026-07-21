# Lightning color tokens (Figma → Swift)

**Collection:** `Lightning Color State` in [Lightning Design System]

**Swift:** `Color.<Category>.<Token>` from **PUIKit** (not legacy `Colors.*`). Hex below are **reference values from Figma** (May 2026); runtime values come from PUIKit assets / appearance.

**Naming:** `Category/Token Name` → drop spaces, PascalCase. Figma `Accent/*-Secondary` → `Accent.*Secondary`. Known PUIKit spellings: `BackgroundPoup` (popup), `SungaiVoiletBlue` (violet).

---

## Base

| Figma | Swift | Light | Dark |
|-------|-------|-------|------|
| `Base/Background Primary` | `Color.Base.BackgroundPrimary` | `#ffffff` | `#000000` |
| `Base/Background Elevation` | `Color.Base.BackgroundElevation` | `#f3f4f5` | `#2c2c2c` |
| `Base/Background Popup` | `Color.Base.BackgroundPoup` | `#ffffff` | `#131415` |
| `Base/Black` | `Color.Base.Black` | `#25282b` | `#141414` |
| `Base/Sungai Violet Blue` | `Color.Base.SungaiVoiletBlue` | `#463cff` | `#463cff` |
| `Base/Jeruk Green` | `Color.Base.JerukGreen` | `#cefe06` | `#cefe06` |
| `Base/Warm White` | `Color.Base.WarmWhite` | `#efeae7` | `#efeae7` |

## Primary

| Figma | Swift | Light | Dark |
|-------|-------|-------|------|
| `Primary/Main` | `Color.Primary.Main` | `#463cff` | `#cefe06` |
| `Primary/Background` | `Color.Primary.Background` | `#eef2ff` | `#2c330e` |
| `Primary/Pressed` | `Color.Primary.Pressed` | `#342dbf` | `#b4df03` |
| `Primary/Line` | `Color.Primary.Line` | `#bcbcff` | `#5d700c` |
| `Primary/Disabled` | `Color.Primary.Disabled` | `#e8e8e8` | `#353535` |

## Content

| Figma | Swift | Light | Dark |
|-------|-------|-------|------|
| `Content/Hutan Black` | `Color.Content.HutanBlack` | `#000000` | `#ffffff` |
| `Content/Hutan 80` | `Color.Content.Hutan80` | `#7e8288` | `#b3b3b3` |
| `Content/Hutan 60` | `Color.Content.Hutan60` | `#a0a4ab` | `#808080` |
| `Content/Hutan 40` | `Color.Content.Hutan40` | `#d5d7dc` | `#4c4c4c` |
| `Content/White` | `Color.Content.White` | `#ffffff` | `#000000` |
| `Content/White Inverse` | `Color.Content.WhiteInverse` | `#ffffff` | `#ffffff` |

## Additional

| Figma | Swift | Light | Dark |
|-------|-------|-------|------|
| `Additional/Line Primary` | `Color.Additional.LinePrimary` | `#9ba2a8` | `#6b7073` |
| `Additional/Line Secondary` | `Color.Additional.LineSecondary` | `#e6e9e8` | `#202224` |

## Success / Warning / Error

| Figma | Swift | Light | Dark |
|-------|-------|-------|------|
| `Success/Main` | `Color.Success.Main` | `#1fc62a` | `#02f690` |
| `Success/Background` | `Color.Success.Background` | `#d8f4d1` | `#0e3727` |
| `Success/Line` | `Color.Success.Line` | `#bceebf` | `#0a7047` |
| `Warning/Main` | `Color.Warning.Main` | `#ffb526` | `#ffaa00` |
| `Warning/Background` | `Color.Warning.Background` | `#fffab2` | `#34210d` |
| `Warning/Line` | `Color.Warning.Line` | `#ffed90` | `#71401c` |
| `Error/Main` | `Color.Error.Main` | `#ff504b` | `#ff7570` |
| `Error/Background` | `Color.Error.Background` | `#fff6f6` | `#311512` |
| `Error/Line` | `Color.Error.Line` | `#ffcbc9` | `#6b3836` |

## Accent

| Figma | Swift | Light | Dark |
|-------|-------|-------|------|
| `Accent/Magenta` | `Color.Accent.Magenta` | `#fd00fe` | `#ff6492` |
| `Accent/Magenta-Secondary` | `Color.Accent.MagentaSecondary` | `#fe99ff` | `#7f277f` |
| `Accent/Magenta-Tertiary` | `Color.Accent.MagentaTertiary` | `#ffd9ff` | `#270c27` |
| `Accent/Azure` | `Color.Accent.Azure` | `#008eff` | `#67d1ff` |
| `Accent/Azure-Secondary` | `Color.Accent.AzureSecondary` | `#90ceff` | `#294b66` |
| `Accent/Azure-Tertiary` | `Color.Accent.AzureTertiary` | `#cde9ff` | `#0f1e2a` |
| `Accent/Blue` | `Color.Accent.Blue` | `#463cff` | `#534afd` |
| `Accent/Blue-Secondary` | `Color.Accent.BlueSecondary` | `#bcbcff` | `#2b327d` |
| `Accent/Blue-Tertiary` | `Color.Accent.BlueTertiary` | `#eef2ff` | `#191b33` |
| `Accent/Purple` | `Color.Accent.Purple` | `#7700a8` | `#cc60ff` |
| `Accent/Purple-Secondary` | `Color.Accent.PurpleSecondary` | `#c999dc` | `#52176b` |
| `Accent/Purple-Tertiary` | `Color.Accent.PurpleTertiary` | `#ebd9f2` | `#1e0828` |
| `Accent/Orange` | `Color.Accent.Orange` | `#ff8e23` | `#ff8831` |
| `Accent/Orange-Secondary` | `Color.Accent.OrangeSecondary` | `#ffc700` | `#d4ab18` |
| `Accent/Orange-Tertiary` | `Color.Accent.OrangeTertiary` | `#ffe999` | `#271905` |
