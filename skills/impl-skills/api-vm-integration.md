---
name: api-vm-integration
description: Wire a service-layer API call into a PViewModelable ViewModel — inject the service, trigger the call (onAppear / init / button tap), source params (text field / stored property / literal / collection), run it in a Task, and update Output state. Pairs with api-integration (which builds the service). Use after the service method exists and the user wants it called from a ViewModel.
owner: Dhanajit Kapali
---

# API integration in the ViewModel

This skill wires an existing service method (built per the `api-integration` skill)
into a `PViewModelable` ViewModel. The `api-integration` skill builds the
service; this skill calls it from the VM.

## Rules

- **Inject the service** via the VM `init` with a default concrete value, e.g.
  `service: ScreenersServiceProtocol = ScreenersService()`. If the VM **already** holds
  a service property, REUSE it — add the new call as another method on the same service
  (do not introduce a second service).
- **One private method per API**, e.g. `private func loadAssets()`. It: sets loading
  state on `output`, runs the call in a `Task { [weak self] … }`, awaits the service,
  maps `response.data`, and updates `output` on `await MainActor.run { … }`. Catch
  errors and route to an error handler that updates `output`.
- **Trigger** the method from `transform(input:)` by sinking the matching `Input`
  publisher. Never call the network directly from the View.
- Always `[weak self]` in the `Task` and sinks; `guard let self else { return }`.
- The service returns `PNetworkResponse<Model>` — read the payload from `response.data`.

## Trigger mapping (how the user wants it fired → wiring)

| Trigger | Wiring |
|---|---|
| On first appear | `input.onFirstAppearPublisher.sink { self.loadX() }` (add the publisher to `Input` if missing) |
| On init / immediately | call `loadX()` at the end of `init` (after `output` is set up) |
| On button tap | add a `PassthroughSubject` + `Input` publisher for that button; `input.onXTapPublisher.sink { self.loadX() }` |
| On refresh / retry | `input.onRefreshPublisher` / `input.onErrorRetryPublisher` sinks |

## Param sourcing (cURL param → value in the VM)

Build a `[String: Any]` (or typed args) for the call. Map each param to its source:

| Source | Code |
|---|---|
| Text field | the bound `PTextField` view-model value, e.g. `output.amountTextFieldViewModel.text` |
| Stored property | a `let`/`var` on the VM, e.g. `self.category` |
| Literal | a constant the user supplies |
| First of array | `self.items.first?.id` |
| Dictionary value | `self.params["key"]` |

Ask the user for each param's source in the gate; don't guess.

## State on Output

Match the nearby module's convention. A common shape:
`isLoading`, `errorMessage`, and `hide…` flags toggled before/after the call.

## Worked example (mirrors ScreenersAssetListViewModel)

```swift
final class ExampleViewModel {
    private let output: ExampleView.Output = .init()
    private var cancellables: Set<AnyCancellable> = []
    private let category: String                       // param from a stored property
    private let service: ExampleServiceProtocol

    init(category: String, service: ExampleServiceProtocol = ExampleService()) {
        self.category = category
        self.service = service
    }

    private func loadItems() {
        output.isLoading = true
        output.errorMessage = nil

        Task { [weak self] in
            guard let self else { return }
            do {
                let parameters: [String: Any] = ["category": self.category]
                let response = try await self.service.getItems(parameters)
                let items = response.data?.items ?? []
                await MainActor.run {
                    self.output.items = items
                    self.output.isLoading = false
                }
            } catch {
                await MainActor.run { self.handleError(error) }
            }
        }
    }

    private func handleError(_ error: Error) {
        output.isLoading = false
        output.errorMessage = error.localizedDescription
    }
}

extension ExampleViewModel: PViewModelable {
    typealias View = ExampleView

    func transform(input: ExampleView.Input) -> ExampleView.Output {
        cancellables = []
        input.onFirstAppearPublisher
            .sink { [weak self] in self?.loadItems() }
            .store(in: &cancellables)
        return output
    }
}
```

## If the VM already integrates a service

- Reuse the existing injected service property.
- Add the new method to the existing `…ServiceProtocol` (per `api-integration`).
- Add a new `private func loadX()` and a new trigger sink in `transform` — leave the
  existing calls untouched.
