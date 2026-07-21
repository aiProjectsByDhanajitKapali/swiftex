import SwiftUI

struct CodeChatView: View {
    @EnvironmentObject private var model: AppViewModel

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            configBar
            Divider()
            transcript
            Divider()
            inputBar
        }
    }

    private var header: some View {
        HStack {
            Label("CodeChat — ask or generate", systemImage: "bubble.left.and.text.bubble.right")
                .font(.headline)
            Spacer()
            Toggle("Debug", isOn: $model.verboseChat).toggleStyle(.switch)
                .help("Show retrieval + the prompt sent to the LLM")
            Button("Clear") { model.clearCodeChat() }
                .buttonStyle(.borderless)
                .disabled(model.codeChatMessages.isEmpty)
        }
        .padding(16)
    }

    private var configBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Output folder for generated files.
            HStack(spacing: 10) {
                Button("Output folder…") { model.pickCodeChatFolder() }
                Text(model.codeChatOutputRoot?.path ?? "where generated files are written")
                    .font(.caption).foregroundStyle(.secondary)
                    .lineLimit(1).truncationMode(.middle)
            }

            // Codebase context for "Codebase examples" — add one folder per tap.
            HStack(spacing: 10) {
                Button("Add folder") { model.addChatCorpusFolder() }
                Button {
                    model.buildChatIndex()
                } label: {
                    if model.isIndexingChat { ProgressView().controlSize(.small) }
                    Text(model.chatIndexCount > 0 ? "Reindex" : "Index")
                }
                .disabled(model.chatCorpusRoots.isEmpty || model.isIndexingChat)
                if !model.chatIndexProgress.isEmpty {
                    Text(model.chatIndexProgress).font(.caption2).foregroundStyle(.secondary)
                        .lineLimit(1).truncationMode(.middle)
                }
                Spacer()
                Toggle("Codebase examples", isOn: $model.codeChatUseRAG).toggleStyle(.switch)
                    .help("Ground answers & generation in the indexed folders below")
            }

            if !model.chatCorpusRoots.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(model.chatCorpusRoots, id: \.self) { url in
                            HStack(spacing: 4) {
                                Image(systemName: "folder")
                                Text(url.lastPathComponent)
                                Button { model.removeChatCorpusFolder(url) } label: {
                                    Image(systemName: "xmark.circle.fill")
                                }
                                .buttonStyle(.borderless)
                            }
                            .font(.caption2)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Capsule().fill(Color(nsColor: .controlBackgroundColor)))
                            .help(url.path)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 8)
    }

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if model.codeChatMessages.isEmpty {
                        Text("Ask about the codebase (\"what is enableStateManager()?\") or ask to build something (\"create an empty PView called WalletEmptyView\"). It keeps conversation context, and generation writes files to the chosen folder.")
                            .font(.callout).foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 8)
                    }
                    ForEach(model.codeChatMessages) { message in
                        bubble(message).id(message.id)
                    }
                    if model.isCodeChatBusy {
                        HStack(spacing: 6) { ProgressView().controlSize(.small); Text("Working…").foregroundStyle(.secondary) }
                    }
                }
                .padding(16)
            }
            .onChange(of: model.codeChatMessages.count) { _ in
                if let last = model.codeChatMessages.last { proxy.scrollTo(last.id, anchor: .bottom) }
            }
        }
    }

    private func bubble(_ message: CodeChatMessage) -> some View {
        let isUser = message.role == .user
        return HStack {
            if isUser { Spacer(minLength: 40) }
            VStack(alignment: .leading, spacing: 6) {
                Text(isUser ? "You" : "Swiftex").font(.caption2).foregroundStyle(.secondary)
                if isUser {
                    Text(message.text).textSelection(.enabled)
                } else {
                    MarkdownText(markdown: message.text)
                    if !message.files.isEmpty {
                        ForEach(message.files, id: \.self) { path in
                            Label((path as NSString).lastPathComponent, systemImage: "doc.badge.plus")
                                .font(.system(.caption, design: .monospaced)).help(path)
                        }
                    }
                    if let debug = message.debug {
                        DisclosureGroup("Debug") {
                            ScrollView(.horizontal, showsIndicators: true) {
                                Text(debug).font(.system(.caption2, design: .monospaced))
                                    .textSelection(.enabled).padding(8)
                            }
                            .frame(maxHeight: 220)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Color.black.opacity(0.15)))
                        }
                        .font(.caption)
                    }
                }
            }
            .padding(10)
            .background(
                isUser ? AnyShapeStyle(Color.accentColor.opacity(0.22)) : AnyShapeStyle(.ultraThinMaterial),
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(.white.opacity(0.06))
            )
            if !isUser { Spacer(minLength: 40) }
        }
    }

    private var inputBar: some View {
        HStack(spacing: 8) {
            TextField("Ask, or describe what to generate…", text: $model.codeChatInput, axis: .vertical)
                .lineLimit(1...4)
                .textFieldStyle(.roundedBorder)
                .onSubmit { model.sendCodeChat() }
            Button {
                model.sendCodeChat()
            } label: {
                if model.isCodeChatBusy { ProgressView().controlSize(.small) }
                Image(systemName: "paperplane.fill")
            }
            .keyboardShortcut(.return, modifiers: [.command])
            .disabled(!model.canCodeChat)
        }
        .padding(12)
    }
}
