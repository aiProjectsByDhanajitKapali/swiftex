# PText (text)

Use `PText` for any text — never SwiftUI `Text`, never `PText(aString)`.

- **Output**: `let titleTextViewModel: PTextViewModel`, initialized
  `PTextViewModel(text: "", color: .Content.HutanBlack)` (use the real copy / a token color).
- **Body**:
  ```swift
  PText(output.titleTextViewModel)
      .setFont(Lightning.Heading.M)            // headings: Heading.L/M; body: Body.M/S
      .accessibilityIdentifier("<View>_Title")
  ```
- `Lightning` lives in `Utils_iOS`. Pick the token by role (title → `Lightning.Heading.M`,
  body/labels → `Lightning.Body.M`, captions → `Lightning.Body.S`).
- To update text later from the ViewModel: `titleTextViewModel.updateText(...)` (or set
  `output.title…` if the module exposes a published string) — never replace the view model.
