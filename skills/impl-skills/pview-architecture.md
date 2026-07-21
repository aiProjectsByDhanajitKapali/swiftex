# PView architecture

A PView feature is THREE files: View, `+IO`, ViewModel. Mirror this exactly.

- **View** `<Feature>/View/<Name>PView.swift` — `struct <Name>PView: PView` with
  `@ObservedObject var output: Output`, one `PassthroughSubject<Void, Never>` per user
  event (onAppear + each button), and `init(viewModel: ViewModel)` (the literal `ViewModel`
  typealias PView provides — NOT the concrete view-model type) calling
  `viewModel.transform(input: .init(...))`.
- **+IO** `<Feature>/View/<Name>PView+IO.swift` — `extension <Name>PView { struct Input { …AnyPublisher fields… }; final class Output: ObservableObject { …component view-models / @Published…; init(){…} } }`.
- **ViewModel** `<Feature>/ViewModel/<Name>PViewViewModel.swift` — `final class <Name>PViewViewModel: PViewModelable { typealias View = <Name>PView; private let output: Output; init(){ output = Output() }; func transform(input:) -> Output { …sink publishers…; return output } }`.

Imports — View/`+IO`: `SwiftUI, Combine, PUIKit, Utils_iOS`. ViewModel: `SwiftUI, Combine, PUIKit`.

## Worked example

### WalletModal/View/WalletModalPView.swift
```swift
import SwiftUI
import Combine
import PUIKit
import Utils_iOS

struct WalletModalPView: PView {
    @ObservedObject var output: Output
    private let onAppearSubject = PassthroughSubject<Void, Never>()
    private let confirmTapSubject = PassthroughSubject<Void, Never>()

    init(viewModel: ViewModel) {
        output = viewModel.transform(input: .init(
            onAppear: onAppearSubject.eraseToAnyPublisher(),
            onConfirmTap: confirmTapSubject.eraseToAnyPublisher()
        ))
    }

    var body: some View {
        VStack(alignment: .center, spacing: 16) {
            PText(output.titleTextViewModel)
                .setFont(Lightning.Heading.M)
                .accessibilityIdentifier("WalletModalPView_Title")

            ButtonView(varient: .primary, size: .large, state: .default, pattern: .textOnly(output.confirmButtonTitle)) {
                confirmTapSubject.send()
            }
            .accessibilityIdentifier("WalletModalPView_Confirm")
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier("WalletModalPView_Root")
        .onAppear { onAppearSubject.send() }
    }
}
```

### WalletModal/View/WalletModalPView+IO.swift
```swift
import SwiftUI
import Combine
import PUIKit
import Utils_iOS

extension WalletModalPView {
    struct Input {
        let onAppear: AnyPublisher<Void, Never>
        let onConfirmTap: AnyPublisher<Void, Never>
    }
    final class Output: ObservableObject {
        let titleTextViewModel: PTextViewModel
        @Published var confirmButtonTitle: String = ""
        init() {
            titleTextViewModel = PTextViewModel(text: "", color: .Content.HutanBlack)
        }
    }
}
```

### WalletModal/ViewModel/WalletModalPViewViewModel.swift
```swift
import SwiftUI
import Combine
import PUIKit

final class WalletModalPViewViewModel: PViewModelable {
    typealias View = WalletModalPView
    private let output: Output
    private var cancellables: Set<AnyCancellable> = []

    init() { output = Output() }

    func transform(input: Input) -> Output {
        cancellables = []
        input.onAppear
            .sink { [weak self] _ in guard let self else { return } /* TODO: load */ }
            .store(in: &cancellables)
        input.onConfirmTap
            .sink { [weak self] _ in guard let self else { return } /* TODO: handle */ }
            .store(in: &cancellables)
        return output
    }
}
```
