---
name: create-coordinator
description: Add a new coordinator using GenericCoordinator and CoordinatorPages. Use when adding navigation to a new screen or feature.
owner: Ram Sharma
---

# Create Coordinator

Add a coordinator following the GenericCoordinator pattern.

## Prerequisites

- Feature module path
- Screens/pages to navigate to
- Parent coordinator (if nested) or entry point

## Step 1: Create Coordinator Folder

```
App/Module/<Module>/<Feature>/Coordinator/
└── <Feature>Coordinator.swift
```

## Step 2: Define CoordinatorPages Enum

```swift
enum YourCoordinatorPages: CoordinatorPages {
    case openSomeView(data: SomeData)
    case openAnotherView
}
```

- One case per navigable screen
- Use associated values for data passed to the screen

## Step 3: Implement GenericCoordinator

```swift
final class YourCoordinator: GenericCoordinator {
    typealias Pages = YourCoordinatorPages
    
    func route(to screen: YourCoordinatorPages) {
        switch screen {
        case .openSomeView(let data):
            openSomeView(data: data)
        case .openAnotherView:
            openAnotherView()
        }
    }
}
```

## Step 4: Navigation Helper Methods

Use extension to separate navigation logic:

```swift
extension YourCoordinator {
    private func openSomeView(data: SomeData) {
        let viewModel = SomeViewModel(data: data)
        let view = SomeView(viewModel: viewModel)
        ScreenObjectMapper.push(PModuleFactory.getModule(viewModel: viewModel, rootView: view))
    }
}
```

## Critical Rules

- ALWAYS use `PModuleFactory.getModule(viewModel:viewModel, rootView:view)` for PView screens
- ALWAYS use `ScreenObjectMapper.push()` to push (or `present` for modals)
- Never use `BaseUIHostingController` directly
- For sheets: use `tabBarController.presentViaSheetCoordinator(controller)` when available (avoids black overlay)

## Reference

- Protocol: `App/Module/Gold/TokopediaGoldMigration/GenericCoordinator/GenericCoordinator.swift`
- Example: `App/Module/TradePage/Coordinator/TradePageCoordinator.swift`
