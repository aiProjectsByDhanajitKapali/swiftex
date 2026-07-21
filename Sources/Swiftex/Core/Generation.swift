import Foundation

/// One generated source file returned by the model.
struct GeneratedFile: Decodable {
    let relativePath: String
    let content: String
}

/// The model's response envelope — a flat list of files. This is the only output
/// structure Swiftex knows about; everything UI-specific lives in the skills.
struct FilesEnvelope: Decodable {
    let files: [GeneratedFile]
}

enum GenerationSchema {
    /// JSON Schema for Ollama's `format` — forces the `{ files: [{relativePath, content}] }`
    /// envelope so the response parses reliably regardless of model chatter.
    static func filesEnvelope() -> [String: Any] {
        [
            "type": "object",
            "properties": [
                "files": [
                    "type": "array",
                    "items": [
                        "type": "object",
                        "properties": [
                            "relativePath": ["type": "string"],
                            "content": ["type": "string"],
                        ],
                        "required": ["relativePath", "content"],
                    ],
                ],
            ],
            "required": ["files"],
        ]
    }
}
