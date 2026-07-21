# PImageView (images / icons / lottie)

Use `PImageView` for images, icons, illustrations, and lottie — never SwiftUI `Image`.

- **Output**: `let iconImageViewModel: PImageViewViewModel`, initialized with a `kind`:
  - placeholder: `PImageViewViewModel(kind: .blank(size: CGSize(width: 24, height: 24)))`
  - remote: `PImageViewViewModel(kind: .remote(url: urlString, size: CGSize(width: 24, height: 24)))`
  - local asset: `PImageViewViewModel(kind: .localImage(name: "asset_name", ...))`
- **Body**:
  ```swift
  PImageView(viewModel: output.iconImageViewModel)
      .accessibilityIdentifier("<View>_Icon")
  ```
- Decide size/kind from the design; default to `.blank(size:)` if unknown.
