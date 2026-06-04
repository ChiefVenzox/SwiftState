import SwiftUI
import SwiftState

struct StarterState: State {
    var counter: Int = 0
    var note: String = ""
    var isLoading: Bool = false
    var message: String?
}

enum StarterAction: Action {
    case increment
    case decrement
    case setNote(String)
    case loadMessage
    case messageLoaded(String)
    case messageFailed(String)
}

let starterReducer: Reducer<StarterState> = { state, action in
    guard let action = action as? StarterAction else { return }
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

let starterEffectReducer: EffectReducer<StarterState> = { state, action in
    guard let action = action as? StarterAction else { return .none }
    switch action {
    case .loadMessage:
        state.isLoading = true
        state.message = nil
        return .run { dispatch in
            do {
                try await Task.sleep(nanoseconds: 600_000_000)
                await dispatch(StarterAction.messageLoaded("Loaded with SwiftState Effects"))
            } catch {
                await dispatch(StarterAction.messageFailed(error.localizedDescription))
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
        starterReducer(&state, action)
        return .none
    }
}

@main
struct SwiftStateStarterApp: App {
    @StateObject private var store = TimeTravelStore(
        initialState: StarterState(),
        effectReducer: starterEffectReducer,
        middlewares: [createLoggerMiddleware()]
    )

    var body: some Scene {
        WindowGroup {
            StarterView()
                .environmentObject(store)
        }
    }
}

struct StarterView: View {
    @EnvironmentObject var store: TimeTravelStore<StarterState>

    var body: some View {
        ZStack {
            NavigationView {
                Form {
                    Section("Counter") {
                        Text("Count: \(store.state.counter)")
                            .font(.title2.weight(.semibold))

                        HStack {
                            Button("Decrement") {
                                store.dispatch(StarterAction.decrement)
                            }

                            Button("Increment") {
                                store.dispatch(StarterAction.increment)
                            }
                        }
                    }

                    Section("Binding") {
                        TextField(
                            "Write a note",
                            text: store.binding(\.note, action: StarterAction.setNote)
                        )

                        if !store.state.note.isEmpty {
                            Text(store.state.note)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Section("Async Effect") {
                        Button(store.state.isLoading ? "Loading..." : "Load Message") {
                            store.dispatch(StarterAction.loadMessage)
                        }
                        .disabled(store.state.isLoading)

                        if let message = store.state.message {
                            Text(message)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .navigationTitle("SwiftState")
            }

            #if DEBUG
            TimeTravelDebuggerView(store: store)
            #endif
        }
    }
}
