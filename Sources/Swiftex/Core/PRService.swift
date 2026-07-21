import Foundation

struct PRFileChange {
    let filename: String
    let status: String
    let additions: Int
    let deletions: Int
    let patch: String?
}

struct PRDetails {
    let number: Int
    let title: String
    let author: String
    let state: String
    let body: String
    let url: String
    let baseBranch: String
    let headBranch: String
    let changedFiles: Int
    let additions: Int
    let deletions: Int
    let files: [PRFileChange]
    var diffSummary: String
    /// Swift-only unified diff (git `--unified=80` when a local repo is available,
    /// else assembled from REST patches), annotated with `[NEW:<line>]` / `[OLD]`
    /// markers so the model can cite exact new-file line numbers.
    var annotatedSwiftDiff: String = ""
    /// Paths of changed `*.swift` files.
    var changedSwiftFiles: [String] = []
    /// True when the diff came from a local `git diff` (richer 80-line context)
    /// rather than truncated REST patches.
    var diffFromGit: Bool = false
}

enum PRError: LocalizedError {
    case noRepo
    case http(Int, String)

    var errorDescription: String? {
        switch self {
        case .noRepo:
            return "Couldn't detect a GitHub repo. Pick a folder whose `origin` remote points to github.com."
        case .http(let code, let detail):
            return "GitHub API error (\(code)): \(detail.prefix(160))"
        }
    }
}

/// Fetches PR metadata + diffs from GitHub and runs a local-LLM review.
///
/// The review mirrors the team's `review-pr.sh`: a Swift-only diff with wide
/// (`--unified=80`) context, annotated with `[NEW:<line>]` markers, fed to a strict
/// Project-specific reviewer prompt, with a stricter findings-only retry if the model
/// returns summary-style output.
final class PRService {
    private let ollama: OllamaClient

    init(ollama: OllamaClient = OllamaClient()) {
        self.ollama = ollama
    }

    /// Reads `origin` from a repo folder and parses owner/repo.
    func detectRepo(in folder: URL) async -> (owner: String, repo: String)? {
        let result = await Task.detached {
            Shell.run("cd \(folder.path.shellQuoted) && git remote get-url origin")
        }.value
        guard result.ok else { return nil }
        let url = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
        return Self.parseOwnerRepo(url)
    }

    /// Fetches PR metadata via the GitHub REST API, then builds the annotated
    /// Swift diff — from a local `git` clone when `repoFolder` is provided and the
    /// PR is fetchable, otherwise from the REST per-file patches.
    func fetchPR(owner: String, repo: String, number: Int, token: String?, repoFolder: URL?) async throws -> PRDetails {
        var headers = [
            "Accept": "application/vnd.github+json",
            "X-GitHub-Api-Version": "2022-11-28",
        ]
        if let token, !token.isEmpty { headers["Authorization"] = "Bearer \(token)" }

        let prJSON = try await getJSON(
            "https://api.github.com/repos/\(owner)/\(repo)/pulls/\(number)",
            headers: headers
        )
        guard let pr = prJSON as? [String: Any] else { throw PRError.http(-1, "bad PR payload") }

        let filesJSON = try await getJSON(
            "https://api.github.com/repos/\(owner)/\(repo)/pulls/\(number)/files?per_page=100",
            headers: headers
        )
        let rawFiles = (filesJSON as? [[String: Any]]) ?? []
        let files: [PRFileChange] = rawFiles.map {
            PRFileChange(
                filename: $0["filename"] as? String ?? "?",
                status: $0["status"] as? String ?? "?",
                additions: $0["additions"] as? Int ?? 0,
                deletions: $0["deletions"] as? Int ?? 0,
                patch: $0["patch"] as? String
            )
        }

        let user = pr["user"] as? [String: Any]
        let base = pr["base"] as? [String: Any]
        let head = pr["head"] as? [String: Any]
        let baseBranch = base?["ref"] as? String ?? "?"

        var details = PRDetails(
            number: number,
            title: pr["title"] as? String ?? "(no title)",
            author: user?["login"] as? String ?? "?",
            state: pr["state"] as? String ?? "?",
            body: pr["body"] as? String ?? "",
            url: pr["html_url"] as? String ?? "",
            baseBranch: baseBranch,
            headBranch: head?["ref"] as? String ?? "?",
            changedFiles: pr["changed_files"] as? Int ?? files.count,
            additions: pr["additions"] as? Int ?? 0,
            deletions: pr["deletions"] as? Int ?? 0,
            files: files,
            diffSummary: ""
        )
        details.diffSummary = Self.buildDiffSummary(files)

        // Prefer a local git diff (wide context); fall back to REST patches.
        if let repoFolder,
           let git = await gitSwiftDiff(owner: owner, repo: repo, number: number, base: baseBranch, in: repoFolder) {
            details.annotatedSwiftDiff = Self.annotate(git.diff)
            details.changedSwiftFiles = git.files
            details.diffFromGit = true
        } else {
            let swiftFiles = files.filter { $0.filename.hasSuffix(".swift") }
            details.changedSwiftFiles = swiftFiles.map { $0.filename }
            details.annotatedSwiftDiff = Self.annotate(Self.restPatchesAsDiff(swiftFiles))
            details.diffFromGit = false
        }
        return details
    }

    /// Runs the strict reviewer prompt over the annotated Swift diff, retries once
    /// with a findings-only prompt if the output looks like a summary, and returns
    /// the composed review markdown (header + impacted files + findings).
    func runReview(_ details: PRDetails, model: String) async throws -> String {
        guard !details.changedSwiftFiles.isEmpty, !details.annotatedSwiftDiff.isEmpty else {
            return Self.composeReview(details, findings: "No Swift files changed.")
        }

        let diff = String(details.annotatedSwiftDiff.prefix(60_000))
        let truncated = details.annotatedSwiftDiff.count > 60_000
        let diffBlock = diff + (truncated ? "\n\n[diff truncated for length]" : "")

        var body = try await ollama.chat(
            model: model,
            system: Self.reviewerPrompt,
            user: "Here is the annotated Swift diff to review:\n\n\(diffBlock)",
            think: false,
            numPredict: 4096,
            numCtx: 32_768,
            timeout: 600
        )

        if !Self.isValidReview(body) {
            // Model summarized instead of reviewing — retry with a stricter contract.
            let retry = try await ollama.chat(
                model: model,
                system: Self.retryPrompt,
                user: "Annotated Swift diff:\n\n\(diffBlock)",
                think: false,
                numPredict: 4096,
                numCtx: 32_768,
                timeout: 600
            )
            if Self.isValidReview(retry) {
                body = retry
            } else {
                body = """
                No valid review findings generated.

                > The local model returned summary-style output twice instead of \
                paste-ready PR comments. Try a stronger model.
                """
            }
        }
        return Self.composeReview(details, findings: body)
    }

    // MARK: - Git diff

    /// Fetches the PR head + base into private refs and returns the wide-context
    /// Swift diff + changed Swift file list. Returns nil if anything fails (no
    /// matching remote, fetch/auth failure) so the caller can fall back to REST.
    private func gitSwiftDiff(owner: String, repo: String, number: Int, base: String, in folder: URL)
        async -> (diff: String, files: [String])? {
        await Task.detached { () -> (diff: String, files: [String])? in
            let q = folder.path.shellQuoted
            func git(_ args: String) -> Shell.Result { Shell.run("cd \(q) && git \(args)") }

            // Find the remote whose URL points at owner/repo (prefer upstream, then origin).
            let remotesOut = git("remote -v").output
            guard let remote = Self.matchingRemote(remotesOut, owner: owner, repo: repo) else { return nil }

            let baseRef = "refs/swiftex/base-\(number)"
            let headRef = "refs/swiftex/pr-\(number)"
            guard git("fetch \(remote) \(base.shellQuoted):\(baseRef)").ok else { return nil }
            guard git("fetch \(remote) pull/\(number)/head:\(headRef)").ok else { return nil }

            let names = git("diff --name-only \(baseRef)...\(headRef) -- '*.swift'").output
                .split(separator: "\n").map(String.init)
                .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            guard !names.isEmpty else { return (diff: "", files: []) }

            let diff = git("diff --unified=80 \(baseRef)...\(headRef) -- '*.swift'").output
            return (diff: diff, files: names)
        }.value
    }

    // MARK: - Diff annotation (port of review-pr.sh awk)

    /// Annotates a unified diff: added/context lines get `[NEW:<line>]` with the
    /// new-file line number; removed lines get `[OLD]`. Headers pass through.
    static func annotate(_ diff: String) -> String {
        guard !diff.isEmpty else { return "" }
        var out: [String] = []
        var newLine = 0
        for line in diff.split(separator: "\n", omittingEmptySubsequences: false).map(String.init) {
            if line.hasPrefix("@@ ") {
                newLine = parseHunkNewStart(line) ?? newLine
                out.append(line)
            } else if line.hasPrefix("+++ ") || line.hasPrefix("--- ")
                        || line.hasPrefix("diff --git ") || line.hasPrefix("index ")
                        || line.hasPrefix("new file") || line.hasPrefix("deleted file")
                        || line.hasPrefix("rename ") || line.hasPrefix("similarity ") {
                out.append(line)
            } else if line.hasPrefix("+") {
                out.append("+[NEW:\(newLine)] \(String(line.dropFirst()))")
                newLine += 1
            } else if line.hasPrefix(" ") {
                out.append(" [NEW:\(newLine)] \(String(line.dropFirst()))")
                newLine += 1
            } else if line.hasPrefix("-") {
                out.append("-[OLD] \(String(line.dropFirst()))")
            } else {
                out.append(line)
            }
        }
        return out.joined(separator: "\n")
    }

    /// From `@@ -a,b +c,d @@`, returns the new-file start line `c`.
    private static func parseHunkNewStart(_ header: String) -> Int? {
        guard let plus = header.firstIndex(of: "+") else { return nil }
        let after = header[header.index(after: plus)...]
        let digits = after.prefix { $0.isNumber }
        return Int(digits)
    }

    /// Assembles REST per-file patches into a single unified diff with a `+++`
    /// header per file so the annotator and model know which file each hunk is in.
    private static func restPatchesAsDiff(_ files: [PRFileChange]) -> String {
        var blocks: [String] = []
        for file in files {
            guard let patch = file.patch, !patch.isEmpty else { continue }
            blocks.append("diff --git a/\(file.filename) b/\(file.filename)")
            blocks.append("+++ b/\(file.filename)")
            blocks.append(patch)
        }
        return blocks.joined(separator: "\n")
    }

    // MARK: - Review validation & composition

    /// Valid output is either the no-issues sentinel or contains at least one
    /// `### <file>:<line> - ` finding heading. Mirrors the script's grep gate.
    static func isValidReview(_ text: String) -> Bool {
        for raw in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line == "No meaningful issues found." { return true }
            if line.hasPrefix("### "), let colon = line.range(of: ":") {
                let afterColon = line[colon.upperBound...]
                let num = afterColon.prefix { $0.isNumber }
                if !num.isEmpty, afterColon.dropFirst(num.count).hasPrefix(" - ") { return true }
            }
        }
        return false
    }

    private static func composeReview(_ details: PRDetails, findings: String) -> String {
        var md = """
        # PR #\(details.number) Review

        **Title:** \(details.title)

        **Base branch:** \(details.baseBranch)

        **Swift files impacted:** \(details.changedSwiftFiles.count)\
        \(details.diffFromGit ? "" : "  _(diff via GitHub REST — limited context)_")

        """
        if !details.changedSwiftFiles.isEmpty {
            md += "\n## Impacted Swift Files\n\n"
            md += details.changedSwiftFiles.map { "- `\($0)`" }.joined(separator: "\n")
            md += "\n"
        }
        md += "\n## AI Review Findings\n\n\(findings)\n"
        return md
    }

    // MARK: - Helpers

    /// Picks the remote whose URL points at owner/repo. Prefers `upstream`, then
    /// `origin`, then any match. `remoteV` is the output of `git remote -v`.
    static func matchingRemote(_ remoteV: String, owner: String, repo: String) -> String? {
        var matches: [String] = []
        for line in remoteV.split(separator: "\n") {
            let parts = line.split(whereSeparator: { $0 == " " || $0 == "\t" })
            guard parts.count >= 2 else { continue }
            let name = String(parts[0])
            let url = String(parts[1])
            if let parsed = parseOwnerRepo(url),
               parsed.owner.lowercased() == owner.lowercased(),
               parsed.repo.lowercased() == repo.lowercased() {
                if !matches.contains(name) { matches.append(name) }
            }
        }
        if matches.contains("upstream") { return "upstream" }
        if matches.contains("origin") { return "origin" }
        return matches.first
    }

    static func parseOwnerRepo(_ url: String) -> (owner: String, repo: String)? {
        guard
            let regex = try? NSRegularExpression(pattern: #"github\.com[:/]([^/]+)/([^/.\s]+)"#),
            let match = regex.firstMatch(in: url, range: NSRange(url.startIndex..., in: url)),
            let ownerRange = Range(match.range(at: 1), in: url),
            let repoRange = Range(match.range(at: 2), in: url)
        else { return nil }
        return (String(url[ownerRange]), String(url[repoRange]))
    }

    private func getJSON(_ urlString: String, headers: [String: String]) async throws -> Any {
        guard let url = URL(string: urlString) else { throw PRError.http(-1, "bad url") }
        var request = URLRequest(url: url)
        for (key, value) in headers { request.setValue(value, forHTTPHeaderField: key) }
        request.timeoutInterval = 20
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw PRError.http(code, String(data: data, encoding: .utf8) ?? "")
        }
        return try JSONSerialization.jsonObject(with: data)
    }

    private static func buildDiffSummary(_ files: [PRFileChange]) -> String {
        var lines: [String] = []
        for file in files {
            lines.append("• \(file.filename) (+\(file.additions)/-\(file.deletions)) [\(file.status)]")
            if let patch = file.patch {
                let patchLines = patch.split(separator: "\n", omittingEmptySubsequences: false)
                lines.append(patchLines.prefix(12).joined(separator: "\n"))
                if patchLines.count > 12 { lines.append("  …") }
            }
            lines.append("")
        }
        return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Prompts (ported from review-pr.sh)

    private static let reviewerPrompt = """
    You are a senior iOS engineer reviewing a production Swift PR for the iOS app.

    Your job is to perform a rigorous PR review and return only meaningful, valid, actionable PR comments.
    Be strict while reviewing, but conservative while reporting.

    Core rule:
    - A short review with one real issue is better than a long review with weak comments.
    - If you are not confident an issue is real from the diff, do not report it.
    - Do not produce generic best-practice comments.
    - Do not praise, summarize the PR, explain what changed, or restate the checklist.
    - Do not write a PR summary. Do not include sections named "Key Changes", "Example Code Snippets", "Summary", "Overall", "Overview", or "What changed".
    - Do not start with phrases like "This set of code changes", "The code changes", "This PR", or "Here are some key points".
    - If your response is only a summary of changed files, it is invalid. Return real review findings or exactly: No meaningful issues found.
    - Your first non-empty line must be one of: ## Critical, ## Medium, ## Suggestions, or No meaningful issues found.
    - Do not invent issues outside the diff.
    - Comment only on added or modified lines. Use unchanged surrounding context only when it directly explains a changed-line risk.
    - If the same issue appears multiple times, report the clearest example and mention the repeated pattern in that finding.
    - If there are no meaningful issues, return exactly: No meaningful issues found.

    Review priorities:
    1. Crash risks
    - Force unwraps, unsafe casts, unsafe indexing, invalid optional assumptions, lifecycle assumptions, impossible states, missing error paths.

    2. Build-breaking Swift risks
    - Missing imports, unavailable symbols, wrong access control, unresolved types, bad initializers, protocol conformance mistakes, and obvious compile failures.

    3. Retain cycles and memory
    - Always flag escaping closures that capture self strongly in Combine, async callbacks, timers, stored callbacks, delegates, and long-lived UI actions.
    - Prefer [weak self] unless the closure is provably non-escaping or ownership is intentionally documented.
    - Avoid unowned unless lifetime is guaranteed.
    - Do not ask to clear cancellables in deinit.

    4. Threading, Combine, and Swift concurrency
    - Output @Published mutations should use setPublished.
    - Input-driven Combine pipelines should use .receive(on: DispatchQueue.global()) where appropriate.
    - UI, coordinator, toast, view, and view-controller creation/presentation from unknown/background queues should use runOnMainThreadIfNeeded.
    - Avoid raw DispatchQueue.main.async, MainActor.run, or Task { @MainActor in } for simple UI hops when runOnMainThreadIfNeeded is the project convention.
    - Do not add duplicate main-thread dispatch around setPublished, PTextViewModel, or output helper APIs that are already thread-safe.
    - Non-Output stored state accessed from multiple threads should use @ThreadSafe when needed.

    5. SwiftUI and PView architecture
    - No ViewModels should be created inside views, including child view models.
    - Views must not directly mutate business-state Output properties.
    - User actions should flow through PassthroughSubject inputs to the ViewModel.
    - PView screens should follow init(viewModel:) and transform(input:) -> Output.
    - transform(input:) should bind only input publishers and reset cancellables.
    - Internal API response or internal subject bindings should be set up in init using viewModelCancellables where appropriate.

    6. UI component conventions
    - Do not use raw SwiftUI Button; use ButtonView.
    - Use .setFont instead of .font.
    - Add meaningful accessibility identifiers for important/tappable UI.
    - Prefer existing project components such as BottomSheetBuilder, PNavbar, and existing project picker views.
    - Flag new custom picker implementations when an existing project picker should be reused.
    - Flag older/deprecated bottom sheet patterns such as blurBottomSheet when BottomSheetBuilder should be used.

    7. Resource and localization conventions
    - Flag new usages of R.generated.swift or R. resources because direct R-file usage is being deprecated.
    - Prefer the current resource/localization/image access pattern used near the changed code.
    - Flag hardcoded user-facing strings only when changed code adds visible UI copy that should use localization.

    8. Navigation
    - PView navigation should use GenericCoordinator with CoordinatorPages.
    - PView screens should be pushed with ScreenObjectMapper.push(PModuleFactory.getModule(viewModel:rootView:)).
    - Do not use BaseUIHostingController directly for PView screens.

    9. API, data, and edge cases
    - Look for unsafe decoding assumptions, poor error handling, bad default values, wrong date/number formatting, and missing empty/loading/error states.
    - Mention missing tests only when changed code adds logic, branching behavior, parsing, navigation, or concurrency that can realistically regress.

    10. Performance
    - Flag expensive work on the main thread, avoidable recomputation in SwiftUI body, unnecessary objectWillChange churn, and non-lazy containers for large lists.

    11. Naming
    - Comment on class, function, or variable names only when the name is genuinely misleading, absurd, or likely to cause maintenance mistakes.
    - Do not nitpick acceptable names.

    Output format:
    - Return Markdown only.
    - Group findings under these headings when present:
      ## Critical
      ## Medium
      ## Suggestions
    - Use Critical for must-fix issues that can cause crashes, leaks, threading bugs, broken architecture, compile failures, or incorrect user-visible behavior.
    - Use Medium for meaningful risks that should be fixed but are not immediate blockers.
    - Use Suggestions only for clearly useful improvements that are worth a PR comment.

    For each finding, use exactly this structure:

    ### <file>:<line> - <short title>
    **Severity:** <Critical|Medium|Suggestion>

    > <Must fix before merge|Should fix|Consider changing>

    **Code:**
    ```swift
    <smallest relevant changed snippet or hunk excerpt>
    ```

    **Issue:** <explain the concrete risk in this code>

    **Suggested fix:** <specific actionable fix, ideally naming the preferred project API/component/pattern>

    Line number rules:
    - The diff is annotated with [NEW:<line>] markers.
    - Use the [NEW:<line>] marker from the changed line as the review line number.
    - Do not include the [NEW:<line>] marker inside the Code snippet.
    - If the exact line cannot be determined, use line: unknown only for important findings.
    """

    private static let retryPrompt = """
    Your previous response was invalid because it summarized the PR instead of giving PR review comments.

    Rewrite the review from scratch.

    Mandatory output contract:
    - Output only valid PR review findings or exactly: No meaningful issues found.
    - Do not summarize the PR.
    - Do not describe key changes.
    - Do not include "Key Changes", "Example Code Snippets", "Summary", "Overall", or "Overview".
    - Every finding must include a file path and line number in the heading.
    - Every finding must include the exact changed code snippet, the issue, and the suggested fix.
    - If there are no clear, meaningful issues in the diff, output exactly: No meaningful issues found.

    Use this exact finding format:

    ## Critical

    ### <file>:<line> - <short title>
    **Severity:** Critical

    > Must fix before merge

    **Code:**
    ```swift
    <smallest relevant changed snippet, without [NEW:<line>] markers>
    ```

    **Issue:** <concrete risk>

    **Suggested fix:** <specific fix>

    Only include ## Medium or ## Suggestions if there are findings in those sections.
    Use [NEW:<line>] markers from the annotated diff for the heading line numbers.
    """
}

private extension String {
    /// Minimal single-quote shell escaping for embedding a path in a command.
    var shellQuoted: String {
        "'" + replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
