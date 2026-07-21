import Foundation

/// One indexed chunk from the codebase.
struct IndexEntry: Codable {
    let path: String
    let chunkIndex: Int
    /// "pview", "bottomsheet", or "code".
    let kind: String
    /// The chunk text (so retrieval can inject it directly).
    let text: String
    let vector: [Float]
}

/// A retrieval hit with its score.
struct Hit {
    let path: String
    let chunkIndex: Int
    let text: String
    let score: Float
    /// Score breakdown for the debug log (e.g. "cos 0.66 +file +decl lex 1.0").
    var detail: String = ""
}

/// Local RAG store. Two named indexes coexist on disk:
///   - "generation" — PView views + BottomSheetBuilder files, embedded whole (we want
///     whole-file examples to mimic).
///   - "chat" — every Swift file, split into ~800-char chunks (sharp retrieval for Q&A).
/// Embeddings are local (Ollama nomic-embed-text) with search_document/search_query prefixes.
enum CodebaseIndex {
    enum Mode { case examples, all }

    private static let embedder = EmbeddingClient()
    private static var cache: [String: [IndexEntry]] = [:]

    private static let chunkSize = 800
    private static let chunkOverlap = 120

    private static func dir() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let d = base.appendingPathComponent("Swiftex", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }

    static func storeURL(_ name: String) -> URL { dir().appendingPathComponent("index-\(name).json") }
    private static func metaURL(_ name: String) -> URL { dir().appendingPathComponent("index-\(name).meta.json") }

    /// WARNING: decodes the entire index (can be hundreds of MB). Never call on the
    /// main thread — wrap in `Task.detached`.
    static func load(_ name: String) -> [IndexEntry] {
        if let cached = cache[name] { return cached }
        guard let data = try? Data(contentsOf: storeURL(name)) else { return [] }
        let entries = (try? JSONDecoder().decode([IndexEntry].self, from: data)) ?? []
        cache[name] = entries
        writeMeta(name, distinctFiles(entries))
        return entries
    }

    /// Distinct file count — reads a tiny sidecar so launch never loads the full index.
    /// Falls back to a full load (off-main!) once, then the sidecar exists.
    static func count(_ name: String) -> Int {
        if let cached = cache[name] { return distinctFiles(cached) }
        if let n = readMeta(name) { return n }
        return distinctFiles(load(name))
    }

    private static func distinctFiles(_ entries: [IndexEntry]) -> Int {
        Set(entries.map { $0.path }).count
    }

    private static func readMeta(_ name: String) -> Int? {
        guard
            let data = try? Data(contentsOf: metaURL(name)),
            let meta = try? JSONDecoder().decode([String: Int].self, from: data)
        else { return nil }
        return meta["files"]
    }

    private static func writeMeta(_ name: String, _ files: Int) {
        try? JSONEncoder().encode(["files": files]).write(to: metaURL(name), options: .atomic)
    }

    private static func save(_ name: String, _ entries: [IndexEntry]) throws {
        try JSONEncoder().encode(entries).write(to: storeURL(name), options: .atomic)
        cache[name] = entries
        writeMeta(name, distinctFiles(entries))
    }

    // MARK: - Indexing

    static func build(
        name: String,
        roots: [URL],
        mode: Mode,
        onProgress: @escaping @Sendable (Int, Int) async -> Void
    ) async throws -> Int {
        let files = await Task.detached { collectCandidates(roots, mode: mode) }.value
        var entries: [IndexEntry] = []
        for (i, candidate) in files.enumerated() {
            if let content = try? String(contentsOfFile: candidate.path, encoding: .utf8) {
                // Generation examples are embedded whole (we inject the whole file later);
                // chat chunks each file for sharp retrieval.
                let chunks = mode == .all ? chunkText(content) : [String(content.prefix(8000))]
                for (ci, chunk) in chunks.enumerated() {
                    if let vector = try? await embedder.embedDocument(chunk) {
                        entries.append(IndexEntry(
                            path: candidate.path, chunkIndex: ci, kind: candidate.kind,
                            text: mode == .all ? chunk : "", vector: vector
                        ))
                    }
                }
            }
            await onProgress(i + 1, files.count)
        }
        try save(name, entries)
        return Set(entries.map { $0.path }).count
    }

    /// Paragraph-packed chunks (~chunkSize chars, chunkOverlap overlap) — mirrors the
    /// approach axiom.ios uses for code/text retrieval.
    static func chunkText(_ text: String) -> [String] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let paragraphs = trimmed.components(separatedBy: "\n\n")
        var chunks: [String] = []
        var current = ""
        for rawPara in paragraphs {
            let para = rawPara.trimmingCharacters(in: .whitespacesAndNewlines)
            if para.isEmpty { continue }
            if current.count + para.count + 2 <= chunkSize {
                current = current.isEmpty ? para : current + "\n\n" + para
            } else {
                if !current.isEmpty { chunks.append(current) }
                if para.count <= chunkSize {
                    current = para
                } else {
                    var start = para.startIndex
                    while start < para.endIndex {
                        let end = para.index(start, offsetBy: chunkSize, limitedBy: para.endIndex) ?? para.endIndex
                        chunks.append(String(para[start..<end]))
                        let next = para.index(end, offsetBy: -chunkOverlap, limitedBy: para.startIndex) ?? para.endIndex
                        if next <= start { break }
                        start = next
                    }
                    current = ""
                }
            }
        }
        if !current.isEmpty { chunks.append(current) }
        return chunks
    }

    private struct Candidate { let path: String; let kind: String }

    private static let excludedComponents: Set<String> = [
        "Pods", "build", "DerivedData", ".build", "Carthage", ".git", "node_modules",
    ]

    private static func collectCandidates(_ roots: [URL], mode: Mode) -> [Candidate] {
        let fm = FileManager.default
        var out: [Candidate] = []
        for root in roots {
            guard let en = fm.enumerator(at: root, includingPropertiesForKeys: nil) else { continue }
            for case let url as URL in en {
                guard url.pathExtension == "swift" else { continue }
                let comps = Set(url.pathComponents)
                if !comps.isDisjoint(with: excludedComponents) { continue }
                let lower = url.path.lowercased()
                if lower.contains("test") || lower.contains("preview") || url.lastPathComponent == "R.generated.swift" {
                    continue
                }
                guard let content = try? String(contentsOf: url, encoding: .utf8) else { continue }

                let kind: String
                if content.contains("BottomSheetBuilder(") {
                    kind = "bottomsheet"
                } else if url.path.contains("/View/") && content.range(of: #":\s*PView\b"#, options: .regularExpression) != nil {
                    kind = "pview"
                } else {
                    kind = "code"
                }

                if mode == .examples && kind == "code" { continue }
                out.append(Candidate(path: url.path, kind: kind))
            }
        }
        return out
    }

    // MARK: - Retrieval

    /// Distinct top file paths (for generation examples — we inject whole files).
    static func search(name: String, queryVector: [Float], kind: String, k: Int) -> [String] {
        var seen = Set<String>()
        var paths: [String] = []
        for hit in searchHits(name: name, queryVector: queryVector, queryText: "", kind: kind, k: k * 4) {
            if seen.insert(hit.path).inserted {
                paths.append(hit.path)
                if paths.count == k { break }
            }
        }
        return paths
    }

    /// Hybrid top-`k` chunks: a cheap cosine pre-filter, then a lexical + symbol-match
    /// re-rank on the top candidates (so exact-symbol questions like "what is PImageView"
    /// reliably surface the declaring file). Pass `queryText` to enable the boosts; ""
    /// = pure cosine. A non-empty `kind` filters to that kind (falls back to all).
    static func searchHits(name: String, queryVector: [Float], queryText: String, kind: String, k: Int) -> [Hit] {
        let all = load(name)
        guard !all.isEmpty else { return [] }
        let pool: [IndexEntry] = {
            guard !kind.isEmpty else { return all }
            let f = all.filter { $0.kind == kind }
            return f.count >= k ? f : all
        }()

        let terms = significantTerms(queryText)

        // Score EVERY chunk with cosine + cheap boosts (filename + lexical, no regex),
        // so a symbol/filename match lifts the right file into contention even when its
        // cosine is low. Then keep the top candidates for the (pricier) declaration pass.
        let scored = pool.map { entry -> (entry: IndexEntry, cos: Float, cheap: Float, tags: [String]) in
            let cos = Vector.cosine(queryVector, entry.vector)
            guard !terms.isEmpty else { return (entry, cos, 0, []) }
            var cheap: Float = 0
            var tags: [String] = []
            let fileBase = (entry.path as NSString).lastPathComponent
                .replacingOccurrences(of: ".swift", with: "").lowercased()
            if terms.contains(where: { fileBase.contains($0) }) { cheap += 0.25; tags.append("+file") }
            let text = entry.text.lowercased()
            let matched = terms.filter { text.contains($0) }.count
            if matched > 0 {
                let ratio = Float(matched) / Float(terms.count)
                cheap += 0.15 * ratio
                tags.append(String(format: "lex %.1f", ratio))
            }
            return (entry, cos, cheap, tags)
        }

        let candidates = scored.sorted { ($0.cos + $0.cheap) > ($1.cos + $1.cheap) }.prefix(max(k * 8, 40))

        // Declaration match (regex) only on the shortlist.
        let hits = candidates.map { item -> Hit in
            var score = item.cos + item.cheap
            var tags = item.tags
            if !terms.isEmpty, declarationMatches(terms: terms, text: item.entry.text) {
                score += 0.15
                tags.append("+decl")
            }
            let detail = String(format: "cos %.3f", item.cos) + (tags.isEmpty ? "" : " " + tags.joined(separator: " "))
            return Hit(path: item.entry.path, chunkIndex: item.entry.chunkIndex,
                       text: item.entry.text, score: score, detail: detail)
        }
        return hits.sorted { $0.score > $1.score }.prefix(k).map { $0 }
    }

    // MARK: - Hybrid scoring helpers

    private static let stopwords: Set<String> = [
        "what", "whats", "which", "is", "are", "the", "this", "that", "how", "does", "do",
        "we", "you", "to", "of", "in", "for", "and", "or", "me", "where", "when", "why",
        "with", "can", "show", "tell", "about", "use", "used", "using", "explain",
    ]

    private static func significantTerms(_ query: String) -> [String] {
        let raw = query.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted)
        var seen = Set<String>()
        return raw.filter { $0.count >= 3 && !stopwords.contains($0) && seen.insert($0).inserted }
    }

    private static let declRegex = try? NSRegularExpression(
        pattern: #"\b(?:struct|class|enum|protocol|extension|func|var|let|typealias)\s+([A-Za-z_][A-Za-z0-9_]*)"#
    )

    /// True if any query term matches a declared symbol (`struct/class/func …`) in the text.
    private static func declarationMatches(terms: [String], text: String) -> Bool {
        guard let regex = declRegex else { return false }
        let ns = text as NSString
        var declNames = Set<String>()
        for m in regex.matches(in: text, range: NSRange(location: 0, length: ns.length)) where m.numberOfRanges > 1 {
            declNames.insert(ns.substring(with: m.range(at: 1)).lowercased())
        }
        return terms.contains { term in declNames.contains { $0.contains(term) } }
    }
}
