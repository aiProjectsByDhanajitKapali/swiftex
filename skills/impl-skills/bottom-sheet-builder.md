---
name: bottom-sheet-builder
description: Build and present bottom sheets with `BottomSheetBuilder`, including text, HTML, local or remote images, banners, button arrangements, tap handlers, and Combine subjects. Use when adding or updating `BottomSheetBuilder` flows, bottom sheet popups, or when the user mentions bottom sheets, `BottomSheetBuilder`, or builder modifiers.
---

# Bottom Sheet Builder

Use this skill when working with `BottomSheetBuilder` in the iOS app.

## Quick rules

- Start with `BottomSheetBuilder()` and chain only the modifiers needed for that sheet.
- A bottom sheet must always have at least a description source.
- Use `.description(...)` for plain text content.
- Use `.htmlString(...)` for rich content. If both are set, `description` renders and HTML is ignored.
- Use `.localImage(...)` for asset-based illustrations. If both `.localImage(...)` and `.image(...)` are set, the local image renders first.
- Use `.imageFrame(...)` only when the default `280x260` image size is not suitable.
- Use `.primaryButton(...)` for the main CTA.
- Use `.secondaryButton(...)` for dismiss, cancel, or supporting actions.
- `buttonArrangement` defaults to `.vertical`.
- Tapping either button executes the closure, sends the optional subject event, then dismisses the bottom sheet.
- Use `.buildWithViewModel()` when presenting through `BasePViewModelHostingController`.
- Use `.build()` only when you specifically want the `BottomSheetView` back directly.
- Bottom sheets should usually be wrapped in a dedicated method such as `showBankDownTimeSheet(...)` rather than being built inline in unrelated code.

## Copy and localization rules

- Plain-text bottom sheet copy must be localized.
- This applies to `.title(...)`, `.description(...)`, `.primaryButton(...)`, and `.secondaryButton(...)` when the copy is authored in the client.
- If the user provides plain text instead of existing localization keys, ask for the localized copy and add the entries in:
  - `App/en.lproj/Localizable.strings`
  - `App/id.lproj/Localizable.strings`
- Then use the new key with `.localized()` in the builder call sites.
- If the description is HTML content from backend or existing data, use `.htmlString(...)` and do not create localized-string entries for that description.
- If title or button texts also come from backend or an existing model object, use those values directly instead of creating new localization keys.

## Method shape rules

- Prefer creating or updating a dedicated method that owns the bottom sheet flow, for example `showBankDownTimeSheet(popup: BankDowntimePopup)`.
- If a nearby object or response model already exists, accept that object in the method and build the sheet from it.
- If the user does not specify an existing method or object, create a simple dedicated method with no parameters and infer a clear name from the title or description, such as `showKycRequiredBottomSheet()` or `showBankMaintenanceBottomSheet()`.
- Keep the builder chain inside that method.
- Present the sheet from the same method unless the surrounding architecture already separates building and presenting.

## Supported modifiers

```swift
BottomSheetBuilder()
    .title(String?)
    .description(String?)
    .htmlString(String?)
    .image(String?)
    .localImage(ImageResource?)
    .imageFrame(CGSize?)
    .primaryButton(String)
    .secondaryButton(String, state: ButtonState = .default, varient: ButtonVarient = .primary)
    .buttonArrangement(BottomSheetViewButtonsArrangementStyle)
    .onPrimaryTap { ... }
    .onSecondaryTap { ... }
    .primaryButtonSubject(PassthroughSubject<Void, Never>)
    .secondaryButtonSubject(PassthroughSubject<Void, Never>)
    .banner(BannerModel?)
```

## Preferred presentation pattern

This is the standard pattern used across the app when presenting a bottom sheet from a dedicated method.

```swift
private func showBankDownTimeSheet() {
    let viewModel = BottomSheetBuilder()
        .title("bank_downtime_sheet_title".localized())
        .description("bank_downtime_sheet_description".localized())
        .primaryButton("gss.understood".localized())
        .buttonArrangement(.vertical)
        .buildWithViewModel()

    let bottomSheetView = BottomSheetView(viewModel: viewModel)
    let controllerViewModel = BaseHostingPViewModel<BottomSheetView>(viewModel: viewModel)
    let hostingController = BasePViewModelHostingController<BottomSheetView>(
        rootView: bottomSheetView,
        viewModel: controllerViewModel
    )
    let bottomSheetVC = BottomSheetViewController(hostingController: hostingController)

    DispatchQueue.main.async {
        ScreenObjectMapper.present(bottomSheetVC, false)
    }
}
```

## Sample usages

### 1. Simple localized info bottom sheet

Use this when the screen owns the copy and there is no existing popup object. Create a dedicated no-parameter method and localize title, description, and button text in both `en` and `id`.

```swift
private func showWalletInfoBottomSheet() {
    let viewModel = BottomSheetBuilder()
        .title("wallet_info_sheet_title".localized())
        .description("wallet_info_sheet_description".localized())
        .primaryButton("wallet_info_sheet_primary_cta".localized())
        .buttonArrangement(.vertical)
        .buildWithViewModel()
}
```

### 2. Object-backed confirmation bottom sheet with horizontal buttons

Use this when a popup object already exists. Build from that object instead of inventing new parameters.

```swift
private func showCashoutTransferPromptBottomSheet(popup: WalletCardView.ButtonData.WalletButtonPopup) {
    let viewModel = BottomSheetBuilder()
        .title(popup.title)
        .description(popup.description)
        .secondaryButton("cancel".localized(), state: .default, varient: .secondary)
        .primaryButton("idr_cash_transfer_popup_primary_btn_title".localized())
        .buttonArrangement(.horizontal)
        .onSecondaryTap {
            UIApplication.dismiss()
        }
        .onPrimaryTap { [weak self] in
            UIApplication.dismiss()
            self?.navigateToTransferInput()
        }
        .buildWithViewModel()
}
```

### 3. HTML description with remote image and banner

Use this when the description comes as formatted HTML from backend or an existing model. Do not create localized-string entries for the HTML description.

```swift
let bannerModel = BannerModel(
    state: .info,
    title: "usd.yield.banner.title".localized(),
    description: "usd.yield.banner.description".localized()
)

private func showInterestEligibilityBottomSheet(popup: InterestEligibilityPopup) {
    let viewModel = BottomSheetBuilder()
        .title(popup.title)
        .htmlString(popup.description)
        .image(popup.image)
        .banner(bannerModel)
        .primaryButton(popup.button?.text ?? "")
        .secondaryButton(popup.link?.text ?? "", state: .default, varient: .secondary)
        .buttonArrangement(.vertical)
        .onPrimaryTap {
            UIApplication.dismiss()
        }
        .onSecondaryTap { [weak self] in
            UIApplication.dismiss()
            self?.handleLinkTap()
        }
        .buildWithViewModel()
}
```

### 4. Local image bottom sheet

Use this when the illustration lives in app assets and the sheet copy is client-authored.

```swift
private func showAddBankAccountBottomSheet() {
    let viewModel = BottomSheetBuilder()
        .title("please_add_bank_account".localized())
        .description("please_add_bank_account_desc".localized())
        .localImage(.addBank)
        .imageFrame(CGSize(width: 220, height: 180))
        .primaryButton("add_bank_account".localized())
        .secondaryButton("cancel".localized(), state: .default, varient: .secondary)
        .buttonArrangement(.vertical)
        .onPrimaryTap { [weak self] in
            self?.openAddBankFlow()
        }
        .buildWithViewModel()
}
```

### 5. Subject-based event handling

Use this when the tap event should be observed through Combine, but still keep the creation inside a dedicated bottom-sheet method.

```swift
private let primaryTapSubject = PassthroughSubject<Void, Never>()
private let secondaryTapSubject = PassthroughSubject<Void, Never>()

private func showMaximumAdjustedBottomSheet() {
    let viewModel = BottomSheetBuilder()
        .title("cashout.adjusted.title".localized())
        .description("cashout.adjusted.description".localized())
        .primaryButton("continue".localized())
        .secondaryButton("cancel".localized(), state: .default, varient: .secondary)
        .buttonArrangement(.horizontal)
        .primaryButtonSubject(primaryTapSubject)
        .secondaryButtonSubject(secondaryTapSubject)
        .buildWithViewModel()
}

primaryTapSubject
    .sink { [weak self] in
        self?.navigateToReviewPage()
    }
    .store(in: &cancellables)

secondaryTapSubject
    .sink { [weak self] in
        self?.trackDismiss()
    }
    .store(in: &cancellables)
```

### 6. Minimal inferred method when no API object exists

If the user only describes the bottom sheet behavior and no method or object exists yet, create a simple method and infer a clear name from the sheet content.

```swift
private func showKycRequiredBottomSheet() {
    let viewModel = BottomSheetBuilder()
        .title("kyc_required_sheet_title".localized())
        .description("kyc_required_sheet_description".localized())
        .primaryButton("complete_kyc_cta".localized())
        .secondaryButton("later".localized(), state: .default, varient: .secondary)
        .buttonArrangement(.vertical)
        .buildWithViewModel()
}
```

## Decision guide

- Need plain text body: use `.description(...)`
- Need formatted body from backend: use `.htmlString(...)`
- Need client-authored plain text: create keys in `App/en.lproj/Localizable.strings` and `App/id.lproj/Localizable.strings`
- Need asset illustration: use `.localImage(...)`
- Need remote illustration: use `.image(...)`
- Need one CTA: use `.primaryButton(...)`
- Need confirm/cancel: add `.secondaryButton(...)`
- Need side-by-side buttons: use `.buttonArrangement(.horizontal)`
- Need stacked buttons: use `.buttonArrangement(.vertical)` or omit it
- Need imperative follow-up logic: use `.onPrimaryTap` / `.onSecondaryTap`
- Need reactive follow-up logic: use `.primaryButtonSubject(...)` / `.secondaryButtonSubject(...)`
- Already have a popup/model object: create a dedicated `show...BottomSheet(object:)` method
- No existing object or method: create a dedicated no-parameter `show...BottomSheet()` method with an inferred name
- Need hosting controller presentation: use `.buildWithViewModel()`

## Important behavior notes

- A bottom sheet should not be created without a description source. Use plain `.description(...)` or `.htmlString(...)`.
- `description` wins over `htmlString` during rendering.
- `localImage` wins over `image` during rendering.
- The primary button always renders as `.primary` with `.default` state.
- The secondary button variant defaults to `.primary`, so pass `varient: .secondary` for cancel-style UI when needed.
- The bottom sheet dismisses automatically after button taps, so only add explicit `UIApplication.dismiss()` when your surrounding flow depends on it.
