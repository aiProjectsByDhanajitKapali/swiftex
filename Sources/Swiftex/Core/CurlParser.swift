import Foundation

struct CurlRequest {
    var method: String
    var url: String
    var headers: [(String, String)]
    var queryParams: [(String, String)]
    var bodyParams: [(String, String)]
    var rawBody: String?

    /// All param names the user may need to source (query + body).
    var paramNames: [String] {
        var seen = Set<String>()
        return (queryParams + bodyParams).map { $0.0 }.filter { seen.insert($0).inserted }
    }
}

/// How a ViewModel triggers the API call.
enum ApiTrigger: String, CaseIterable, Identifiable {
    case onAppear = "On appear"
    case onInit = "On init"
    case buttonTap = "Button tap"
    case refresh = "Refresh / retry"
    var id: String { rawValue }
}

/// Where a request param's value comes from in the ViewModel.
enum ApiParamSource: String, CaseIterable, Identifiable {
    case textField = "Text field"
    case storedProperty = "Stored property"
    case literal = "Literal"
    case arrayFirst = "First of array"
    case dictValue = "Dictionary value"
    var id: String { rawValue }
}

struct ApiParamMapping: Identifiable {
    var id: String { name }
    let name: String
    var source: ApiParamSource = .storedProperty
    var value: String = ""   // e.g. property name, the text field's view-model, or a literal
}

/// A proposed file change to review before writing.
struct ProposedFile: Identifiable {
    var id: String { relativePath }
    let relativePath: String
    let newContent: String
    let oldContent: String?   // nil = new file
    var apply: Bool = true
    var isNew: Bool { oldContent == nil }
}

/// Best-effort cURL parser (handles -X/-H/-d, JSON or form bodies, query strings).
enum CurlParser {
    static func parse(_ raw: String) -> CurlRequest? {
        let tokens = tokenize(raw.replacingOccurrences(of: "\\\n", with: " "))
        guard !tokens.isEmpty else { return nil }

        var method: String?
        var url: String?
        var headers: [(String, String)] = []
        var body: String?

        var i = 0
        while i < tokens.count {
            let t = tokens[i]
            switch t {
            case "curl":
                break
            case "-X", "--request":
                i += 1; if i < tokens.count { method = tokens[i].uppercased() }
            case "-H", "--header":
                i += 1
                if i < tokens.count, let (k, v) = splitHeader(tokens[i]) { headers.append((k, v)) }
            case "-d", "--data", "--data-raw", "--data-binary", "--data-urlencode":
                i += 1; if i < tokens.count { body = (body ?? "") + tokens[i] }
            case "-u", "--user", "-A", "--user-agent", "-e", "--referer", "-b", "--cookie":
                i += 1   // flag with an arg we don't need
            default:
                if t.hasPrefix("http://") || t.hasPrefix("https://") {
                    url = t
                } else if !t.hasPrefix("-"), url == nil, t.contains("/") {
                    url = t
                }
            }
            i += 1
        }

        guard let finalURL = url else { return nil }
        let (_, query) = splitURL(finalURL)
        let resolvedMethod = method ?? (body != nil ? "POST" : "GET")
        let bodyParams = body.map(parseBody) ?? []

        return CurlRequest(
            method: resolvedMethod,
            url: finalURL,
            headers: headers,
            queryParams: query,
            bodyParams: bodyParams,
            rawBody: body
        )
    }

    // MARK: - Helpers

    private static func tokenize(_ s: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        var quote: Character?
        for ch in s {
            if let q = quote {
                if ch == q { quote = nil } else { current.append(ch) }
            } else if ch == "\"" || ch == "'" {
                quote = ch
            } else if ch == " " || ch == "\n" || ch == "\t" {
                if !current.isEmpty { tokens.append(current); current = "" }
            } else {
                current.append(ch)
            }
        }
        if !current.isEmpty { tokens.append(current) }
        return tokens
    }

    private static func splitHeader(_ h: String) -> (String, String)? {
        guard let r = h.range(of: ":") else { return nil }
        let k = String(h[..<r.lowerBound]).trimmingCharacters(in: .whitespaces)
        let v = String(h[r.upperBound...]).trimmingCharacters(in: .whitespaces)
        return k.isEmpty ? nil : (k, v)
    }

    private static func splitURL(_ url: String) -> (String, [(String, String)]) {
        guard let r = url.range(of: "?") else { return (url, []) }
        let path = String(url[..<r.lowerBound])
        let queryString = String(url[r.upperBound...])
        let params = queryString.split(separator: "&").compactMap { pair -> (String, String)? in
            let kv = pair.split(separator: "=", maxSplits: 1)
            guard let k = kv.first else { return nil }
            return (String(k), kv.count > 1 ? String(kv[1]) : "")
        }
        return (path, params)
    }

    private static func parseBody(_ body: String) -> [(String, String)] {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("{"),
           let data = trimmed.data(using: .utf8),
           let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return obj.keys.sorted().map { ($0, String(describing: obj[$0] ?? "")) }
        }
        // form-encoded
        return trimmed.split(separator: "&").compactMap { pair in
            let kv = pair.split(separator: "=", maxSplits: 1)
            guard let k = kv.first else { return nil }
            return (String(k), kv.count > 1 ? String(kv[1]) : "")
        }
    }
}
