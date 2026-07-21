import SwiftUI

enum SwiftexSection: String, CaseIterable, Identifiable {
    case panel = "Panel"
    case prReview = "PR Review"
    case uiBuilder = "UI Builder"
    case api = "API"
    case jira = "Jira"
    case codeChat = "CodeChat"

    var id: String { rawValue }
    var icon: String {
        switch self {
        case .panel: return "slider.horizontal.3"
        case .prReview: return "checkmark.shield"
        case .uiBuilder: return "wand.and.stars"
        case .api: return "network"
        case .jira: return "ticket"
        case .codeChat: return "bubble.left.and.text.bubble.right"
        }
    }
}

struct ContentView: View {
    @StateObject private var model = AppViewModel()
    @State private var selection: SwiftexSection = .panel

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                SwiftexLogo()
                List(SwiftexSection.allCases, selection: $selection) { section in
                    Label(section.rawValue, systemImage: section.icon).tag(section)
                }
                .listStyle(.sidebar)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 240)
        } detail: {
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .background(AppBackground())
                .toolbar {
                    if model.isWorking {
                        ToolbarItem(placement: .automatic) {
                            Button(role: .destructive) {
                                model.stopWork()
                            } label: {
                                Label("Stop", systemImage: "stop.fill")
                            }
                            .help("Stop the current task")
                        }
                    }
                    ToolbarItem(placement: .automatic) {
                        StatusPill(
                            text: model.ollamaRunning ? "\(model.backend.rawValue) running" : "\(model.backend.rawValue) down",
                            color: model.ollamaRunning ? .green : .red
                        )
                    }
                }
        }
        .environmentObject(model)
        .task { await model.refreshStatus() }
    }

    @ViewBuilder
    private var detail: some View {
        switch selection {
        case .panel: PanelView()
        case .prReview: PRReviewView()
        case .uiBuilder: UIBuilderView()
        case .api: ApiView()
        case .jira: JiraView()
        case .codeChat: CodeChatView()
        }
    }
}
