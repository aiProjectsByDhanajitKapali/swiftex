import Foundation

/// Runs commands through a login shell so the app inherits the user's PATH
/// (Homebrew etc.) — important for finding `ollama`, `git`, and `xed` when the
/// app is launched from Finder/Xcode rather than a terminal.
enum Shell {
    struct Result: Sendable {
        let status: Int32
        let output: String
        var ok: Bool { status == 0 }
    }

    @discardableResult
    static func run(_ command: String) -> Result {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-lc", command]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.run()
        } catch {
            return Result(status: -1, output: error.localizedDescription)
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let output = String(data: data, encoding: .utf8) ?? ""
        return Result(status: process.terminationStatus, output: output)
    }

    /// Fire-and-forget (used to launch `ollama serve` in the background).
    static func runDetached(_ command: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-lc", command]
        try? process.run()
    }
}
