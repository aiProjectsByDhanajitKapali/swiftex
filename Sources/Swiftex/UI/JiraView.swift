import SwiftUI

struct JiraView: View {
    @EnvironmentObject private var model: AppViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if model.jiraConnected {
                    filterBar
                    issuesHeader
                    if model.jiraIssues.isEmpty && !model.isLoadingIssues {
                        Text("No issues for this filter.")
                            .font(.callout).foregroundStyle(.secondary)
                    }
                    ForEach(model.jiraIssues) { issue in
                        issueCard(issue)
                    }
                } else {
                    Card {
                        Label("Connect Jira in the Panel tab (site, email, API token).", systemImage: "info.circle")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(20)
        }
    }

    private var filterBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            Picker("", selection: Binding(
                get: { model.jiraFilter },
                set: { model.setJiraFilter($0) }
            )) {
                ForEach(AppViewModel.JiraFilter.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            if model.jiraFilter == .currentSprint, let sprint = model.currentSprint {
                Label("\(sprint.name) · \(Self.dateRange(sprint))", systemImage: "calendar")
                    .font(.caption).foregroundStyle(.secondary)
            } else if model.jiraFilter == .currentSprint && model.jiraBoardId.trimmed.isEmpty {
                Text("Set a board ID in the Panel to show sprint dates.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    private static func dateRange(_ sprint: JiraSprint) -> String {
        func fmt(_ iso: String?) -> String? {
            guard let day = iso?.prefix(10), day.count == 10 else { return nil }
            let parser = DateFormatter(); parser.dateFormat = "yyyy-MM-dd"
            guard let date = parser.date(from: String(day)) else { return String(day) }
            let out = DateFormatter(); out.dateFormat = "MMM d"
            return out.string(from: date)
        }
        let start = fmt(sprint.startDate) ?? "?"
        let end = fmt(sprint.endDate) ?? "?"
        return "\(start) - \(end)"
    }

    private var issuesHeader: some View {
        HStack {
            Text("ASSIGNED TO ME").font(.caption2).foregroundStyle(.secondary)
            Spacer()
            if model.isLoadingIssues { ProgressView().controlSize(.small) }
            Button { Task { await model.loadIssues() } } label: { Image(systemName: "arrow.clockwise") }
                .buttonStyle(.borderless)
            if !model.jiraStatusMessage.isEmpty {
                Text(model.jiraStatusMessage).font(.caption).foregroundStyle(.secondary)
                    .lineLimit(1).truncationMode(.tail)
            }
        }
    }

    private func issueCard(_ issue: JiraIssue) -> some View {
        let selected = model.selectedIssueKey == issue.key
        return Card {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(issue.key).font(.system(.callout, design: .monospaced)).bold()
                    StatusPill(text: issue.status, color: statusColor(issue.statusCategory))
                    Spacer()
                    if !issue.type.isEmpty {
                        Text(issue.type).font(.caption2).foregroundStyle(.secondary)
                    }
                    Button { model.openIssueInBrowser(issue.key) } label: { Image(systemName: "arrow.up.right.square") }
                        .buttonStyle(.borderless)
                        .help("Open in browser")
                }
                Text(issue.summary).font(.body)
                HStack(spacing: 10) {
                    if !issue.priority.isEmpty {
                        Label(issue.priority, systemImage: "flag").font(.caption2).foregroundStyle(.secondary)
                    }
                    Label(issue.updated, systemImage: "clock").font(.caption2).foregroundStyle(.secondary)
                }

                if selected { actions(for: issue) }
            }
            .contentShape(Rectangle())
            .onTapGesture { model.selectIssue(selected ? nil : issue.key) }
        }
    }

    private func actions(for issue: JiraIssue) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider()
            if model.issueTransitions.isEmpty {
                Text("Loading transitions…").font(.caption).foregroundStyle(.secondary)
            } else {
                Text("MOVE TO").font(.caption2).foregroundStyle(.secondary)
                FlowButtons(transitions: model.issueTransitions) { t in
                    model.applyTransition(key: issue.key, transition: t)
                }
            }
            HStack {
                TextField("Add a comment…", text: $model.commentDraft, axis: .vertical)
                    .lineLimit(1...3)
                    .textFieldStyle(.roundedBorder)
                Button("Comment") { model.addComment(key: issue.key) }
                    .disabled(model.commentDraft.trimmed.isEmpty)
            }
        }
        .padding(.top, 4)
    }

    private func statusColor(_ category: String) -> Color {
        switch category {
        case "done": return .green
        case "indeterminate": return .blue
        default: return .secondary
        }
    }
}

/// Simple wrapping row of transition buttons.
private struct FlowButtons: View {
    let transitions: [JiraTransition]
    let onTap: (JiraTransition) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(transitions) { t in
                    Button(t.name) { onTap(t) }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
            }
        }
    }
}
