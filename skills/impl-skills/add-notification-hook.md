---
name: add-notification-hook
description: Add a new NotificationCenter notification with proper definition, post, and observer lifecycle. Use when adding cross-module events.
owner: Ram Sharma

---

# Add NotificationCenter Hook

Add a new notification following the project pattern. Centralize names to avoid typos and coupling.

## Step 1: Define Notification Name

Add to `App/extnNotification/extnNotifications.swift`:

```swift
extension Notification.Name {
    // ... existing names ...
    static let yourNewNotification = Notification.Name(rawValue: "yourNewNotification")
}
```

- Use camelCase for the raw value
- Match the static property name

## Step 2: Post the Notification

When the event occurs:

```swift
NotificationCenter.default.post(
    name: .yourNewNotification,
    object: nil,
    userInfo: ["key": value]  // optional
)
```

- Prefer `userInfo` for payload; avoid `object` for heavy data
- Document what the notification means in a comment near the post

## Step 3: Observe (SwiftUI / Combine)

In ViewModel:

```swift
NotificationCenter.default.publisher(for: .yourNewNotification)
    .compactMap { $0.userInfo?["key"] as? ExpectedType }
    .sink { [weak self] value in
        // handle
    }
    .store(in: &cancellables)
```

- Use `[weak self]` in closures
- Store in `cancellables`; no need to removeObserver (Combine handles it)

## Step 4: Observe (UIKit / addObserver)

```swift
NotificationCenter.default.addObserver(
    self,
    selector: #selector(handleNotification),
    name: .yourNewNotification,
    object: nil
)
```

- MUST call `NotificationCenter.default.removeObserver(self)` in deinit (or when no longer needed)

## Critical Rules

- Define ALL names in `extnNotifications.swift`; never use raw strings
- Document purpose: who posts, who observes, when it fires
- For ViewModels: prefer `publisher(for:)` + `sink` + `cancellables` (auto cleanup)
- For UIKit: always pair addObserver with removeObserver

## Reference

- Names file: `App/extnNotification/extnNotifications.swift`
- Plan: `.cursor/plans/skill_plans/Rules_Skills_Hooks_Audit_Plan_REFERENCE.md`
