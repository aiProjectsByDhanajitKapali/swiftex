import SwiftUI

struct PanelView: View {
    @EnvironmentObject private var model: AppViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                backendCard
                if model.backend == .ollama { ollamaCard } else { mlxCard }
                designSourceCard
                figmaCard
                jiraCard
                skillsCard
                codebaseCard
            }
            .padding(20)
        }
    }

    private var backendCard: some View {
        Card("LLM backend", systemImage: "cpu.fill") {
            Picker("", selection: Binding(
                get: { model.backend },
                set: { model.backend = $0 }
            )) {
                ForEach(AppViewModel.LLMBackend.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented).labelsHidden()
        }
    }

    private var mlxCard: some View {
        Card("MLX", systemImage: "cpu") {
            HStack {
                Text(model.mlxBaseURL)
                    .font(.system(.callout, design: .monospaced))
                    .foregroundStyle(.secondary)
                Spacer()
                StatusPill(
                    text: model.ollamaRunning ? "Running" : "Stopped",
                    color: model.ollamaRunning ? .green : .red
                )
            }

            HStack(spacing: 10) {
                Button {
                    Task { await model.startMLX() }
                } label: { Label("Start", systemImage: "play.fill") }
                    .disabled(model.ollamaRunning || model.mlxBusy)

                Button {
                    Task { await model.stopMLX() }
                } label: { Label("Stop", systemImage: "stop.fill") }
                    .disabled(!model.ollamaRunning || model.mlxBusy)

                Button {
                    Task { await model.refreshStatus() }
                } label: { Label("Refresh", systemImage: "arrow.clockwise") }

                if model.mlxBusy { ProgressView().controlSize(.small) }
            }

            Text("vllm-mlx serves one model at a time. Embeddings still use Ollama.")
                .font(.caption).foregroundStyle(.secondary)

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Text("MODEL").font(.caption2).foregroundStyle(.secondary)
                if model.mlxModels.isEmpty {
                    Text("No MLX models downloaded. Pull one, e.g.\n`huggingface-cli download mlx-community/Qwen2.5-Coder-14B-Instruct-4bit`")
                        .font(.callout).foregroundStyle(.secondary)
                        .textSelection(.enabled)
                } else {
                    Picker("", selection: Binding(
                        get: { model.mlxModel },
                        set: { model.mlxModel = $0 }
                    )) {
                        ForEach(model.mlxModels, id: \.self) { Text($0).tag($0) }
                    }
                    .labelsHidden()
                    .frame(maxWidth: 320, alignment: .leading)
                    .disabled(model.mlxBusy)
                    if model.ollamaRunning {
                        Text("Switching model: press Stop, then Start.")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var ollamaCard: some View {
        Card("Ollama", systemImage: "cpu") {
            HStack {
                Text(model.ollamaBaseURL)
                    .font(.system(.callout, design: .monospaced))
                    .foregroundStyle(.secondary)
                Spacer()
                StatusPill(
                    text: model.ollamaRunning ? "Running" : "Stopped",
                    color: model.ollamaRunning ? .green : .red
                )
            }

            HStack(spacing: 10) {
                Button {
                    Task { await model.startOllama() }
                } label: { Label("Start", systemImage: "play.fill") }
                    .disabled(model.ollamaRunning || model.ollamaBusy)

                Button {
                    Task { await model.stopOllama() }
                } label: { Label("Stop", systemImage: "stop.fill") }
                    .disabled(!model.ollamaRunning || model.ollamaBusy)

                Button {
                    Task { await model.refreshStatus() }
                } label: { Label("Refresh", systemImage: "arrow.clockwise") }

                if model.ollamaBusy { ProgressView().controlSize(.small) }
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Text("MODEL").font(.caption2).foregroundStyle(.secondary)
                if model.models.isEmpty {
                    Text(model.ollamaRunning
                        ? "No models found. Run `ollama pull qwen2.5-coder:14b`."
                        : "Start Ollama to load models.")
                        .font(.callout).foregroundStyle(.secondary)
                } else {
                    Picker("", selection: Binding(
                        get: { model.selectedModel },
                        set: { model.selectModel($0) }
                    )) {
                        ForEach(model.models) { Text($0.name).tag($0.name) }
                    }
                    .labelsHidden()
                    .frame(maxWidth: 320, alignment: .leading)
                }
            }
        }
    }

    private var jiraCard: some View {
        Card("Jira connection", systemImage: "ticket") {
            HStack {
                Text("Jira Cloud — API-token Basic auth.")
                    .font(.callout).foregroundStyle(.secondary)
                Spacer()
                StatusPill(
                    text: model.jiraConnected ? "Connected" : "Not connected",
                    color: model.jiraConnected ? .green : .secondary
                )
            }
            TextField("site, e.g. pgb-jira.atlassian.net", text: $model.jiraSite)
                .textFieldStyle(.roundedBorder)
            TextField("your Atlassian email", text: $model.jiraEmail)
                .textFieldStyle(.roundedBorder)
            TextField("board ID for sprint (e.g. 797) — optional", text: $model.jiraBoardId)
                .textFieldStyle(.roundedBorder)
            HStack {
                SecureField("API token", text: $model.jiraToken)
                    .textFieldStyle(.roundedBorder)
                Button("Save & test") { Task { await model.saveJiraConfigAndTest() } }
            }
            if model.jiraConnected, let account = model.jiraAccount {
                Label(account, systemImage: "person.crop.circle").font(.callout)
            } else if !model.jiraStatusMessage.isEmpty {
                Text(model.jiraStatusMessage).font(.caption).foregroundStyle(.red)
            }
        }
    }

    private var skillsCard: some View {
        Card("UI Skills", systemImage: "books.vertical") {
            Text("Swiftex reads how to build PViews from these markdown skills — edit them to change generation, no rebuild.")
                .font(.callout).foregroundStyle(.secondary)

            if !model.skillSources.isEmpty {
                Label(model.skillSources.joined(separator: ", "), systemImage: "doc.text")
                    .font(.callout)
            }
            Text(model.skillsSummary)
                .font(.caption).foregroundStyle(.secondary)
                .lineLimit(1).truncationMode(.middle)

            HStack {
                Button("Choose skills folder…") { model.pickSkillsFolder() }
                Button("Reload") { Task { await model.refreshSkills() } }
            }
        }
    }

    private var designSourceCard: some View {
        Card("Design source", systemImage: "square.on.square.dashed") {
            HStack {
                Text("Figma Dev Mode MCP (richer: code + tokens + real copy).")
                    .font(.callout).foregroundStyle(.secondary)
                Spacer()
                StatusPill(
                    text: model.mcpAvailable ? "MCP available" : "MCP off",
                    color: model.mcpAvailable ? .green : .secondary
                )
            }
            Toggle("Prefer Figma Dev Mode MCP (fall back to REST)", isOn: $model.useMCP)
                .toggleStyle(.switch)
            if model.useMCP && !model.mcpAvailable {
                Text("Open the Figma desktop app and enable the Dev Mode MCP server (port 3845). Until then, the REST token below is used.")
                    .font(.caption).foregroundStyle(.orange)
            }
        }
    }

    private var codebaseCard: some View {
        Card("Codebase examples (RAG)", systemImage: "text.magnifyingglass") {
            HStack {
                Text("Index real PView / bottom-sheet files; inject similar ones to ground generation.")
                    .font(.callout).foregroundStyle(.secondary)
                Spacer()
                StatusPill(
                    text: model.indexCount > 0 ? "\(model.indexCount) indexed" : "no index",
                    color: model.indexCount > 0 ? .green : .secondary
                )
            }
            HStack {
                Button("Choose codebase folder…") { model.pickCorpusFolder() }
                Text(model.corpusRoot?.path ?? "No folder selected")
                    .font(.caption).foregroundStyle(.secondary)
                    .lineLimit(1).truncationMode(.middle)
            }
            HStack(spacing: 10) {
                Button {
                    model.buildIndex()
                } label: {
                    if model.isIndexing { ProgressView().controlSize(.small) }
                    Text(model.indexCount > 0 ? "Rebuild index" : "Build index")
                }
                .disabled(model.corpusRoot == nil || model.isIndexing)
                if !model.indexProgress.isEmpty {
                    Text(model.indexProgress).font(.caption).foregroundStyle(.secondary)
                }
            }
            Toggle("Use codebase examples during generation", isOn: $model.useRAG)
                .toggleStyle(.switch)
                .disabled(model.indexCount == 0)
        }
    }

    private var figmaCard: some View {
        Card("Figma connection", systemImage: "link") {
            HStack {
                Text("Personal access token used by UI Builder.")
                    .font(.callout).foregroundStyle(.secondary)
                Spacer()
                StatusPill(
                    text: model.figmaConnected ? "Connected" : "Not connected",
                    color: model.figmaConnected ? .green : .secondary
                )
            }

            HStack {
                SecureField("figd_…", text: $model.figmaToken)
                    .textFieldStyle(.roundedBorder)
                Button("Save & test") { Task { await model.saveTokenAndTest() } }
            }

            if model.figmaConnected, let account = model.figmaAccount {
                Label(account, systemImage: "person.crop.circle")
                    .font(.callout)
            } else if !model.figmaStatusMessage.isEmpty {
                Text(model.figmaStatusMessage)
                    .font(.caption)
                    .foregroundStyle(model.figmaConnected ? Color.secondary : Color.red)
            }
        }
    }
}
