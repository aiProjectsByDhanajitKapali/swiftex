import AppKit
import SwiftUI

struct UIBuilderView: View {
    @EnvironmentObject private var model: AppViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                designCard
                targetCard
                generateRow
                if !model.buildLog.isEmpty { logCard }
            }
            .padding(20)
        }
    }

    private var designCard: some View {
        Card("Design", systemImage: "scribble.variable") {
            TextField("Paste Figma frame URL (must include node-id)", text: $model.figmaURL, axis: .vertical)
                .lineLimit(1...3)
                .textFieldStyle(.roundedBorder)

            if !model.figmaConnected {
                Label("Connect Figma in the Panel tab first.", systemImage: "exclamationmark.triangle")
                    .font(.caption).foregroundStyle(.orange)
            }
        }
    }

    private var targetCard: some View {
        Card("Target", systemImage: "folder") {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Module").font(.caption2).foregroundStyle(.secondary)
                    TextField("Wallet", text: Binding(
                        get: { model.moduleName },
                        set: { model.setModule($0) }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 150)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Feature").font(.caption2).foregroundStyle(.secondary)
                    TextField("auto from frame", text: $model.featureFolder)
                        .textFieldStyle(.roundedBorder)
                }
            }

            HStack {
                Button("Choose output folder…") { model.pickOutputFolder() }
                Text(model.outputRoot?.path ?? "No folder selected")
                    .font(.caption)
                    .foregroundStyle(model.outputRoot == nil ? .red : .secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
    }

    private var generateRow: some View {
        HStack {
            Button {
                model.generate()
            } label: {
                if model.isBuilding {
                    ProgressView().controlSize(.small)
                    Text("Generating…")
                } else {
                    Label("Generate PView files", systemImage: "wand.and.stars")
                }
            }
            .keyboardShortcut(.return, modifiers: [.command])
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
            .disabled(!model.canBuild)
            Spacer()
            Toggle("Extended log", isOn: $model.verboseLog)
                .toggleStyle(.switch)
                .help("Log the Figma node tree, full prompt, and raw LLM response")
        }
    }

    private var logCard: some View {
        Card("Log", systemImage: "text.alignleft") {
            HStack {
                Spacer()
                Button {
                    copyLog()
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                .buttonStyle(.borderless)
                .disabled(model.buildLog.isEmpty)
                .help("Copy the full log to the clipboard")
            }
            VStack(alignment: .leading, spacing: 3) {
                ForEach(Array(model.buildLog.enumerated()), id: \.offset) { _, line in
                    Text(line)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private func copyLog() {
        let text = model.buildLog.joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}
