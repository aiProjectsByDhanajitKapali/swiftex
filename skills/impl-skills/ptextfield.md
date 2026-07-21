# PTextField (text input)

Use `PTextField` for input fields.

- **Output** (a `let`, initialized in `Output.init()` — not a `@Published var` with an
  inline value): `PTextFieldViewModel` is generic over its value and needs a formatter.

  ```swift
  let amountTextFieldViewModel: PTextFieldViewModel<Decimal>
  // in Output.init():
  amountTextFieldViewModel = PTextFieldViewModel(
      initialValue: nil,
      formatter: PTextFieldNumberFormatter(maximumFractionDigits: 2),
      isFocused: false,
      placeholder: "0"
  )
  ```

- **Valid formatters — use ONLY these. Do NOT invent a formatter type.**
  - `PTextFieldNumberFormatter(...)` — numeric input (the common case). `Value` is a number.
  - `AnyPTextFieldFormatter(...)` — type-erased wrapper around an existing formatter.
  - There is **no** `PTextFieldStringFormatter` (or any other `PTextField…Formatter`). If you
    need a plain free-text field and none of the above fits, do NOT fabricate a formatter —
    leave `// TODO: choose a real formatter for this field` and use `PTextFieldNumberFormatter()`.

- **Body** — `.enableStateManager()` FIRST (right after the initializer), before any SwiftUI
  modifier (see `enable-state-manager`):
  ```swift
  PTextField(viewModel: output.amountTextFieldViewModel)
      .enableStateManager()
      .accessibilityIdentifier("<View>_TextField")
  ```

- **API** — use these methods only: `updateValue(_:)`, `updatePlaceholder(string:)`,
  `updateFormatter(_:)`, `setResponder(_:)`. Note `updatePlaceholder` takes a `string:` label.
  - There is **no `.state` setter** and no readable `.placeholder` property — never write
    `viewModel.state = …` or read `viewModel.placeholder`. Drive error/validation/loading via
    `enableStateManager` + the `ViewState`.
