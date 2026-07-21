import Foundation

struct JiraIssue: Identifiable {
    var id: String { key }
    let key: String
    let summary: String
    let status: String
    let statusCategory: String   // "new", "indeterminate", "done"
    let type: String
    let priority: String
    let updated: String
}

struct JiraTransition: Identifiable {
    let id: String
    let name: String
}

struct JiraSprint {
    let id: Int
    let name: String
    let startDate: String?   // ISO8601
    let endDate: String?
}

enum JiraError: LocalizedError {
    case notConfigured
    case http(Int, String)

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "Add your Jira site, email, and API token first."
        case .http(let code, let detail): return "Jira API error (\(code)): \(detail.prefix(160))"
        }
    }
}

/// Jira Cloud REST client using API-token Basic auth (email:token). Read + write:
/// list assigned issues, fetch/apply transitions, add comments.
final class JiraService {
    var site = ""   // "yourcompany.atlassian.net" or a full URL — normalized to host
    var email = ""
    var token = ""

    var hasConfig: Bool {
        !host.isEmpty && !email.trimmed.isEmpty && !token.trimmed.isEmpty
    }

    private var host: String {
        site.replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
            .split(separator: "/").first.map(String.init)?.trimmed ?? ""
    }

    func browseURL(_ key: String) -> URL? { URL(string: "https://\(host)/browse/\(key)") }

    /// Verifies the token, returns the account display name.
    func testConnection() async throws -> String {
        let json = try await get("/rest/api/3/myself")
        let obj = json as? [String: Any]
        return (obj?["displayName"] as? String) ?? (obj?["emailAddress"] as? String) ?? "Jira user"
    }

    /// Active sprint for a board (Agile API). Returns nil if none/board not set.
    func activeSprint(boardId: String) async throws -> JiraSprint? {
        let trimmed = boardId.trimmed
        guard !trimmed.isEmpty else { return nil }
        let json = try await get("/rest/agile/1.0/board/\(trimmed)/sprint?state=active")
        let values = (json as? [String: Any])?["values"] as? [[String: Any]] ?? []
        guard let s = values.first, let id = s["id"] as? Int else { return nil }
        return JiraSprint(
            id: id,
            name: s["name"] as? String ?? "Sprint \(id)",
            startDate: s["startDate"] as? String,
            endDate: s["endDate"] as? String
        )
    }

    func issues(jql: String) async throws -> [JiraIssue] {
        let q = jql.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? jql
        let path = "/rest/api/3/search/jql?jql=\(q)&fields=summary,status,issuetype,priority,updated&maxResults=50"
        let json = try await get(path)
        let issues = (json as? [String: Any])?["issues"] as? [[String: Any]] ?? []
        return issues.map { issue in
            let fields = issue["fields"] as? [String: Any] ?? [:]
            let status = fields["status"] as? [String: Any]
            let category = (status?["statusCategory"] as? [String: Any])?["key"] as? String
            return JiraIssue(
                key: issue["key"] as? String ?? "?",
                summary: fields["summary"] as? String ?? "(no summary)",
                status: status?["name"] as? String ?? "?",
                statusCategory: category ?? "new",
                type: (fields["issuetype"] as? [String: Any])?["name"] as? String ?? "",
                priority: (fields["priority"] as? [String: Any])?["name"] as? String ?? "",
                updated: String((fields["updated"] as? String ?? "").prefix(10))
            )
        }
    }

    func transitions(for key: String) async throws -> [JiraTransition] {
        let json = try await get("/rest/api/3/issue/\(key)/transitions")
        let list = (json as? [String: Any])?["transitions"] as? [[String: Any]] ?? []
        return list.compactMap { t in
            guard let id = t["id"] as? String, let name = t["name"] as? String else { return nil }
            return JiraTransition(id: id, name: name)
        }
    }

    func applyTransition(key: String, transitionId: String) async throws {
        try await post("/rest/api/3/issue/\(key)/transitions", body: ["transition": ["id": transitionId]])
    }

    func addComment(key: String, text: String) async throws {
        // API v3 comment bodies are ADF (Atlassian Document Format).
        let adf: [String: Any] = [
            "body": [
                "type": "doc", "version": 1,
                "content": [["type": "paragraph", "content": [["type": "text", "text": text]]]],
            ],
        ]
        try await post("/rest/api/3/issue/\(key)/comment", body: adf)
    }

    // MARK: - HTTP

    private func authHeader() -> String {
        "Basic " + Data("\(email.trimmed):\(token.trimmed)".utf8).base64EncodedString()
    }

    private func request(_ path: String, method: String) throws -> URLRequest {
        guard hasConfig, let url = URL(string: "https://\(host)\(path)") else {
            throw JiraError.notConfigured
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(authHeader(), forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 20
        return request
    }

    private func get(_ path: String) async throws -> Any {
        let (data, response) = try await URLSession.shared.data(for: try request(path, method: "GET"))
        try Self.check(response, data)
        return try JSONSerialization.jsonObject(with: data)
    }

    @discardableResult
    private func post(_ path: String, body: [String: Any]) async throws -> Data {
        var req = try request(path, method: "POST")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: req)
        try Self.check(response, data)
        return data
    }

    private static func check(_ response: URLResponse, _ data: Data) throws {
        guard let http = response as? HTTPURLResponse else { throw JiraError.http(-1, "no response") }
        guard (200...299).contains(http.statusCode) else {
            throw JiraError.http(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
    }
}
