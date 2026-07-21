import AppKit
import Foundation
import SwiftUI

@MainActor
final class AppViewModel: ObservableObject {
    enum LLMBackend: String, CaseIterable, Identifiable { case ollama = "Ollama", mlx = "MLX"; var id: String { rawValue } }

    // MARK: Backend
    @Published var backend: LLMBackend {
        didSet { defaults.set(backend.rawValue, forKey: "backend"); Task { await refreshStatus() } }
    }
    /// Fixed local endpoint for the MLX (vllm-mlx) server — not user-editable.
    /// 11435 sits next to Ollama's 11434.
    let mlxBaseURL = "http://127.0.0.1:11435/v1"
    @Published var mlxModel: String = "mlx-community/Qwen2.5-Coder-14B-Instruct-4bit" {
        didSet { defaults.set(mlxModel, forKey: "mlxModel") }
    }
    /// MLX models actually downloaded in the local Hugging Face cache (like Ollama's
    /// installed-model list). vllm-mlx serves one model per process — changing this
    /// and pressing Stop → Start swaps the loaded model.
    @Published var mlxModels: [String] = []

    // MARK: Ollama
    @Published var ollamaRunning = false
    @Published var ollamaBusy = false
    /// True while the local MLX (vllm-mlx) server is being launched/stopped.
    @Published var mlxBusy = false
    @Published var models: [OllamaModel] = []
    @Published var selectedModel: String = ""
    let ollamaBaseURL = "http://127.0.0.1:11434"

    /// The model to use for the active backend.
    var activeModel: String { backend == .mlx ? mlxModel : selectedModel }

    /// A chat client configured for the active backend.
    func activeChatClient() -> OllamaClient {
        switch backend {
        case .ollama:
            return OllamaClient()
        case .mlx:
            let url = URL(string: mlxBaseURL) ?? URL(string: "http://127.0.0.1:11435/v1")!
            return OllamaClient(baseURL: url, mode: .openAI)
        }
    }

    // MARK: Figma
    @Published var figmaToken: String = ""
    @Published var figmaConnected = false
    @Published var figmaAccount: String?
    @Published var figmaStatusMessage: String = ""
    @Published var mcpAvailable = false
    @Published var useMCP: Bool {
        didSet { defaults.set(useMCP, forKey: "useMCP") }
    }

    // MARK: UI Builder
    @Published var figmaURL: String = ""
    @Published var moduleName: String = "Wallet"
    @Published var featureFolder: String = ""
    @Published var outputRoot: URL?
    @Published var isBuilding = false
    @Published var buildLog: [String] = []
    @Published var verboseLog: Bool {
        didSet { defaults.set(verboseLog, forKey: "verboseLog") }
    }

    // MARK: Skills
    @Published var skillsRoot: URL?
    @Published var skillsSummary: String = "Not loaded"
    @Published var skillSources: [String] = []

    // MARK: Codebase RAG — generation index (scoped: PView + bottom-sheet)
    @Published var corpusRoot: URL?
    @Published var indexCount = 0
    @Published var isIndexing = false
    @Published var indexProgress = ""
    @Published var useRAG: Bool {
        didSet { defaults.set(useRAG, forKey: "useRAG") }
    }

    // MARK: Chat index (broad: whole codebase + packages)
    @Published var chatCorpusRoots: [URL] = []
    @Published var chatIndexCount = 0
    @Published var isIndexingChat = false
    @Published var chatIndexProgress = ""

    // MARK: CodeChat (conversational Q&A + file generation, RAG-grounded, with history)
    @Published var codeChatMessages: [CodeChatMessage] = []
    @Published var codeChatInput: String = ""
    @Published var isCodeChatBusy = false
    @Published var codeChatOutputRoot: URL?
    @Published var codeChatUseRAG = false
    @Published var verboseChat: Bool {
        didSet { defaults.set(verboseChat, forKey: "verboseChat") }
    }

    // MARK: PR Review
    @Published var repoRoot: URL?
    @Published var repoSlug: String?
    @Published var githubToken: String = ""
    @Published var prNumber: String = ""
    @Published var prDetails: PRDetails?
    @Published var reviewMarkdown: String = ""
    @Published var isFetchingPR = false
    @Published var isReviewing = false
    @Published var prStatusMessage: String = ""

    // MARK: API integration
    @Published var apiVMPath: URL?
    @Published var apiCurl: String = ""
    @Published var apiParsed: CurlRequest?
    @Published var apiParamMappings: [ApiParamMapping] = []
    @Published var apiTrigger: ApiTrigger = .onAppear
    @Published var apiResponseJSON: String = ""
    @Published var apiProposed: [ProposedFile] = []
    @Published var isGeneratingApi = false
    @Published var apiStatus: String = ""

    // MARK: Jira
    enum JiraFilter: String, CaseIterable, Identifiable {
        case currentSprint = "Current Sprint"
        case open = "Open"
        case all = "All"
        var id: String { rawValue }
    }

    @Published var jiraSite: String = ""
    @Published var jiraEmail: String = ""
    @Published var jiraToken: String = ""
    @Published var jiraBoardId: String = ""
    @Published var jiraConnected = false
    @Published var jiraAccount: String?
    @Published var jiraStatusMessage = ""
    @Published var jiraIssues: [JiraIssue] = []
    @Published var isLoadingIssues = false
    @Published var jiraFilter: JiraFilter = .currentSprint
    @Published var currentSprint: JiraSprint?
    @Published var selectedIssueKey: String?
    @Published var issueTransitions: [JiraTransition] = []
    @Published var commentDraft: String = ""

    private let ollama = OllamaClient()
    private let figma = FigmaClient()
    private let jira = JiraService()
    private var prService: PRService { PRService(ollama: activeChatClient()) }
    private let defaults = UserDefaults.standard

    // Running work, so the Stop button can cancel it.
    private var builderTask: Task<Void, Never>?
    private var codeChatTask: Task<Void, Never>?

    /// True while a cancellable long task (UI Builder / CodeChat) is running.
    var isWorking: Bool { isBuilding || isCodeChatBusy }

    func stopWork() {
        builderTask?.cancel(); builderTask = nil
        codeChatTask?.cancel(); codeChatTask = nil
    }

    static func isCancellation(_ error: Error) -> Bool {
        if error is CancellationError { return true }
        if let urlError = error as? URLError, urlError.code == .cancelled { return true }
        return false
    }

    init() {
        backend = LLMBackend(rawValue: defaults.string(forKey: "backend") ?? "") ?? .ollama
        mlxModel = defaults.string(forKey: "mlxModel") ?? "mlx-community/Qwen2.5-Coder-14B-Instruct-4bit"
        verboseLog = defaults.bool(forKey: "verboseLog")
        useMCP = (defaults.object(forKey: "useMCP") as? Bool) ?? true
        useRAG = defaults.bool(forKey: "useRAG")
        verboseChat = (defaults.object(forKey: "verboseChat") as? Bool) ?? true
        if let path = defaults.string(forKey: "corpusRoot") { corpusRoot = URL(fileURLWithPath: path) }
        if let paths = defaults.stringArray(forKey: "chatCorpusRoots") {
            chatCorpusRoots = paths.map { URL(fileURLWithPath: $0) }
        }
        figmaToken = defaults.string(forKey: "figmaToken") ?? ""
        githubToken = defaults.string(forKey: "githubToken") ?? ProcessInfo.processInfo.environment["GITHUB_TOKEN"] ?? ""
        moduleName = defaults.string(forKey: "moduleName") ?? "Wallet"
        selectedModel = defaults.string(forKey: "selectedModel") ?? ""
        if let path = defaults.string(forKey: "outputRoot") { outputRoot = URL(fileURLWithPath: path) }
        if let path = defaults.string(forKey: "repoRoot") { repoRoot = URL(fileURLWithPath: path) }
        if let path = defaults.string(forKey: "skillsRoot") { skillsRoot = URL(fileURLWithPath: path) }
        if let path = defaults.string(forKey: "codeChatOutputRoot") { codeChatOutputRoot = URL(fileURLWithPath: path) }
        jiraSite = defaults.string(forKey: "jiraSite") ?? ""
        jiraEmail = defaults.string(forKey: "jiraEmail") ?? ""
        jiraToken = defaults.string(forKey: "jiraToken") ?? ""
        jiraBoardId = defaults.string(forKey: "jiraBoardId") ?? ""
        if let raw = defaults.string(forKey: "jiraFilter"), let f = JiraFilter(rawValue: raw) { jiraFilter = f }
    }

    // MARK: - API integration

    var canGenerateApi: Bool {
        !isGeneratingApi && ollamaRunning && !activeModel.isEmpty
            && apiVMPath != nil && apiParsed != nil
    }

    func pickAPIViewModel() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = []
        panel.allowsMultipleSelection = false
        panel.prompt = "Use this ViewModel"
        panel.message = "Select the ViewModel .swift file to wire the API into"
        if panel.runModal() == .OK, let url = panel.url {
            apiVMPath = url
        }
    }

    func parseCurl() {
        guard let parsed = CurlParser.parse(apiCurl) else {
            apiStatus = "Could not parse cURL — check the command."
            apiParsed = nil; apiParamMappings = []
            return
        }
        apiParsed = parsed
        apiParamMappings = parsed.paramNames.map { ApiParamMapping(name: $0) }
        apiStatus = "\(parsed.method) \(parsed.url) — \(parsed.paramNames.count) param(s)."
    }

    func generateAPI() {
        guard let vmPath = apiVMPath, let parsed = apiParsed else { return }
        isGeneratingApi = true
        apiProposed = []
        apiStatus = "Generating…"

        let model = activeModel
        let client = activeChatClient()
        let trigger = apiTrigger
        let mappings = apiParamMappings
        let responseJSON = apiResponseJSON
        let curl = apiCurl
        let skillsRootOverride = skillsRoot

        Task {
            do {
                let vmContent = (try? String(contentsOf: vmPath, encoding: .utf8)) ?? ""
                let repoRoot = Self.repoRoot(for: vmPath)
                let proposed = try await Self.runApiGeneration(
                    ollama: client, model: model, vmPath: vmPath, vmContent: vmContent,
                    repoRoot: repoRoot, curl: curl, parsed: parsed, trigger: trigger,
                    mappings: mappings, responseJSON: responseJSON, skillsRoot: skillsRootOverride
                )
                apiProposed = proposed
                apiStatus = "\(proposed.count) file change(s) — review and apply."
            } catch {
                apiStatus = "Generation failed: \(error.localizedDescription)"
            }
            isGeneratingApi = false
        }
    }

    func applyApprovedApiFiles() {
        guard let vmPath = apiVMPath else { return }
        let repoRoot = Self.repoRoot(for: vmPath)
        var written = 0
        for file in apiProposed where file.apply {
            let url = repoRoot.appendingPathComponent(file.relativePath)
            do {
                try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                try file.newContent.write(to: url, atomically: true, encoding: .utf8)
                written += 1
            } catch {
                apiStatus = "Write failed for \(file.relativePath): \(error.localizedDescription)"
                return
            }
        }
        apiStatus = "Applied \(written) file(s)."
        apiProposed = []
    }

    private static func repoRoot(for fileURL: URL) -> URL {
        var dir = fileURL.deletingLastPathComponent()
        let fm = FileManager.default
        while dir.path != "/" {
            if fm.fileExists(atPath: dir.appendingPathComponent(".git").path) { return dir }
            dir = dir.deletingLastPathComponent()
        }
        return fileURL.deletingLastPathComponent()
    }

    private static func runApiGeneration(
        ollama: OllamaClient, model: String, vmPath: URL, vmContent: String, repoRoot: URL,
        curl: String, parsed: CurlRequest, trigger: ApiTrigger, mappings: [ApiParamMapping],
        responseJSON: String, skillsRoot: URL?
    ) async throws -> [ProposedFile] {
        let serviceSkill = SkillLoader.skillContent("api-integration.md", override: skillsRoot) ?? ""
        let vmSkill = SkillLoader.skillContent("api-vm-integration.md", override: skillsRoot) ?? ""
        let vmRel = vmPath.path.replacingOccurrences(of: repoRoot.path + "/", with: "")

        let system = """
        You are an iOS engineer. Wire an API into a ViewModel following the two
        attached skills EXACTLY (service layer + VM integration). If the ViewModel already
        has a service, add the new endpoint to that service — do not create a second one.

        ## Output
        Respond with ONLY JSON: { "files": [ { "relativePath": "<repo-relative path>", "content": "<full Swift>" } ] }
        Return the COMPLETE content of every file you create or modify (full file, never a diff,
        never fenced). Paths are relative to the repo root.

        # Skill: api-integration\n\n\(serviceSkill)
        # Skill: api-vm-integration\n\n\(vmSkill)
        """

        let paramLines = mappings.map { "- \($0.name): \($0.source.rawValue) → \($0.value)" }.joined(separator: "\n")
        let user = """
        Target ViewModel: \(vmRel)
        Trigger: \(trigger.rawValue)

        ## cURL
        \(curl)

        ## Parsed
        \(parsed.method) \(parsed.url)
        Params: \(parsed.paramNames.joined(separator: ", "))

        ## Param sources
        \(paramLines.isEmpty ? "(none)" : paramLines)

        ## Response JSON
        \(responseJSON.isEmpty ? "(not provided — ask is not possible; infer a reasonable @Decodable model)" : responseJSON)

        ## Current ViewModel file (\(vmRel))
        \(String(vmContent.prefix(8000)))

        Generate the service-layer files and the updated ViewModel now.
        """

        let raw = try await ollama.chat(
            model: model, system: system, user: user,
            format: GenerationSchema.filesEnvelope(), think: false, numPredict: 12_288, numCtx: 16_384, timeout: 420
        )
        guard
            let data = raw.data(using: .utf8),
            let envelope = try? JSONDecoder().decode(FilesEnvelope.self, from: data),
            !envelope.files.isEmpty
        else {
            throw ScaffoldEngineError.noFiles
        }
        return envelope.files.map { file in
            let abs = repoRoot.appendingPathComponent(file.relativePath)
            let old = try? String(contentsOf: abs, encoding: .utf8)
            return ProposedFile(
                relativePath: file.relativePath,
                newContent: ScaffoldEngine.stripCodeFences(file.content),
                oldContent: old
            )
        }
    }

    // MARK: - Jira

    private func applyJiraConfig() { jira.site = jiraSite; jira.email = jiraEmail; jira.token = jiraToken }

    /// Called on launch — if saved config exists, connect, fetch the sprint, and load issues.
    func refreshJira() async {
        applyJiraConfig()
        guard jira.hasConfig else { return }
        currentSprint = try? await jira.activeSprint(boardId: jiraBoardId)
        await loadIssues()
        jiraConnected = true
    }

    func saveJiraConfigAndTest() async {
        defaults.set(jiraSite, forKey: "jiraSite")
        defaults.set(jiraEmail, forKey: "jiraEmail")
        defaults.set(jiraToken, forKey: "jiraToken")
        defaults.set(jiraBoardId, forKey: "jiraBoardId")
        applyJiraConfig()
        guard jira.hasConfig else {
            jiraConnected = false; jiraStatusMessage = "Enter site, email, and API token."
            return
        }
        do {
            jiraAccount = try await jira.testConnection()
            jiraConnected = true
            jiraStatusMessage = "Connected as \(jiraAccount ?? "Jira user")."
            currentSprint = try? await jira.activeSprint(boardId: jiraBoardId)
            await loadIssues()
        } catch {
            jiraConnected = false; jiraAccount = nil
            jiraStatusMessage = error.localizedDescription
        }
    }

    func setJiraFilter(_ filter: JiraFilter) {
        jiraFilter = filter
        defaults.set(filter.rawValue, forKey: "jiraFilter")
        Task { await loadIssues() }
    }

    private func jql(for filter: JiraFilter) -> String {
        switch filter {
        case .currentSprint:
            let sprintClause = currentSprint.map { "sprint = \($0.id)" } ?? "sprint in openSprints()"
            return "assignee = currentUser() AND \(sprintClause) AND statusCategory != Done ORDER BY updated DESC"
        case .open:
            return "assignee = currentUser() AND statusCategory != Done ORDER BY updated DESC"
        case .all:
            return "assignee = currentUser() ORDER BY updated DESC"
        }
    }

    func loadIssues() async {
        applyJiraConfig()
        guard jira.hasConfig else { return }
        isLoadingIssues = true
        do {
            jiraIssues = try await jira.issues(jql: jql(for: jiraFilter))
            jiraConnected = true
            jiraStatusMessage = "\(jiraIssues.count) issue(s) — \(jiraFilter.rawValue)."
        } catch {
            jiraStatusMessage = error.localizedDescription
        }
        isLoadingIssues = false
    }

    func selectIssue(_ key: String?) {
        selectedIssueKey = key
        issueTransitions = []
        commentDraft = ""
        guard let key else { return }
        Task {
            issueTransitions = (try? await jira.transitions(for: key)) ?? []
        }
    }

    func applyTransition(key: String, transition: JiraTransition) {
        Task {
            do {
                try await jira.applyTransition(key: key, transitionId: transition.id)
                jiraStatusMessage = "Moved \(key) → \(transition.name)."
                await loadIssues()
                selectIssue(key)
            } catch {
                jiraStatusMessage = error.localizedDescription
            }
        }
    }

    func addComment(key: String) {
        let text = commentDraft.trimmed
        guard !text.isEmpty else { return }
        Task {
            do {
                try await jira.addComment(key: key, text: text)
                commentDraft = ""
                jiraStatusMessage = "Comment added to \(key)."
            } catch {
                jiraStatusMessage = error.localizedDescription
            }
        }
    }

    func openIssueInBrowser(_ key: String) {
        if let url = jira.browseURL(key) { NSWorkspace.shared.open(url) }
    }

    // MARK: - Skills

    func refreshSkills() async {
        let override = skillsRoot
        let loaded = await Task.detached { SkillLoader.load(override: override) }.value
        skillSources = loaded.sources
        if let root = loaded.rootPath {
            skillsSummary = "\(loaded.sources.count) file(s) — \(root)"
        } else {
            skillsSummary = "No skills folder found (built-in fallback)."
        }
    }

    func pickSkillsFolder() {
        if let url = Self.pickFolder(message: "Select the skills folder (must contain ui-builder-instructions.md)", start: skillsRoot) {
            skillsRoot = url
            defaults.set(url.path, forKey: "skillsRoot")
            Task { await refreshSkills() }
        }
    }

    // MARK: - Ollama

    func refreshStatus() async {
        let client = activeChatClient()
        ollamaRunning = await client.isRunning()   // "running" = the active backend is reachable
        if ollamaRunning {
            models = (try? await client.listModels()) ?? []
            if backend == .ollama, selectedModel.isEmpty || !models.contains(where: { $0.name == selectedModel }) {
                selectedModel = models.first { $0.name.contains("coder") }?.name ?? models.first?.name ?? ""
            }
        } else {
            models = []
        }
        await scanMlxModels()
        if !figmaToken.isEmpty { await testFigma() }
        if let repoRoot { await detectRepo(repoRoot) }
        await refreshSkills()
        mcpAvailable = await FigmaMCPClient().isAvailable()
        // Off the main actor — count() can fall back to decoding a large index once.
        let counts = await Task.detached {
            (CodebaseIndex.count("generation"), CodebaseIndex.count("chat"))
        }.value
        indexCount = counts.0
        chatIndexCount = counts.1
        await refreshJira()
    }

    // MARK: - CodeChat

    var canCodeChat: Bool {
        !isCodeChatBusy && ollamaRunning && !activeModel.isEmpty && !codeChatInput.trimmed.isEmpty
    }

    func pickCodeChatFolder() {
        if let url = Self.pickFolder(message: "Select where generated files should be created", start: codeChatOutputRoot) {
            codeChatOutputRoot = url
            defaults.set(url.path, forKey: "codeChatOutputRoot")
        }
    }

    func clearCodeChat() { codeChatMessages = [] }

    /// Heuristic: does the message ask to generate/create code (vs ask a question)?
    private func isGenerationRequest(_ text: String) -> Bool {
        let t = text.lowercased()
        let verbs = ["generate", "create", "make", "build", "scaffold", "add a", "write a", "give me a"]
        let nouns = ["view", "pview", "file", "screen", "component", "struct", "class",
                     "function", "func", "sheet", "model", "service", "button", "swiftui"]
        if verbs.contains(where: { t.hasPrefix($0) }) { return true }
        return verbs.contains(where: { t.contains($0) }) && nouns.contains(where: { t.contains($0) })
    }

    /// Prior turns (excluding the just-appended current user message) as {role, content}.
    private func priorHistory() -> [[String: String]] {
        codeChatMessages.dropLast().suffix(8).map {
            ["role": $0.role == .user ? "user" : "assistant", "content": $0.text]
        }
    }

    func sendCodeChat() {
        let prompt = codeChatInput.trimmed
        guard !prompt.isEmpty, !isCodeChatBusy, !activeModel.isEmpty else { return }
        codeChatInput = ""
        codeChatMessages.append(CodeChatMessage(role: .user, text: prompt))
        isCodeChatBusy = true
        if isGenerationRequest(prompt) {
            generateInCodeChat(prompt)
        } else {
            answerInCodeChat(prompt)
        }
    }

    private func answerInCodeChat(_ question: String) {
        let model = activeModel
        let verbose = verboseChat
        let history = priorHistory()
        codeChatTask = Task {
            do {
                let (context, hits) = try await retrieveChatContext(for: question)
                let system = """
                You are a Swift / iOS assistant for the codebase. Answer using the
                provided code excerpts when relevant, and cite the file names you used.
                If the excerpts don't cover the question, say so rather than guessing.
                """
                let user = context.isEmpty
                    ? question
                    : "Question: \(question)\n\n## Relevant code from the codebase\n\(context)"
                let answer = try await activeChatClient().chat(
                    model: model, system: system, user: user, history: history,
                    think: false, numPredict: 2048, numCtx: 16_384, timeout: 180
                )
                let debug = verbose ? Self.buildChatDebug(hits: hits, system: system, user: user) : nil
                codeChatMessages.append(CodeChatMessage(role: .assistant, text: answer, debug: debug))
            } catch {
                let text = Self.isCancellation(error) ? "⏹ Stopped." : "⚠️ \(error.localizedDescription)"
                codeChatMessages.append(CodeChatMessage(role: .assistant, text: text))
            }
            isCodeChatBusy = false
            codeChatTask = nil
        }
    }

    private func generateInCodeChat(_ prompt: String) {
        guard let outputRoot = codeChatOutputRoot else {
            codeChatMessages.append(CodeChatMessage(
                role: .assistant,
                text: "Pick an output folder first (Choose folder…) so I can write the files."
            ))
            isCodeChatBusy = false
            return
        }
        let model = activeModel
        let useRAG = codeChatUseRAG
        let verbose = verboseChat
        let convo = priorHistory().map { "\($0["role"] ?? ""): \($0["content"] ?? "")" }.joined(separator: "\n")
        let effectivePrompt = convo.isEmpty ? prompt : "Conversation so far:\n\(convo)\n\nRequest: \(prompt)"

        let placeholderIndex = codeChatMessages.count
        codeChatMessages.append(CodeChatMessage(role: .assistant, text: "Generating…"))

        let request = ScaffoldRequest(
            figmaURL: "", figmaToken: "", model: model, moduleName: "", featureFolder: nil,
            outputRoot: outputRoot, skillsRoot: skillsRoot, verbose: true, useMCP: false,
            useRAG: useRAG, corpusRoot: corpusRoot, ragIndexName: "chat"
        )

        codeChatTask = Task {
            let engine = ScaffoldEngine(ollama: activeChatClient())
            var logLines: [String] = []
            engine.onLog = { line in logLines.append(line) }
            do {
                let result = try await engine.runPrompt(request, prompt: effectivePrompt)
                let files = result.writtenFiles.map { $0.path }
                if placeholderIndex < codeChatMessages.count {
                    codeChatMessages[placeholderIndex] = CodeChatMessage(
                        role: .assistant, text: "Created \(files.count) file(s).",
                        files: files, debug: verbose ? logLines.joined(separator: "\n") : nil
                    )
                }
                ScaffoldEngine.openInXcode(result.writtenFiles)
            } catch {
                if placeholderIndex < codeChatMessages.count {
                    codeChatMessages[placeholderIndex] = CodeChatMessage(
                        role: .assistant,
                        text: Self.isCancellation(error) ? "⏹ Stopped." : "⚠️ \(error.localizedDescription)",
                        debug: verbose ? logLines.joined(separator: "\n") : nil
                    )
                }
            }
            isCodeChatBusy = false
            codeChatTask = nil
        }
    }

    private static func buildChatDebug(hits: [Hit], system: String, user: String) -> String {
        var lines = ["RETRIEVED \(hits.count) chunk(s) (cosine score):"]
        if hits.isEmpty { lines.append("  (none — index empty?)") }
        for hit in hits {
            lines.append(String(format: "  %.3f  %@ #%d   [\(hit.detail)]", hit.score, (hit.path as NSString).lastPathComponent, hit.chunkIndex))
            lines.append("         \(hit.path)")
        }
        lines.append("\n── INJECTED PROMPT (system) ──\n\(system)")
        lines.append("\n── INJECTED PROMPT (user) ──\n\(String(user.prefix(6000)))")
        return lines.joined(separator: "\n")
    }

    /// Retrieves the top code excerpts for a question from the codebase index.
    private func retrieveChatContext(for question: String) async throws -> (context: String, hits: [Hit]) {
        let queryVector = try await EmbeddingClient().embedQuery(question)
        // Loading + scoring the (large) index off the main actor so the UI never blocks.
        let hits = await Task.detached {
            CodebaseIndex.count("chat") > 0
                ? CodebaseIndex.searchHits(name: "chat", queryVector: queryVector, queryText: question, kind: "", k: 6)
                : []
        }.value
        let blocks = hits.map { hit -> String in
            let name = (hit.path as NSString).lastPathComponent
            return "// \(name) (chunk \(hit.chunkIndex))\n\(hit.text)"
        }
        return (blocks.joined(separator: "\n\n"), hits)
    }

    // MARK: - Codebase RAG

    func pickCorpusFolder() {
        if let url = Self.pickFolder(message: "Select the codebase root to index (e.g. MyIOSApp/App/Module)", start: corpusRoot) {
            corpusRoot = url
            defaults.set(url.path, forKey: "corpusRoot")
        }
    }

    func buildIndex() {
        guard let corpusRoot, !isIndexing else { return }
        isIndexing = true
        indexProgress = "Scanning…"
        Task {
            do {
                let count = try await CodebaseIndex.build(
                    name: "generation", roots: [corpusRoot], mode: .examples
                ) { done, total in
                    await MainActor.run { self.indexProgress = "Embedding \(done)/\(total)…" }
                }
                indexCount = count
                indexProgress = "Indexed \(count) example file(s)."
            } catch {
                indexProgress = "Index failed: \(error.localizedDescription)"
            }
            isIndexing = false
        }
    }

    /// Append ONE folder per tap (e.g. add Modules, then PUIKit, then Utils_iOS).
    func addChatCorpusFolder() {
        guard let url = Self.pickFolder(
            message: "Add a folder to index (tap again to add more, e.g. Modules, PUIKit, Utils_iOS)",
            start: chatCorpusRoots.last
        ) else { return }
        if !chatCorpusRoots.contains(url) {
            chatCorpusRoots.append(url)
            persistChatCorpus()
        }
    }

    func removeChatCorpusFolder(_ url: URL) {
        chatCorpusRoots.removeAll { $0 == url }
        persistChatCorpus()
    }

    private func persistChatCorpus() {
        defaults.set(chatCorpusRoots.map { $0.path }, forKey: "chatCorpusRoots")
    }

    func buildChatIndex() {
        guard !chatCorpusRoots.isEmpty, !isIndexingChat else { return }
        isIndexingChat = true
        chatIndexProgress = "Scanning…"
        Task {
            do {
                let count = try await CodebaseIndex.build(
                    name: "chat", roots: chatCorpusRoots, mode: .all
                ) { done, total in
                    await MainActor.run { self.chatIndexProgress = "Embedding \(done)/\(total)…" }
                }
                chatIndexCount = count
                chatIndexProgress = "Indexed \(count) file(s)."
            } catch {
                chatIndexProgress = "Index failed: \(error.localizedDescription)"
            }
            isIndexingChat = false
        }
    }

    func startOllama() async {
        ollamaBusy = true
        _ = await ollama.start()
        await refreshStatus()
        ollamaBusy = false
    }

    func stopOllama() async {
        ollamaBusy = true
        _ = await ollama.stop()
        await refreshStatus()
        ollamaBusy = false
    }

    /// Lists MLX models present in the local Hugging Face cache (the picker, like
    /// Ollama's, shows only what's downloaded). Cache dirs look like
    /// `models--mlx-community--Qwen2.5-Coder-14B-Instruct-4bit`; the org/name slug
    /// is recovered by replacing the first `--` after `models--` with `/`.
    func scanMlxModels() async {
        let hub = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".cache/huggingface/hub")
        let found: [String] = await Task.detached {
            guard let dirs = try? FileManager.default.contentsOfDirectory(
                at: hub, includingPropertiesForKeys: nil) else { return [] }
            return dirs.compactMap { url -> String? in
                let name = url.lastPathComponent
                guard name.hasPrefix("models--") else { return nil }
                // Must have real weights, not just a metadata stub: require a
                // `*.safetensors` file in a snapshot (the `.index.json` doesn't count).
                let snapshots = url.appendingPathComponent("snapshots")
                let revs = (try? FileManager.default.contentsOfDirectory(
                    at: snapshots, includingPropertiesForKeys: nil)) ?? []
                let hasWeights = revs.contains { rev in
                    let files = (try? FileManager.default.contentsOfDirectory(atPath: rev.path)) ?? []
                    return files.contains { $0.hasSuffix(".safetensors") }
                }
                guard hasWeights else { return nil }
                let slug = String(name.dropFirst("models--".count))
                guard let r = slug.range(of: "--") else { return nil }
                let repo = slug.replacingCharacters(in: r, with: "/")
                // Exclude embedding / reranker models — this picker is for chat models
                // (embeddings go through Ollama). Heuristic on the well-known names.
                let lc = repo.lowercased()
                let embedHint = ["sentence-transformers/", "embed", "minilm", "bge-", "gte-", "nomic", "rerank"]
                guard !embedHint.contains(where: { lc.contains($0) }) else { return nil }
                return repo
            }.sorted()
        }.value
        mlxModels = found
        // Keep the selection valid — fall back to a downloaded model if the current
        // one isn't present.
        if !found.isEmpty, !found.contains(mlxModel) {
            mlxModel = found.first { $0.lowercased().contains("coder") } ?? found[0]
        }
    }

    // MARK: MLX (vllm-mlx) lifecycle

    /// Launches `vllm-mlx serve` from the Swiftex venv detached, then polls until
    /// the OpenAI-compatible API answers (model load — or first-run download — can
    /// take a while). Mirrors `scripts/swiftex-mlx-serve.sh`.
    func startMLX() async {
        mlxBusy = true
        if await activeChatClient().isRunning() {
            await refreshStatus(); mlxBusy = false; return
        }
        let port = URLComponents(string: mlxBaseURL)?.port ?? 11435
        let bin = "$HOME/.swiftex-mlx/venv/bin/vllm-mlx"
        let cmd = "nohup \(bin) serve \"\(mlxModel)\" --port \(port) --continuous-batching"
            + " >> $HOME/.swiftex-mlx/serve.log 2>&1 &"
        await Task.detached { Shell.runDetached(cmd) }.value
        // Poll up to ~90s for readiness (cached 14B load is ~15–30s; first run downloads).
        for _ in 0..<90 {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            if await activeChatClient().isRunning() { break }
        }
        await refreshStatus()
        mlxBusy = false
    }

    func stopMLX() async {
        mlxBusy = true
        _ = await Task.detached { Shell.run("pkill -f 'vllm-mlx serve'") }.value
        await refreshStatus()
        mlxBusy = false
    }

    func selectModel(_ name: String) {
        selectedModel = name
        defaults.set(name, forKey: "selectedModel")
    }

    // MARK: - Figma

    func saveTokenAndTest() async {
        defaults.set(figmaToken, forKey: "figmaToken")
        await testFigma()
    }

    func testFigma() async {
        figma.token = figmaToken
        guard figma.hasToken else {
            figmaConnected = false
            figmaAccount = nil
            figmaStatusMessage = "Enter a Figma personal access token."
            return
        }
        do {
            let user = try await figma.me()
            figmaConnected = true
            figmaAccount = user.email ?? user.handle
            figmaStatusMessage = "Connected as \(figmaAccount ?? "Figma user")."
        } catch {
            figmaConnected = false
            figmaAccount = nil
            figmaStatusMessage = error.localizedDescription
        }
    }

    // MARK: - UI Builder

    var canBuild: Bool {
        // MCP needs no token; REST path needs a connected Figma token.
        let haveDesignSource = (useMCP && mcpAvailable) || figmaConnected
        return !isBuilding && ollamaRunning && !activeModel.isEmpty
            && !figmaURL.trimmed.isEmpty && haveDesignSource && outputRoot != nil
    }

    func setModule(_ name: String) {
        moduleName = name
        defaults.set(name, forKey: "moduleName")
    }

    func pickOutputFolder() {
        if let url = Self.pickFolder(message: "Select the output folder for generated Swift files", start: outputRoot) {
            outputRoot = url
            defaults.set(url.path, forKey: "outputRoot")
        }
    }

    func generate() {
        guard let outputRoot else { return }
        isBuilding = true
        buildLog = []
        let request = ScaffoldRequest(
            figmaURL: figmaURL, figmaToken: figmaToken, model: activeModel,
            moduleName: moduleName, featureFolder: featureFolder, outputRoot: outputRoot,
            skillsRoot: skillsRoot, verbose: verboseLog, useMCP: useMCP,
            useRAG: useRAG, corpusRoot: corpusRoot
        )
        builderTask = Task {
            let engine = ScaffoldEngine(ollama: activeChatClient())
            engine.onLog = { [weak self] line in self?.appendBuildLog(line) }
            do {
                let result = try await engine.run(request)
                appendBuildLog("✅ Done — \(result.writtenFiles.count) file(s) generated.")
                ScaffoldEngine.openInXcode(result.writtenFiles)
            } catch {
                appendBuildLog(Self.isCancellation(error) ? "⏹ Stopped." : "❌ \(error.localizedDescription)")
            }
            isBuilding = false
            builderTask = nil
        }
    }

    // MARK: - PR Review

    var canFetchPR: Bool {
        !isFetchingPR && repoSlug != nil && Int(prNumber.trimmed) != nil
    }

    func pickRepoFolder() {
        if let url = Self.pickFolder(message: "Select your iOS repo (folder with a github.com origin)", start: repoRoot) {
            repoRoot = url
            defaults.set(url.path, forKey: "repoRoot")
            Task { await detectRepo(url) }
        }
    }

    func saveGithubToken() {
        defaults.set(githubToken, forKey: "githubToken")
    }

    private func detectRepo(_ folder: URL) async {
        if let repo = await prService.detectRepo(in: folder) {
            repoSlug = "\(repo.owner)/\(repo.repo)"
            prStatusMessage = ""
        } else {
            repoSlug = nil
            prStatusMessage = "No github.com origin found in that folder."
        }
    }

    func fetchPR() {
        guard let slug = repoSlug, let number = Int(prNumber.trimmed) else { return }
        let parts = slug.split(separator: "/")
        guard parts.count == 2 else { return }
        isFetchingPR = true
        prDetails = nil
        reviewMarkdown = ""
        prStatusMessage = "Fetching PR #\(number)…"
        Task {
            do {
                let details = try await prService.fetchPR(
                    owner: String(parts[0]), repo: String(parts[1]),
                    number: number, token: githubToken.isEmpty ? nil : githubToken,
                    repoFolder: repoRoot
                )
                prDetails = details
                let src = details.diffFromGit ? "git" : "REST"
                prStatusMessage = "Loaded PR #\(number) — \(details.changedSwiftFiles.count) Swift file(s) (\(src) diff)."
            } catch {
                prStatusMessage = error.localizedDescription
            }
            isFetchingPR = false
        }
    }

    func reviewPR() {
        guard let details = prDetails, !activeModel.isEmpty else { return }
        isReviewing = true
        reviewMarkdown = ""
        prStatusMessage = "Reviewing with \(activeModel)…"
        Task {
            do {
                reviewMarkdown = try await prService.runReview(details, model: activeModel)
                prStatusMessage = "Review complete."
            } catch {
                prStatusMessage = error.localizedDescription
            }
            isReviewing = false
        }
    }

    // MARK: - Helpers

    private func appendBuildLog(_ message: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        buildLog.append("[\(formatter.string(from: Date()))] \(message)")
    }

    private static func pickFolder(message: String, start: URL?) -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Use this folder"
        panel.message = message
        if let start { panel.directoryURL = start }
        return panel.runModal() == .OK ? panel.url : nil
    }
}

extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}

struct CodeChatMessage: Identifiable {
    enum Role { case user, assistant }
    let id = UUID()
    let role: Role
    let text: String
    var files: [String] = []
    var debug: String? = nil
}
