import Foundation

enum FigmaMCPError: LocalizedError {
    case unreachable
    case rpc(String)
    case noContent

    var errorDescription: String? {
        switch self {
        case .unreachable: return "Figma Dev Mode MCP server not reachable (is Figma desktop open with the MCP server enabled?)."
        case .rpc(let m): return "Figma MCP error: \(m)"
        case .noContent: return "Figma MCP returned no design context."
        }
    }
}

/// Minimal MCP client for the local Figma Dev Mode MCP server (streamable HTTP,
/// JSON-RPC 2.0 over `http://127.0.0.1:3845/mcp`). Calls `get_design_context`,
/// which returns the selected node as code + design-system token names — much
/// richer than the REST layer tree.
final class FigmaMCPClient {
    let endpoint: URL
    private var sessionId: String?

    init(endpoint: URL = URL(string: "http://127.0.0.1:3845/mcp")!) {
        self.endpoint = endpoint
    }

    func isAvailable() async -> Bool {
        (try? await initializeSession(timeout: 4)) != nil
    }

    /// Returns the design context (code + tokens) for a node id like "13085:43635".
    func designContext(nodeId: String) async throws -> String {
        try await ensureSession()
        var args: [String: Any] = [
            "nodeId": nodeId,
            "clientLanguages": "swift",
            "clientFrameworks": "swiftui",
        ]
        var text = try await callTool("get_design_context", arguments: args, timeout: 180)
        // If Code Connect isn't configured, Figma returns a prompt instead of the
        // context; retry with it disabled to get the actual design.
        let lower = text.lowercased()
        if lower.contains("code connect") && (lower.contains("missing") || lower.contains("disablecodeconnect")) {
            args["disableCodeConnect"] = true
            text = try await callTool("get_design_context", arguments: args, timeout: 180)
        }
        return Self.sanitize(text)
    }

    /// Drops the generic agent boilerplate Figma appends ("SUPER CRITICAL: convert
    /// React…", screenshot/asset notes) but keeps the code and the style/token defs.
    private static func sanitize(_ raw: String) -> String {
        var code = raw
        if let cut = code.range(of: "SUPER CRITICAL") {
            code = String(code[..<cut.lowerBound])
        }
        code = code.trimmingCharacters(in: .whitespacesAndNewlines)
        // Preserve the "These styles are contained in the design: …" line (font tokens).
        if let sr = raw.range(of: "These styles are contained in the design:") {
            let line = raw[sr.lowerBound...].prefix { !$0.isNewline }
            code += "\n\nStyles: " + line.replacingOccurrences(of: "These styles are contained in the design:", with: "").trimmingCharacters(in: .whitespaces)
        }
        return code
    }

    // MARK: - Handshake

    @discardableResult
    private func initializeSession(timeout: TimeInterval) async throws -> String {
        let (_, sid) = try await rpc([
            "jsonrpc": "2.0", "id": 1, "method": "initialize",
            "params": [
                "protocolVersion": "2024-11-05",
                "capabilities": [:],
                "clientInfo": ["name": "swiftex", "version": "0.1"],
            ],
        ], timeout: timeout)
        guard let sid else { throw FigmaMCPError.rpc("no session id returned") }
        sessionId = sid
        _ = try? await rpc(["jsonrpc": "2.0", "method": "notifications/initialized"], timeout: 10)
        return sid
    }

    private func ensureSession() async throws {
        if sessionId == nil { _ = try await initializeSession(timeout: 10) }
    }

    private func callTool(_ name: String, arguments: [String: Any], timeout: TimeInterval) async throws -> String {
        let (json, _) = try await rpc([
            "jsonrpc": "2.0", "id": 2, "method": "tools/call",
            "params": ["name": name, "arguments": arguments],
        ], timeout: timeout)

        if let error = json["error"] as? [String: Any] {
            throw FigmaMCPError.rpc(String(describing: error["message"] ?? error))
        }
        guard
            let result = json["result"] as? [String: Any],
            let content = result["content"] as? [[String: Any]]
        else {
            throw FigmaMCPError.noContent
        }
        let text = content
            .compactMap { ($0["type"] as? String) == "text" ? $0["text"] as? String : nil }
            .joined(separator: "\n")
        guard !text.isEmpty else { throw FigmaMCPError.noContent }
        return text
    }

    // MARK: - Transport (streamable HTTP, SSE-framed responses)

    private func rpc(_ payload: [String: Any], timeout: TimeInterval) async throws -> (json: [String: Any], sessionId: String?) {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json, text/event-stream", forHTTPHeaderField: "Accept")
        if let sessionId { request.setValue(sessionId, forHTTPHeaderField: "Mcp-Session-Id") }
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        request.timeoutInterval = timeout

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw FigmaMCPError.unreachable
        }
        guard let http = response as? HTTPURLResponse else { throw FigmaMCPError.unreachable }
        let sid = http.value(forHTTPHeaderField: "Mcp-Session-Id")

        let body = String(data: data, encoding: .utf8) ?? ""
        let jsonText = Self.extractJSON(body)
        guard !jsonText.isEmpty else { return ([:], sid) }
        let obj = (try? JSONSerialization.jsonObject(with: Data(jsonText.utf8))) as? [String: Any] ?? [:]
        return (obj, sid)
    }

    /// SSE responses arrive as `event: message\ndata: {json}` lines; take the last data payload.
    private static func extractJSON(_ body: String) -> String {
        guard body.contains("data:") else { return body }
        let datas = body
            .split(whereSeparator: \.isNewline)
            .filter { $0.hasPrefix("data:") }
            .map { $0.dropFirst("data:".count).trimmingCharacters(in: .whitespaces) }
        return datas.last ?? ""
    }
}
