import Foundation

struct LoadedSkills: Sendable {
    let text: String
    let sources: [String]
    let rootPath: String?
    var isEmpty: Bool { text.isEmpty }
}

/// A UI pattern declared in the orchestrator: a name, a trigger description, and the
/// implementation skills (in impl-skills/) to load for it.
struct UIPattern: Sendable {
    let name: String
    let trigger: String
    let skills: [String]
}

/// Skills live in two folders under the resolved skills root:
///   - `swiftex-skills/` — orchestrators (entry: swiftex-ui-builder.md; swiftex-ui-verifier.md)
///   - `impl-skills/`  — granular implementation skills (pview-architecture, ptext, …)
/// The orchestrator declares, per pattern, which implementation skills to compose.
enum SkillLoader {
    static let orchestratorDir = "swiftex-skills"
    static let implDir = "impl-skills"
    static let entryOrchestrator = "swiftex-ui-builder.md"
    static let verifierOrchestrator = "swiftex-ui-verifier.md"

    // MARK: - Resolution

    static func resolveRoot(override: URL?) -> URL? {
        var candidates: [URL] = []
        if let override { candidates.append(override) }
        candidates.append(URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("skills"))
        if let pkg = packageSkillsURL() { candidates.append(pkg) }
        for candidate in candidates {
            let entry = candidate.appendingPathComponent("\(orchestratorDir)/\(entryOrchestrator)")
            if FileManager.default.fileExists(atPath: entry.path) { return candidate }
        }
        return nil
    }

    // MARK: - Orchestrator + patterns

    /// Returns the parsed patterns, the orchestrator text (general contract/tokens), and root.
    static func routing(override: URL?) -> (patterns: [UIPattern], orchestrator: String, rootPath: String?) {
        guard
            let root = resolveRoot(override: override),
            let text = try? String(contentsOf: root.appendingPathComponent("\(orchestratorDir)/\(entryOrchestrator)"), encoding: .utf8)
        else {
            return ([], "", nil)
        }
        var patterns: [UIPattern] = []
        if let regex = try? NSRegularExpression(
            pattern: #"^-\s*([\w-]+)\s*[—\-]\s*(.+?)\s+skills:\s*(.+)$"#,
            options: [.anchorsMatchLines]
        ) {
            let range = NSRange(text.startIndex..., in: text)
            for m in regex.matches(in: text, range: range) {
                guard
                    let nr = Range(m.range(at: 1), in: text),
                    let tr = Range(m.range(at: 2), in: text),
                    let sr = Range(m.range(at: 3), in: text)
                else { continue }
                let skills = String(text[sr]).split(separator: ",").map {
                    $0.trimmingCharacters(in: .whitespaces)
                }.filter { !$0.isEmpty }
                patterns.append(UIPattern(
                    name: String(text[nr]),
                    trigger: String(text[tr]).trimmingCharacters(in: .whitespaces),
                    skills: skills
                ))
            }
        }
        return (patterns, text, root.path)
    }

    /// Loads an implementation skill from impl-skills/ (name with or without .md).
    static func implSkill(_ name: String, override: URL?) -> String? {
        guard let root = resolveRoot(override: override) else { return nil }
        let file = name.hasSuffix(".md") ? name : "\(name).md"
        return try? String(contentsOf: root.appendingPathComponent("\(implDir)/\(file)"), encoding: .utf8)
    }

    /// Loads an orchestrator from swiftex-skills/ (e.g. the verifier).
    static func orchestrator(_ name: String, override: URL?) -> String? {
        guard let root = resolveRoot(override: override) else { return nil }
        return try? String(contentsOf: root.appendingPathComponent("\(orchestratorDir)/\(name)"), encoding: .utf8)
    }

    /// Looks up a skill by file name across impl-skills/ then swiftex-skills/ (used by the
    /// API tab which loads api-integration.md / api-vm-integration.md directly).
    static func skillContent(_ file: String, override: URL?) -> String? {
        guard let root = resolveRoot(override: override) else { return nil }
        for sub in [implDir, orchestratorDir] {
            let url = root.appendingPathComponent("\(sub)/\(file)")
            if let content = try? String(contentsOf: url, encoding: .utf8) { return content }
        }
        return nil
    }

    /// Fallback used only when no orchestrator/pattern is found.
    static func load(override: URL?) -> LoadedSkills {
        let (_, orchestrator, rootPath) = routing(override: override)
        return LoadedSkills(text: orchestrator, sources: availableSkills(override: override), rootPath: rootPath)
    }

    /// Skill file names available (for the Panel display).
    static func availableSkills(override: URL?) -> [String] {
        guard let root = resolveRoot(override: override) else { return [] }
        let fm = FileManager.default
        var names: [String] = []
        for sub in [orchestratorDir, implDir] {
            let dir = root.appendingPathComponent(sub)
            let files = (try? fm.contentsOfDirectory(atPath: dir.path)) ?? []
            names.append(contentsOf: files.filter { $0.hasSuffix(".md") }.sorted())
        }
        return names
    }

    private static func packageSkillsURL() -> URL? {
        let thisFile = URL(fileURLWithPath: #filePath)
        let packageRoot = thisFile
            .deletingLastPathComponent() // Core
            .deletingLastPathComponent() // Swiftex
            .deletingLastPathComponent() // Sources
            .deletingLastPathComponent() // package root
        return packageRoot.appendingPathComponent("skills")
    }
}
