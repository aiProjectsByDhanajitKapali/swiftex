import SwiftUI

struct ApiView: View {
    @EnvironmentObject private var model: AppViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                viewModelCard
                curlCard
                if model.apiParsed != nil { gateCard }
                generateRow
                if !model.apiProposed.isEmpty { reviewCard }
            }
            .padding(20)
        }
    }

    private var viewModelCard: some View {
        Card("Target ViewModel", systemImage: "doc.text") {
            HStack {
                Button("Choose ViewModel…") { model.pickAPIViewModel() }
                Text(model.apiVMPath?.lastPathComponent ?? "No ViewModel selected")
                    .font(.caption).foregroundStyle(model.apiVMPath == nil ? .red : .secondary)
                    .lineLimit(1).truncationMode(.middle)
            }
        }
    }

    private var curlCard: some View {
        Card("cURL", systemImage: "terminal") {
            TextField("Paste a cURL command…", text: $model.apiCurl, axis: .vertical)
                .lineLimit(3...10)
                .font(.system(.callout, design: .monospaced))
                .textFieldStyle(.roundedBorder)
            HStack {
                Button("Parse") { model.parseCurl() }
                    .disabled(model.apiCurl.trimmed.isEmpty)
                if !model.apiStatus.isEmpty {
                    Text(model.apiStatus).font(.caption).foregroundStyle(.secondary)
                        .lineLimit(1).truncationMode(.middle)
                }
            }
        }
    }

    private var gateCard: some View {
        Card("Integration", systemImage: "slider.horizontal.3") {
            VStack(alignment: .leading, spacing: 4) {
                Text("TRIGGER").font(.caption2).foregroundStyle(.secondary)
                Picker("", selection: $model.apiTrigger) {
                    ForEach(ApiTrigger.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented).labelsHidden()
            }

            if !model.apiParamMappings.isEmpty {
                Text("PARAM SOURCES").font(.caption2).foregroundStyle(.secondary)
                ForEach($model.apiParamMappings) { $mapping in
                    HStack(spacing: 8) {
                        Text(mapping.name)
                            .font(.system(.caption, design: .monospaced))
                            .frame(width: 120, alignment: .leading)
                        Picker("", selection: $mapping.source) {
                            ForEach(ApiParamSource.allCases) { Text($0.rawValue).tag($0) }
                        }
                        .labelsHidden().frame(width: 150)
                        TextField("property / value", text: $mapping.value)
                            .textFieldStyle(.roundedBorder)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("RESPONSE JSON (for the model)").font(.caption2).foregroundStyle(.secondary)
                TextField("{ \"data\": { … } }", text: $model.apiResponseJSON, axis: .vertical)
                    .lineLimit(3...8)
                    .font(.system(.caption, design: .monospaced))
                    .textFieldStyle(.roundedBorder)
            }
        }
    }

    private var generateRow: some View {
        HStack {
            Button {
                model.generateAPI()
            } label: {
                if model.isGeneratingApi { ProgressView().controlSize(.small) }
                Label("Generate changes", systemImage: "wand.and.stars")
            }
            .controlSize(.large).buttonStyle(.borderedProminent)
            .disabled(!model.canGenerateApi)
            Spacer()
        }
    }

    private var reviewCard: some View {
        Card("Review changes", systemImage: "checklist") {
            ForEach($model.apiProposed) { $file in
                DisclosureGroup {
                    ScrollView(.horizontal, showsIndicators: true) {
                        Text(file.newContent)
                            .font(.system(.caption2, design: .monospaced))
                            .textSelection(.enabled)
                            .padding(8)
                    }
                    .frame(maxHeight: 260)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.black.opacity(0.15)))
                } label: {
                    HStack {
                        Toggle("", isOn: $file.apply).labelsHidden()
                        Text(file.relativePath)
                            .font(.system(.caption, design: .monospaced))
                            .lineLimit(1).truncationMode(.middle)
                        StatusPill(text: file.isNew ? "new" : "modified",
                                   color: file.isNew ? .green : .blue)
                    }
                }
            }
            HStack {
                Button("Apply approved") { model.applyApprovedApiFiles() }
                    .buttonStyle(.borderedProminent)
                Text("Writes the checked files into the repo.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(.top, 4)
        }
    }
}
