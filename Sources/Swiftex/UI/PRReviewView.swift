import SwiftUI

struct PRReviewView: View {
    @EnvironmentObject private var model: AppViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                repoCard
                fetchCard
                if let details = model.prDetails { detailsCard(details) }
                if model.isReviewing || !model.reviewMarkdown.isEmpty { reviewCard }
            }
            .padding(20)
        }
    }

    private var repoCard: some View {
        Card("Repository", systemImage: "shippingbox") {
            HStack {
                Button("Choose repo folder…") { model.pickRepoFolder() }
                if let slug = model.repoSlug {
                    Label(slug, systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    Text(model.repoRoot?.path ?? "No repo selected")
                        .font(.caption).foregroundStyle(.secondary)
                        .lineLimit(1).truncationMode(.middle)
                }
            }
            HStack {
                SecureField("GitHub token (optional, for private repos)", text: $model.githubToken)
                    .textFieldStyle(.roundedBorder)
                Button("Save") { model.saveGithubToken() }
            }
        }
    }

    private var fetchCard: some View {
        Card("Pull request", systemImage: "arrow.triangle.pull") {
            HStack {
                TextField("PR number, e.g. 1234", text: $model.prNumber)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 180)
                Button {
                    model.fetchPR()
                } label: {
                    if model.isFetchingPR { ProgressView().controlSize(.small) }
                    Text("Fetch")
                }
                .disabled(!model.canFetchPR)
                Spacer()
            }
            if !model.prStatusMessage.isEmpty {
                Text(model.prStatusMessage).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func detailsCard(_ details: PRDetails) -> some View {
        Card(systemImage: nil) {
            VStack(alignment: .leading, spacing: 8) {
                Text(details.title).font(.headline)
                HStack(spacing: 12) {
                    Label(details.author, systemImage: "person")
                    Label("\(details.headBranch) → \(details.baseBranch)", systemImage: "arrow.left.arrow.right")
                    Label("+\(details.additions) / -\(details.deletions)", systemImage: "plusminus")
                }
                .font(.caption).foregroundStyle(.secondary)

                Text("\(details.changedFiles) file(s) changed · \(details.changedSwiftFiles.count) Swift"
                     + (details.diffFromGit ? "  ·  git diff (wide context)" : "  ·  REST diff (limited context)"))
                    .font(.caption).foregroundStyle(.secondary)

                if details.changedSwiftFiles.isEmpty {
                    Text("No Swift files changed — nothing to review.")
                        .font(.caption).foregroundStyle(.secondary)
                }

                Button {
                    model.reviewPR()
                } label: {
                    if model.isReviewing { ProgressView().controlSize(.small) }
                    Label("Review with \(model.activeModel.isEmpty ? model.backend.rawValue : model.activeModel)",
                          systemImage: "checkmark.shield")
                }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
                .disabled(model.isReviewing || model.activeModel.isEmpty || details.changedSwiftFiles.isEmpty)
                .padding(.top, 4)
            }
        }
    }

    private var reviewCard: some View {
        Card("Review", systemImage: "checkmark.shield") {
            if model.reviewMarkdown.isEmpty {
                HStack { ProgressView().controlSize(.small); Text("Generating review…").foregroundStyle(.secondary) }
            } else {
                MarkdownText(markdown: model.reviewMarkdown)
            }
        }
    }
}
