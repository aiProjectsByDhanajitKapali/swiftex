import Foundation

struct OllamaModel: Identifiable, Hashable {
    var id: String { name }
    let name: String
}

/// Which API the client speaks. `.ollama` = native /api/*; `.openAI` = OpenAI-compatible
/// /v1/* (mlx via vllm-mlx / mlx_lm.server / LM Studio).
enum LLMMode: String, Sendable { case ollama, openAI }

enum OllamaError: LocalizedError {
    case http(String)
    case empty

    var errorDescription: String? {
        switch self {
        case .http(let detail): return "Ollama HTTP error: \(detail)"
        case .empty: return "Ollama returned an empty response."
        }
    }
}

/// Thin async client over the local Ollama HTTP API (default 127.0.0.1:11434).
/// Mirrors the proven VS Code service: structured output via `format`, and
/// `think:false` so reasoning models (qwen3) don't burn the token budget on
/// hidden <think> output and return empty content.
final class OllamaClient {
    let baseURL: URL
    let mode: LLMMode

    /// For `.ollama` pass the host (e.g. http://127.0.0.1:11434). For `.openAI` pass the
    /// API base including /v1 (e.g. http://127.0.0.1:8000/v1).
    init(baseURL: URL = URL(string: "http://127.0.0.1:11434")!, mode: LLMMode = .ollama) {
        self.baseURL = baseURL
        self.mode = mode
    }

    private var statusPath: URL {
        mode == .ollama ? baseURL.appendingPathComponent("api/tags") : baseURL.appendingPathComponent("models")
    }

    func isRunning() async -> Bool {
        var request = URLRequest(url: statusPath)
        request.timeoutInterval = 3
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }

    /// Starts `ollama serve` detached, then waits (up to ~5s) for it to answer.
    @discardableResult
    func start() async -> Bool {
        if await isRunning() { return true }
        await Task.detached { Shell.runDetached("nohup ollama serve >/dev/null 2>&1 &") }.value
        for _ in 0..<10 {
            try? await Task.sleep(nanoseconds: 500_000_000)
            if await isRunning() { return true }
        }
        return false
    }

    @discardableResult
    func stop() async -> Bool {
        _ = await Task.detached { Shell.run("pkill -f 'ollama serve'") }.value
        return true
    }

    func listModels() async throws -> [OllamaModel] {
        let (data, response) = try await URLSession.shared.data(for: URLRequest(url: statusPath))
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw OllamaError.http("model list failed")
        }
        if mode == .openAI {
            struct Models: Decodable { struct M: Decodable { let id: String }; let data: [M]? }
            let parsed = try JSONDecoder().decode(Models.self, from: data)
            return (parsed.data ?? []).map { OllamaModel(name: $0.id) }
        }
        struct Tags: Decodable {
            struct Model: Decodable { let name: String }
            let models: [Model]?
        }
        let tags = try JSONDecoder().decode(Tags.self, from: data)
        return (tags.models ?? []).map { OllamaModel(name: $0.name) }
    }

    /// `format` is a JSON Schema object passed straight through to Ollama to force
    /// schema-valid output. `think:false` disables reasoning tokens where supported.
    func chat(
        model: String,
        system: String,
        user: String,
        /// Prior turns as {role, content} — sent so the model has conversation memory
        /// (Ollama is stateless; it only remembers what we resend).
        history: [[String: String]] = [],
        format: [String: Any]? = nil,
        think: Bool? = nil,
        numPredict: Int = 4096,
        /// Context window. Ollama defaults to only 4096 tokens regardless of the
        /// model's trained max, which silently truncates large prompts (skills +
        /// frame tree). Set this high enough to fit the whole prompt + output.
        numCtx: Int = 16_384,
        timeout: TimeInterval = 180
    ) async throws -> String {
        var messages: [[String: String]] = [["role": "system", "content": system]]
        messages.append(contentsOf: history)
        messages.append(["role": "user", "content": user])

        let endpoint: URL
        var body: [String: Any]
        if mode == .openAI {
            endpoint = baseURL.appendingPathComponent("chat/completions")
            body = [
                "model": model,
                "stream": false,
                "messages": messages,
                "temperature": 0.2,
                "max_tokens": numPredict,
            ]
            // OpenAI-style structured output (vllm-mlx / LM Studio: lm-format-enforcer).
            if let format {
                body["response_format"] = [
                    "type": "json_schema",
                    "json_schema": ["name": "output", "schema": format, "strict": true],
                ]
            }
        } else {
            endpoint = baseURL.appendingPathComponent("api/chat")
            body = [
                "model": model,
                "stream": false,
                "messages": messages,
                "options": ["temperature": 0.2, "num_predict": numPredict, "num_ctx": numCtx],
            ]
            if let format { body["format"] = format }
            if let think { body["think"] = think }
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = timeout

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw OllamaError.http("\(mode == .openAI ? "chat/completions" : "api/chat") status \(code)")
        }

        let content: String
        if mode == .openAI {
            struct OAResp: Decodable {
                struct Choice: Decodable { struct Msg: Decodable { let content: String? }; let message: Msg? }
                let choices: [Choice]?
            }
            let parsed = try JSONDecoder().decode(OAResp.self, from: data)
            content = parsed.choices?.first?.message?.content?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        } else {
            struct ChatResponse: Decodable {
                struct Message: Decodable { let content: String? }
                let message: Message?
            }
            let parsed = try JSONDecoder().decode(ChatResponse.self, from: data)
            content = parsed.message?.content?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        }
        guard !content.isEmpty else { throw OllamaError.empty }
        return content
    }
}
