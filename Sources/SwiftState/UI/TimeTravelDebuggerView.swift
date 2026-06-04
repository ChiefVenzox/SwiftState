import SwiftUI

/// A premium, glassmorphic floating debugger panel for `TimeTravelStore`.
/// Allows developers to visualize action dispatch history, scrub through states using a slider,
/// perform undo/redo operations, and inspect the state payload in real-time.
public struct TimeTravelDebuggerView<S: State>: View {
    
    @ObservedObject public var store: TimeTravelStore<S>
    
    // UI Local State
    @SwiftUI.State private var isCollapsed: Bool = true
    @SwiftUI.State private var dragOffset: CGSize = .zero
    @SwiftUI.State private var position: CGPoint = CGPoint(x: 180, y: 300)
    @SwiftUI.State private var selectedTab: DebugTab = .actions
    
    enum DebugTab {
        case actions
        case stateJSON
    }
    
    public init(store: TimeTravelStore<S>) {
        self.store = store
    }
    
    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                if isCollapsed {
                    collapsedBadge
                        .position(position)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    self.dragOffset = value.translation
                                }
                                .onEnded { value in
                                    var newPosition = self.position
                                    newPosition.x += value.translation.width
                                    newPosition.y += value.translation.height
                                    self.position = newPosition
                                    self.dragOffset = .zero
                                    
                                    // Keep badge inside screen bounds
                                    keepInBounds(geometry: geometry)
                                }
                        )
                } else {
                    expandedPanel(geometry: geometry)
                        .frame(width: 320, height: 420)
                        .position(position)
                        .gesture(
                            DragGesture(minimumDistance: 10)
                                .onChanged { value in
                                    // Only drag via the header area to prevent conflicts with list scrolls
                                    if value.startLocation.y < 50 {
                                        self.dragOffset = value.translation
                                    }
                                }
                                .onEnded { value in
                                    if value.startLocation.y < 50 {
                                        var newPosition = self.position
                                        newPosition.x += value.translation.width
                                        newPosition.y += value.translation.height
                                        self.position = newPosition
                                        self.dragOffset = .zero
                                        keepInBounds(geometry: geometry)
                                    }
                                }
                        )
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.82), value: isCollapsed)
            .onAppear {
                // Initialize default position in bottom right corner
                self.position = CGPoint(
                    x: geometry.size.width - 70,
                    y: geometry.size.height - 100
                )
            }
        }
    }
    
    // MARK: - Collapsed Badge
    private var collapsedBadge: some View {
        Button(action: { isCollapsed = false }) {
            ZStack {
                Circle()
                    .fill(SwiftStateUI.Color.background)
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [SwiftStateUI.Color.accentPurple, SwiftStateUI.Color.accentCyan],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                    )
                
                VStack(spacing: 2) {
                    Image(systemName: "clock.arrow.2.circlepath")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(SwiftStateUI.Color.accentCyan)
                    
                    Text("\(store.currentHistoryIndex)/\(store.history.count - 1)")
                        .font(SwiftStateUI.Font.codeCaption)
                        .foregroundColor(SwiftStateUI.Color.primaryText)
                }
            }
            .shadow(color: SwiftStateUI.Color.accentPurple.opacity(0.3), radius: 10, x: 0, y: 4)
        }
        .frame(width: 60, height: 60)
        .offset(dragOffset)
    }
    
    // MARK: - Expanded Panel
    private func expandedPanel(geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            // Header - Drag Handle & Control Panel
            headerView
            
            // Timeline Scrubber
            timelineScrubberView
            
            // Tab Selector
            tabSelectorView
            
            // Tab Content
            contentView
            
            // Footer - Action Buttons
            footerControlView
        }
        .background(
            RoundedRectangle(cornerRadius: SwiftStateUI.Layout.cornerRadius)
                .fill(SwiftStateUI.Color.cardBackground)
                .background(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: SwiftStateUI.Layout.cornerRadius)
                        .stroke(SwiftStateUI.Color.border, lineWidth: SwiftStateUI.Layout.borderSize)
                )
        )
        .cornerRadius(SwiftStateUI.Layout.cornerRadius)
        .shadow(color: Color.black.opacity(0.4), radius: 20, x: 0, y: 10)
        .offset(dragOffset)
    }
    
    // MARK: - Header View
    private var headerView: some View {
        HStack {
            Image(systemName: "cpu")
                .foregroundColor(SwiftStateUI.Color.accentPurple)
                .font(.system(size: 16, weight: .bold))
            
            Text("SwiftState")
                .font(SwiftStateUI.Font.heading)
                .foregroundColor(SwiftStateUI.Color.primaryText)
            
            Text("DEBUG")
                .font(.system(size: 9, weight: .bold))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(SwiftStateUI.Color.accentPurple.opacity(0.2))
                .foregroundColor(SwiftStateUI.Color.accentPurple)
                .cornerRadius(4)
            
            Spacer()
            
            Button(action: { isCollapsed = true }) {
                Image(systemName: "minus.circle.fill")
                    .foregroundColor(SwiftStateUI.Color.secondaryText)
                    .font(.system(size: 18))
            }
        }
        .padding(.horizontal, SwiftStateUI.Layout.padding)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }
    
    // MARK: - Timeline Scrubber
    private var timelineScrubberView: some View {
        VStack(spacing: 4) {
            HStack {
                Text("Timeline")
                    .font(SwiftStateUI.Font.codeCaption)
                    .foregroundColor(SwiftStateUI.Color.secondaryText)
                Spacer()
                Text("State \(store.currentHistoryIndex) / \(store.history.count - 1)")
                    .font(SwiftStateUI.Font.codeCaption)
                    .foregroundColor(SwiftStateUI.Color.accentCyan)
            }
            
            Slider(
                value: Binding(
                    get: { Double(store.currentHistoryIndex) },
                    set: { store.jump(to: Int($0)) }
                ),
                in: 0...Double(max(1, store.history.count - 1)),
                step: 1.0
            )
            .accentColor(SwiftStateUI.Color.accentCyan)
        }
        .padding(.horizontal, SwiftStateUI.Layout.padding)
        .padding(.vertical, 6)
    }
    
    // MARK: - Tab Selector
    private var tabSelectorView: some View {
        HStack(spacing: 0) {
            Button(action: { selectedTab = .actions }) {
                VStack(spacing: 6) {
                    Text("ACTIONS (\(store.actionHistory.count))")
                        .font(SwiftStateUI.Font.codeTitle)
                        .foregroundColor(selectedTab == .actions ? SwiftStateUI.Color.accentPurple : SwiftStateUI.Color.secondaryText)
                    
                    Rectangle()
                        .fill(selectedTab == .actions ? SwiftStateUI.Color.accentPurple : Color.clear)
                        .frame(height: 2)
                }
            }
            .frame(maxWidth: .infinity)
            
            Button(action: { selectedTab = .stateJSON }) {
                VStack(spacing: 6) {
                    Text("STATE JSON")
                        .font(SwiftStateUI.Font.codeTitle)
                        .foregroundColor(selectedTab == .stateJSON ? SwiftStateUI.Color.accentPurple : SwiftStateUI.Color.secondaryText)
                    
                    Rectangle()
                        .fill(selectedTab == .stateJSON ? SwiftStateUI.Color.accentPurple : Color.clear)
                        .frame(height: 2)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.top, 4)
    }
    
    // MARK: - Tab Content
    private var contentView: some View {
        Group {
            switch selectedTab {
            case .actions:
                actionsListView
            case .stateJSON:
                jsonInspectorView
            }
        }
        .frame(maxHeight: .infinity)
        .background(Color.black.opacity(0.2))
    }
    
    // MARK: - Actions List Tab
    private var actionsListView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    // Initial State Entry
                    Button(action: { store.jump(to: 0) }) {
                        HStack {
                            Circle()
                                .fill(store.currentHistoryIndex == 0 ? SwiftStateUI.Color.accentCyan : SwiftStateUI.Color.secondaryText)
                                .frame(width: 8, height: 8)
                            
                            Text("Initial State")
                                .font(SwiftStateUI.Font.codeBody)
                                .fontWeight(.bold)
                                .foregroundColor(store.currentHistoryIndex == 0 ? SwiftStateUI.Color.accentCyan : SwiftStateUI.Color.primaryText)
                            
                            Spacer()
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .background(store.currentHistoryIndex == 0 ? SwiftStateUI.Color.activeHighlight : Color.clear)
                        .cornerRadius(6)
                    }
                    .id(0)
                    
                    // List of Actions
                    ForEach(store.historyEntries.dropFirst()) { entry in
                        let actionName = entry.action.map(String.init(describing:)) ?? "Unknown Action"
                        let stateIndex = entry.index
                        let isActive = store.currentHistoryIndex == stateIndex
                        let isUndoneFuture = stateIndex > store.currentHistoryIndex
                        
                        Button(action: { store.jump(to: stateIndex) }) {
                            HStack {
                                Rectangle()
                                    .fill(isActive ? SwiftStateUI.Color.accentPurple : (isUndoneFuture ? Color.gray.opacity(0.3) : SwiftStateUI.Color.accentPurple.opacity(0.4)))
                                    .frame(width: 4, height: 16)
                                    .cornerRadius(2)
                                
                                Text(actionName)
                                    .font(SwiftStateUI.Font.codeBody)
                                    .strikethrough(isUndoneFuture)
                                    .foregroundColor(isActive ? SwiftStateUI.Color.accentPurple : (isUndoneFuture ? SwiftStateUI.Color.secondaryText : SwiftStateUI.Color.primaryText))
                                
                                Spacer()
                                
                                Text("#\(stateIndex)")
                                    .font(SwiftStateUI.Font.codeCaption)
                                    .foregroundColor(SwiftStateUI.Color.secondaryText)
                            }
                            .padding(.vertical, 6)
                            .padding(.horizontal, 10)
                            .background(isActive ? SwiftStateUI.Color.activeHighlight : Color.clear)
                            .cornerRadius(6)
                        }
                        .id(stateIndex)
                    }
                }
                .padding(8)
            }
            .onAppear {
                // Scroll to active index
                proxy.scrollTo(store.currentHistoryIndex, anchor: .center)
            }
            .onChange(of: store.currentHistoryIndex) { index in
                withAnimation {
                    proxy.scrollTo(index, anchor: .center)
                }
            }
        }
    }
    
    // MARK: - JSON State Tab
    private var jsonInspectorView: some View {
        ScrollView {
            VStack(alignment: .leading) {
                Text(prettyJSONString)
                    .font(SwiftStateUI.Font.codeBody)
                    .foregroundColor(SwiftStateUI.Color.accentGreen)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
    
    private var prettyJSONString: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(store.state),
              let string = String(data: data, encoding: .utf8) else {
            return "{ \"error\": \"Could not encode state\" }"
        }
        return string
    }
    
    // MARK: - Footer Control Panel
    private var footerControlView: some View {
        HStack(spacing: 12) {
            Button(action: { store.undo() }) {
                HStack {
                    Image(systemName: "arrow.uturn.backward")
                    Text("Undo")
                }
                .font(SwiftStateUI.Font.codeTitle)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(store.canUndo ? SwiftStateUI.Color.accentPurple.opacity(0.2) : Color.clear)
                .foregroundColor(store.canUndo ? SwiftStateUI.Color.accentPurple : Color.gray.opacity(0.4))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(store.canUndo ? SwiftStateUI.Color.accentPurple.opacity(0.4) : Color.gray.opacity(0.1), lineWidth: 1)
                )
            }
            .disabled(!store.canUndo)
            
            Button(action: { store.clearHistory() }) {
                Image(systemName: "trash")
                    .font(SwiftStateUI.Font.codeTitle)
                    .frame(width: 42, height: 38)
                    .background(store.history.count > 1 ? SwiftStateUI.Color.accentCyan.opacity(0.16) : Color.clear)
                    .foregroundColor(store.history.count > 1 ? SwiftStateUI.Color.accentCyan : Color.gray.opacity(0.4))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(store.history.count > 1 ? SwiftStateUI.Color.accentCyan.opacity(0.35) : Color.gray.opacity(0.1), lineWidth: 1)
                    )
            }
            .disabled(store.history.count <= 1)
            .help("Clear history")
            
            Button(action: { store.redo() }) {
                HStack {
                    Text("Redo")
                    Image(systemName: "arrow.uturn.forward")
                }
                .font(SwiftStateUI.Font.codeTitle)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(store.canRedo ? SwiftStateUI.Color.accentPurple.opacity(0.2) : Color.clear)
                .foregroundColor(store.canRedo ? SwiftStateUI.Color.accentPurple : Color.gray.opacity(0.4))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(store.canRedo ? SwiftStateUI.Color.accentPurple.opacity(0.4) : Color.gray.opacity(0.1), lineWidth: 1)
                )
            }
            .disabled(!store.canRedo)
        }
        .padding(SwiftStateUI.Layout.padding)
    }
    
    // MARK: - Bounds Calculation
    private func keepInBounds(geometry: GeometryProxy) {
        let screenWidth = geometry.size.width
        let screenHeight = geometry.size.height
        let panelWidth: CGFloat = isCollapsed ? 30 : 160
        let panelHeight: CGFloat = isCollapsed ? 30 : 210
        
        var newPosition = position
        newPosition.x = min(max(panelWidth, newPosition.x), screenWidth - panelWidth)
        newPosition.y = min(max(panelHeight, newPosition.y), screenHeight - panelHeight)
        self.position = newPosition
    }
}
