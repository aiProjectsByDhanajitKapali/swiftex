import Foundation

struct FigmaParsedURL {
    let fileKey: String
    let nodeId: String?
}

struct FigmaNode {
    let id: String
    let name: String
    let type: String
    var children: [FigmaNode]
}

struct FigmaFrameContext {
    let fileKey: String
    let nodeId: String
    let fileName: String?
    let root: FigmaNode
    let treeMarkdown: String
}

enum FigmaError: LocalizedError {
    case noToken
    case badURL
    case noNodeId
    case http(Int, String)
    case nodeNotFound(String)

    var errorDescription: String? {
        switch self {
        case .noToken: return "Figma is not connected. Add your personal access token."
        case .badURL: return "Could not parse Figma URL. Paste a valid figma.com/design/… link."
        case .noNodeId: return "Figma URL must include node-id=… (copy the link from a selected frame)."
        case .http(let code, let body): return "Figma API error (\(code)): \(body.prefix(120))"
        case .nodeNotFound(let id): return "Node \(id) not found or not accessible."
        }
    }
}

/// Parses Figma links and fetches a simplified frame tree via the Figma REST API.
final class FigmaClient {
    private let base = URL(string: "https://api.figma.com/v1")!
    private let maxDepth = 6
    private let maxChildren = 30

    var token: String = ""

    var hasToken: Bool { !token.trimmingCharacters(in: .whitespaces).isEmpty }

    struct FigmaUser {
        let email: String?
        let handle: String?
    }

    /// Verifies the token and returns the connected account (Figma /v1/me).
    func me() async throws -> FigmaUser {
        guard hasToken else { throw FigmaError.noToken }
        var request = URLRequest(url: base.appendingPathComponent("me"))
        request.setValue(token, forHTTPHeaderField: "X-Figma-Token")
        request.timeoutInterval = 15
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            let body = String(data: data, encoding: .utf8) ?? ""
            throw FigmaError.http(code, body)
        }
        struct Me: Decodable { let email: String?; let handle: String? }
        let me = try JSONDecoder().decode(Me.self, from: data)
        return FigmaUser(email: me.email, handle: me.handle)
    }

    /// Extracts file key + node id even from pasted Cursor-style prompts
    /// ("Implement this design. @https://www.figma.com/design/<key>/...?node-id=13-46").
    func parse(_ input: String) -> FigmaParsedURL? {
        guard let keyMatch = firstMatch(
            in: input,
            pattern: #"https?://(?:www\.)?figma\.com/(?:design|file|proto|board)/([a-zA-Z0-9]+)"#,
            group: 1
        ) else {
            return nil
        }

        var nodeId: String? = nil
        if let rawNode = firstMatch(in: input, pattern: #"node-id=([0-9]+-[0-9]+|[0-9]+:[0-9]+)"#, group: 1) {
            nodeId = rawNode.replacingOccurrences(of: "-", with: ":")
        }
        return FigmaParsedURL(fileKey: keyMatch, nodeId: nodeId)
    }

    func fetchFrame(_ input: String) async throws -> FigmaFrameContext {
        guard hasToken else { throw FigmaError.noToken }
        guard let parsed = parse(input) else { throw FigmaError.badURL }
        guard let nodeId = parsed.nodeId else { throw FigmaError.noNodeId }

        let encodedId = nodeId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? nodeId
        let url = base.appendingPathComponent("files/\(parsed.fileKey)/nodes")
            .appending(queryItems: [URLQueryItem(name: "ids", value: nodeId)])

        var request = URLRequest(url: url)
        request.setValue(token, forHTTPHeaderField: "X-Figma-Token")
        request.timeoutInterval = 15
        _ = encodedId

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw FigmaError.http(-1, "no response")
        }
        guard http.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw FigmaError.http(http.statusCode, body)
        }

        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let nodes = json["nodes"] as? [String: Any],
            let entry = nodes[nodeId] as? [String: Any],
            let document = entry["document"] as? [String: Any]
        else {
            throw FigmaError.nodeNotFound(nodeId)
        }

        let fileName = (json["name"] as? String) ?? (entry["name"] as? String)
        let root = simplify(document, depth: 0)
        let tree = treeMarkdown(root)

        return FigmaFrameContext(
            fileKey: parsed.fileKey,
            nodeId: nodeId,
            fileName: fileName,
            root: root,
            treeMarkdown: tree
        )
    }

    // MARK: - Helpers

    private func simplify(_ node: [String: Any], depth: Int) -> FigmaNode {
        let id = node["id"] as? String ?? ""
        let name = node["name"] as? String ?? "?"
        let type = node["type"] as? String ?? "?"

        var children: [FigmaNode] = []
        if depth < maxDepth, let rawChildren = node["children"] as? [[String: Any]] {
            for child in rawChildren.prefix(maxChildren) {
                if let visible = child["visible"] as? Bool, visible == false { continue }
                children.append(simplify(child, depth: depth + 1))
            }
        }
        return FigmaNode(id: id, name: name, type: type, children: children)
    }

    private func treeMarkdown(_ node: FigmaNode, indent: Int = 0) -> String {
        let prefix = String(repeating: "  ", count: indent)
        var lines = ["\(prefix)- **\(node.name)** (\(node.type))"]
        for child in node.children {
            lines.append(treeMarkdown(child, indent: indent + 1))
        }
        return lines.joined(separator: "\n")
    }

    private func firstMatch(in text: String, pattern: String, group: Int) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard
            let match = regex.firstMatch(in: text, range: range),
            match.numberOfRanges > group,
            let groupRange = Range(match.range(at: group), in: text)
        else {
            return nil
        }
        return String(text[groupRange])
    }
}
