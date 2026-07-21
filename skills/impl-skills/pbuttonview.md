# Button → ButtonView

Use `ButtonView` (Utils_iOS design system) for buttons — never SwiftUI `Button`.

- **Output**: `@Published var confirmButtonTitle: String = ""` (or pass a localized literal).
- **View**: one `PassthroughSubject<Void, Never>` per button, and a matching
  `AnyPublisher<Void, Never>` field in `Input` wired in `init`.
- **Body**:
  ```swift
  ButtonView(varient: .primary, size: .large, state: .default, pattern: .textOnly(output.confirmButtonTitle)) {
      confirmTapSubject.send()
  }
  .accessibilityIdentifier("<View>_Confirm")
  ```
- Button copy must be localized: `.textOnly("some.key".localized())` when authored in the client.
- Handle the tap in `transform(input:)` by sinking the button's `Input` publisher.
- Do NOT apply `.id(...)` to a button.
