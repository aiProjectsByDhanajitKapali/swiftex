import Foundation

struct ScaffoldRequest {
    var figmaURL: String
    var figmaToken: String
    var model: String
    var moduleName: String
    var featureFolder: String?
    var outputRoot: URL
    /// Optional override for the skills folder; nil falls back to default resolution.
    var skillsRoot: URL? = nil
    /// When true, logs the Figma tree, full prompt, and raw LLM response.
    var verbose: Bool = false
    /// Prefer the Figma Dev Mode MCP (when reachable) over the REST layer tree.
    var useMCP: Bool = true
    /// Inject similar real examples retrieved from the codebase index (scoped RAG).
    var useRAG: Bool = false
    var corpusRoot: URL? = nil
    var ragTopK: Int = 2
    /// Which index to retrieve examples from ("generation" = scoped, "chat" = whole codebase).
    var ragIndexName: String = "generation"
}

struct ScaffoldResult {
    let writtenFiles: [URL]
}

enum ScaffoldEngineError: LocalizedError {
    case ollamaDown
    case noFiles

    var errorDescription: String? {
        switch self {
        case .ollamaDown: return "Ollama is not running. Start it (ollama serve) and pick a model."
        case .noFiles: return "The model did not return any files. See the log for raw output."
        }
    }
}

/// Generic generation host: Figma frame → (skills + LLM) → Swift files on disk.
/// Holds NO UI knowledge — what a PView is and how PUIKit components are written
/// lives entirely in the skills folder (see SkillLoader / skills/).
final class ScaffoldEngine {
    private let ollama: OllamaClient
    private let figma: FigmaClient

    var onLog: (@MainActor (String) -> Void)?

    init(ollama: OllamaClient = OllamaClient(), figma: FigmaClient = FigmaClient()) {
        self.ollama = ollama
        self.figma = figma
    }

    func run(_ request: ScaffoldRequest) async throws -> ScaffoldResult {
        await phase("OLLAMA")
        await log("Checking Ollama…")
        guard await ollama.isRunning() else { throw ScaffoldEngineError.ollamaDown }
        await log("Ollama running · model \(request.model)")

        await phase("FIGMA")
        let source = try await resolveDesign(request)
        await log("Source: \(source.label) · root \"\(source.rootName)\"")
        if request.verbose {
            await log("Design context:\n\(source.design)")
        } else {
            await log("Design context: \(source.design.count) chars (toggle Extended log to see it)")
        }

        await phase("SKILL ROUTING")
        let routed = try await routeSkills(request: request, design: source.design)

        var examples = ""
        if request.useRAG {
            await phase("CODEBASE EXAMPLES")
            examples = await retrieveExamples(design: source.design, kind: routed.kind, request: request)
        }

        let feature = request.featureFolder?.nilIfEmpty ?? defaultFeature(from: source.rootName)
        var files = try await generateFiles(
            request: request, design: source.design, rootName: source.rootName,
            skillsText: routed.text, directive: routed.directive, examples: examples, feature: feature
        )
        files = await verifyFiles(files, request: request)

        await phase("OUTPUT")
        let written = try writeFiles(files, outputRoot: request.outputRoot)
        for url in written { await log("• \(url.path)") }
        await log("Wrote \(written.count) file(s) under \(request.outputRoot.path)")
        return ScaffoldResult(writtenFiles: written)
    }

    /// CodeGen: free-form natural-language request → routed skill (+ optional RAG) →
    /// files written to the chosen output folder. Reuses the same routing/generation.
    func runPrompt(_ request: ScaffoldRequest, prompt: String) async throws -> ScaffoldResult {
        await phase("OLLAMA")
        await log("Checking Ollama…")
        guard await ollama.isRunning() else { throw ScaffoldEngineError.ollamaDown }

        await phase("SKILL ROUTING")
        let routed = try await routeSkills(request: request, design: prompt)

        var examples = ""
        if request.useRAG {
            await phase("CODEBASE EXAMPLES")
            examples = await retrieveExamples(design: prompt, kind: routed.kind, request: request)
        }

        let feature = request.featureFolder?.nilIfEmpty ?? "Generated"
        var files = try await generateFiles(
            request: request, design: prompt, rootName: feature,
            skillsText: routed.text, directive: routed.directive, examples: examples,
            feature: feature, freeform: true
        )
        files = await verifyFiles(files, request: request)

        await phase("OUTPUT")
        let written = try writeFiles(files, outputRoot: request.outputRoot)
        for url in written { await log("• \(url.path)") }
        await log("Wrote \(written.count) file(s) under \(request.outputRoot.path)")
        return ScaffoldResult(writtenFiles: written)
    }

    // MARK: - Design source

    private struct ResolvedDesign {
        let design: String
        let rootName: String
        let label: String
    }

    /// Prefer the Figma Dev Mode MCP (richer: code + tokens + real copy); fall back
    /// to the REST layer tree when the MCP isn't reachable or isn't requested.
    private func resolveDesign(_ request: ScaffoldRequest) async throws -> ResolvedDesign {
        if request.useMCP {
            let mcp = FigmaMCPClient()
            if await mcp.isAvailable(), let nodeId = figma.parse(request.figmaURL)?.nodeId {
                await log("Fetching design via Figma Dev Mode MCP (node \(nodeId))…")
                do {
                    let ctx = try await mcp.designContext(nodeId: nodeId)
                    let root = Self.rootName(fromDesignContext: ctx) ?? defaultFeature(from: nodeId)
                    return ResolvedDesign(design: ctx, rootName: root, label: "Figma Dev Mode MCP")
                } catch {
                    await log("MCP failed (\(error.localizedDescription)); falling back to REST.")
                }
            } else {
                await log("Figma MCP not reachable; falling back to REST.")
            }
        }

        figma.token = request.figmaToken
        await log("Fetching Figma frame via REST…")
        let frame = try await figma.fetchFrame(request.figmaURL)
        return ResolvedDesign(design: frame.treeMarkdown, rootName: frame.root.name, label: "Figma REST")
    }

    /// First `data-name="…"` in Dev Mode code is the root node name.
    private static func rootName(fromDesignContext ctx: String) -> String? {
        guard let r = ctx.range(of: #"data-name="[^"]+""#, options: .regularExpression) else { return nil }
        return String(ctx[r])
            .replacingOccurrences(of: "data-name=\"", with: "")
            .replacingOccurrences(of: "\"", with: "")
    }

    // MARK: - Skill routing

    /// Step 1: classify the design to ONE pattern (pview / bottomsheet), then load the
    /// orchestrator + only that pattern's implementation skills. Focused prompt, but
    /// composed from granular skills.
    private func routeSkills(request: ScaffoldRequest, design: String) async throws -> (text: String, directive: String, kind: String) {
        let (patterns, orchestrator, rootPath) = SkillLoader.routing(override: request.skillsRoot)

        guard !patterns.isEmpty else {
            await log("No orchestrator found — using built-in fallback.")
            return (SkillLoader.load(override: request.skillsRoot).text, "Follow the attached skills exactly.", "pview")
        }
        await log("Skills root: \(rootPath ?? "?") · patterns: \(patterns.map { $0.name }.joined(separator: ", "))")

        let chosen = try await classify(design: design, patterns: patterns, model: request.model)
        await log("Pattern: \(chosen.name) — \(chosen.trigger.prefix(70))")
        await log("Loading skills: \(chosen.skills.joined(separator: ", "))")

        var sections: [String] = [orchestrator]
        for skillName in chosen.skills {
            if let content = SkillLoader.implSkill(skillName, override: request.skillsRoot) {
                sections.append("\n\n## Skill: \(skillName)\n\n\(content)")
            } else {
                await log("⚠️ missing skill: \(skillName)")
            }
        }
        let directive = """
        This design is a "\(chosen.name)" pattern: \(chosen.trigger)
        Follow the attached implementation skills EXACTLY and produce only what they specify.
        Do not use any other pattern, and do not emit raw UIKit or plain SwiftUI unless a skill uses it.
        """
        return (sections.joined(separator: "\n"), directive, chosen.name)
    }

    /// Scoped RAG: embed the design, retrieve the most similar real files of the
    /// routed kind from the codebase index, and return them as example blocks.
    private func retrieveExamples(design: String, kind: String, request: ScaffoldRequest) async -> String {
        let indexName = request.ragIndexName
        guard CodebaseIndex.count(indexName) > 0 else {
            await log("No \(indexName) index found — build it first. Skipping examples.")
            return ""
        }
        guard let queryVector = try? await EmbeddingClient().embedQuery(design) else {
            await log("Embedding failed — skipping examples.")
            return ""
        }
        let paths = CodebaseIndex.search(name: indexName, queryVector: queryVector, kind: kind, k: request.ragTopK)
        guard !paths.isEmpty else {
            await log("No similar examples found.")
            return ""
        }
        var blocks: [String] = []
        for path in paths {
            await log("• \((path as NSString).lastPathComponent)")
            if let content = try? String(contentsOfFile: path, encoding: .utf8) {
                blocks.append("// \((path as NSString).lastPathComponent)\n\(String(content.prefix(2500)))")
            }
        }
        return blocks.joined(separator: "\n\n")
    }

    private func classify(design: String, patterns: [UIPattern], model: String) async throws -> UIPattern {
        guard patterns.count > 1 else { return patterns[0] }
        let list = patterns.map { "- \($0.name): \($0.trigger)" }.joined(separator: "\n")
        let raw = try await ollama.chat(
            model: model,
            system: "You route a design to exactly ONE UI pattern. Reply with JSON only.",
            user: "Patterns:\n\(list)\n\n## Design\n\(design.prefix(3000))\n\nReturn { \"pattern\": \"<exact name>\" } for the single best match.",
            format: [
                "type": "object",
                "properties": ["pattern": ["type": "string", "enum": patterns.map { $0.name }]],
                "required": ["pattern"],
            ],
            think: false,
            numPredict: 60,
            numCtx: 8192,
            timeout: 60
        )
        if
            let data = raw.data(using: .utf8),
            let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let pick = obj["pattern"] as? String,
            let match = patterns.first(where: { $0.name == pick })
        {
            return match
        }
        return patterns[0]
    }

    /// Step 2 pipeline: re-read the generated files against the verifier skill and rewrite
    /// any that violate the conventions. Best-effort — skips silently if no verifier.
    private func verifyFiles(_ files: [GeneratedFile], request: ScaffoldRequest) async -> [GeneratedFile] {
        guard let verifier = SkillLoader.orchestrator(SkillLoader.verifierOrchestrator, override: request.skillsRoot) else {
            return files
        }
        await phase("VERIFY")
        await log("Verifying \(files.count) file(s)…")
        let bundle = files.map { "// FILE: \($0.relativePath)\n\($0.content)" }.joined(separator: "\n\n")
        do {
            let raw = try await ollama.chat(
                model: request.model,
                system: verifier,
                user: "Verify and fix these files. Return all of them.\n\n\(String(bundle.prefix(14_000)))",
                format: GenerationSchema.filesEnvelope(), think: false, numPredict: 12_288, numCtx: 16_384, timeout: 300
            )
            guard
                let data = raw.data(using: .utf8),
                let envelope = try? JSONDecoder().decode(FilesEnvelope.self, from: data),
                !envelope.files.isEmpty
            else {
                await log("Verifier returned nothing usable — keeping originals.")
                return files
            }
            // Only accept verifier files whose path matches a generated file; keep the rest.
            var byPath = Dictionary(uniqueKeysWithValues: files.map { ($0.relativePath, $0) })
            for f in envelope.files where byPath[f.relativePath] != nil {
                byPath[f.relativePath] = GeneratedFile(relativePath: f.relativePath, content: f.content)
            }
            await log("Verifier reviewed \(envelope.files.count) file(s).")
            return files.map { byPath[$0.relativePath] ?? $0 }
        } catch {
            await log("Verify failed (\(error.localizedDescription)) — keeping originals.")
            return files
        }
    }

    // MARK: - Generation

    private func generateFiles(
        request: ScaffoldRequest,
        design: String,
        rootName: String,
        skillsText: String,
        directive: String,
        examples: String,
        feature: String,
        freeform: Bool = false
    ) async throws -> [GeneratedFile] {
        let system = Prompts.generationSystem(skills: skillsText, directive: directive, examples: examples)
        let user = Prompts.generationUser(
            module: request.moduleName,
            feature: feature,
            rootFrameName: rootName,
            design: design,
            freeform: freeform
        )

        await phase("PROMPT")
        await log("System \(system.count) chars · user \(user.count) chars · directive applied")
        if request.verbose {
            await log("── System prompt ──\n\(system)")
            await log("── User prompt ──\n\(user)")
        }

        await phase("GENERATION")
        await log("Asking \(request.model) to generate Swift (schema-enforced; may take a minute)…")
        let raw = try await ollama.chat(
            model: request.model,
            system: system,
            user: user,
            format: GenerationSchema.filesEnvelope(),
            think: false,
            numPredict: 12_288,
            timeout: 420
        )
        await log("Response: \(raw.count) chars")
        if request.verbose { await log("── Raw LLM response ──\n\(raw)") }

        guard
            let data = raw.data(using: .utf8),
            let envelope = try? JSONDecoder().decode(FilesEnvelope.self, from: data),
            !envelope.files.isEmpty
        else {
            throw ScaffoldEngineError.noFiles
        }
        await log("Files: " + envelope.files.map { $0.relativePath }.joined(separator: ", "))
        return envelope.files
    }

    private func writeFiles(_ files: [GeneratedFile], outputRoot: URL) throws -> [URL] {
        let fm = FileManager.default
        var written: [URL] = []
        for file in files {
            let normalized = file.relativePath
                .replacingOccurrences(of: "\\", with: "/")
                .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            guard !normalized.isEmpty else { continue }
            let url = outputRoot.appendingPathComponent(normalized)
            try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Self.stripCodeFences(file.content).write(to: url, atomically: true, encoding: .utf8)
            written.append(url)
        }
        return written
    }

    /// Models sometimes wrap file content in ```swift … ``` fences inside the JSON
    /// string; strip them so the written .swift file compiles.
    static func stripCodeFences(_ content: String) -> String {
        var s = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard s.hasPrefix("```") else { return s + "\n" }
        if let firstNewline = s.firstIndex(of: "\n") {
            s = String(s[s.index(after: firstNewline)...])
        }
        if let closing = s.range(of: "```", options: .backwards) {
            s = String(s[..<closing.lowerBound])
        }
        return s.trimmingCharacters(in: .whitespacesAndNewlines) + "\n"
    }

    private func defaultFeature(from frameName: String) -> String {
        let cleaned = frameName.unicodeScalars
            .filter { CharacterSet.alphanumerics.contains($0) }
        let base = String(String.UnicodeScalarView(cleaned))
        return base.isEmpty ? "Feature" : base
    }

    // MARK: - Side effects

    /// Opens generated files in Xcode via `xed`.
    static func openInXcode(_ files: [URL]) {
        guard !files.isEmpty else { return }
        let quoted = files.map { "'" + $0.path.replacingOccurrences(of: "'", with: "'\\''") + "'" }
        Shell.runDetached("xed \(quoted.joined(separator: " "))")
    }

    private func log(_ message: String) async {
        if let onLog { await onLog(message) }
    }

    /// Emits a visual phase divider so the log reads as distinct stages.
    private func phase(_ title: String) async {
        await log("━━━━━━━━━━  \(title)  ━━━━━━━━━━")
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? nil : trimmed
    }
}
