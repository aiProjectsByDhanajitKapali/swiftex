import Foundation

enum EmbeddingError: LocalizedError {
    case http(String)
    case empty

    var errorDescription: String? {
        switch self {
        case .http(let d): return "Embedding HTTP error: \(d)"
        case .empty: return "Embedding model returned no vector."
        }
    }
}

/// Local embeddings via Ollama `/api/embed` (default model: nomic-embed-text, 768-d).
/// Used to index the codebase and retrieve similar real examples for generation.
final class EmbeddingClient {
    let baseURL: URL
    let model: String

    init(baseURL: URL = URL(string: "http://127.0.0.1:11434")!, model: String = "nomic-embed-text") {
        self.baseURL = baseURL
        self.model = model
    }

    /// nomic-embed-text is asymmetric: documents and queries must be prefixed with
    /// `search_document:` / `search_query:` for good retrieval. Use these, not embed().
    func embedDocument(_ text: String) async throws -> [Float] {
        try await embed("search_document: " + text)
    }

    func embedQuery(_ text: String) async throws -> [Float] {
        try await embed("search_query: " + text)
    }

    func embed(_ text: String, timeout: TimeInterval = 60) async throws -> [Float] {
        var request = URLRequest(url: baseURL.appendingPathComponent("api/embed"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "model": model,
            "input": String(text.prefix(8000)),
        ])
        request.timeoutInterval = timeout

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw EmbeddingError.http("status \((response as? HTTPURLResponse)?.statusCode ?? -1)")
        }
        struct Resp: Decodable { let embeddings: [[Float]]? }
        let parsed = try JSONDecoder().decode(Resp.self, from: data)
        guard let vector = parsed.embeddings?.first, !vector.isEmpty else {
            throw EmbeddingError.empty
        }
        return vector
    }
}

enum Vector {
    /// Cosine similarity of two equal-length vectors.
    static func cosine(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count, !a.isEmpty else { return 0 }
        var dot: Float = 0, na: Float = 0, nb: Float = 0
        for i in 0..<a.count {
            dot += a[i] * b[i]
            na += a[i] * a[i]
            nb += b[i] * b[i]
        }
        let denom = (na.squareRoot() * nb.squareRoot())
        return denom == 0 ? 0 : dot / denom
    }
}
