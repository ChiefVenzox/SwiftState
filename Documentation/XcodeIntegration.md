# Xcode Integration Guide

Use this guide to add SwiftState to a SwiftUI app from Xcode and wire it into your app entry point, views, async effects, and debug tooling.

## Requirements

- Xcode 14 or newer
- Swift 5.7 or newer
- iOS 15, macOS 12, tvOS 15, or watchOS 8 and newer

## Add SwiftState With Xcode

1. Open your app in Xcode.
2. Select `File > Add Package Dependencies...`.
3. Paste the package URL:

```text
https://github.com/ChiefVenzox/SwiftState.git
```

4. Choose the dependency rule:

```text
Branch: main
```

Use the latest released version instead when a release tag is available for the APIs you need.

5. Add the `SwiftState` product to your app target.

## Create App State

```swift
import SwiftState

struct AppState: State {
    var counter: Int = 0
    var note: String = ""
    var isLoading: Bool = false
    var message: String?
}

enum AppAction: Action {
    case increment
    case decrement
    case setNote(String)
    case loadMessage
    case messageLoaded(String)
    case messageFailed(String)
}
```

## Add Reducers And Effects

Keep synchronous state updates in a standard reducer:

```swift
let appReducer: Reducer<AppState> = { state, action in
    guard let action = action as? AppAction else { return }
    switch action {
    case .increment:
        state.counter += 1
    case .decrement:
        state.counter -= 1
    case .setNote(let note):
        state.note = note
    case .loadMessage, .messageLoaded, .messageFailed:
        break
    }
}
```

Use an effect reducer for async work:

```swift
let appEffectReducer: EffectReducer<AppState> = { state, action in
    guard let action = action as? AppAction else { return .none }
    switch action {
    case .loadMessage:
        state.isLoading = true
        state.message = nil
        return .run { dispatch in
            do {
                try await Task.sleep(nanoseconds: 500_000_000)
                await dispatch(AppAction.messageLoaded("Loaded from an async effect"))
            } catch {
                await dispatch(AppAction.messageFailed(error.localizedDescription))
            }
        }
    case .messageLoaded(let message):
        state.isLoading = false
        state.message = message
        return .none
    case .messageFailed(let message):
        state.isLoading = false
        state.message = message
        return .none
    default:
        appReducer(&state, action)
        return .none
    }
}
```

## Install The Store In Your App

Create the store once at the app entry point and pass it through SwiftUI with `environmentObject`.

```swift
import SwiftUI
import SwiftState

@main
struct MyApp: App {
    @StateObject private var store = TimeTravelStore(
        initialState: AppState(),
        effectReducer: appEffectReducer,
        middlewares: [createLoggerMiddleware()]
    )

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
    }
}
```

For production-only apps that do not need debug history, use `Store` instead:

```swift
@StateObject private var store = Store(
    initialState: AppState(),
    effectReducer: appEffectReducer,
    middlewares: [createLoggerMiddleware()]
)
```

## Use The Store In SwiftUI

```swift
struct ContentView: View {
    @EnvironmentObject var store: TimeTravelStore<AppState>

    var body: some View {
        ZStack {
            Form {
                Section("Counter") {
                    Text("Count: \(store.state.counter)")
                    Button("Increment") {
                        store.dispatch(AppAction.increment)
                    }
                    Button("Decrement") {
                        store.dispatch(AppAction.decrement)
                    }
                }

                Section("Binding") {
                    TextField(
                        "Note",
                        text: store.binding(\.note, action: AppAction.setNote)
                    )
                }

                Section("Async Effect") {
                    Button(store.state.isLoading ? "Loading..." : "Load Message") {
                        store.dispatch(AppAction.loadMessage)
                    }
                    .disabled(store.state.isLoading)

                    if let message = store.state.message {
                        Text(message)
                    }
                }
            }

            #if DEBUG
            TimeTravelDebuggerView(store: store)
            #endif
        }
    }
}
```

## Recommended App Structure

For a small app:

```text
App/
  MyApp.swift
  AppState.swift
  AppReducer.swift
  ContentView.swift
```

For a larger app:

```text
Features/
  Profile/
    ProfileState.swift
    ProfileAction.swift
    ProfileReducer.swift
    ProfileView.swift
  Settings/
    SettingsState.swift
    SettingsAction.swift
    SettingsReducer.swift
    SettingsView.swift
App/
  AppState.swift
  AppReducer.swift
  MyApp.swift
```

Compose larger reducers with `combineReducers`, `combineEffectReducers`, and `pullback`.

## Release Builds

Keep `TimeTravelDebuggerView` behind `#if DEBUG` so it never appears in App Store builds:

```swift
#if DEBUG
TimeTravelDebuggerView(store: store)
#endif
```

You can still use `TimeTravelStore` in debug builds and switch to `Store` for release-oriented examples if you want to avoid retaining history.
