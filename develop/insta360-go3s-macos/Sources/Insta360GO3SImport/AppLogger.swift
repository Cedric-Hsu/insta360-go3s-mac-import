import AppKit
import Foundation

enum AppLogger {
    static let logURL: URL = {
        let base = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/Insta360GO3SImport", isDirectory: true)
        return base.appendingPathComponent("perf.log")
    }()

    private static let queue = DispatchQueue(label: "insta360.perf.log", qos: .utility)

    static func log(
        _ component: String,
        _ message: String,
        durationMs: Double? = nil,
        extra: [String: Any] = [:]
    ) {
        queue.async {
            let timestamp = ISO8601DateFormatter().string(from: Date())
            var suffix = ""
            if let durationMs {
                suffix += String(format: " duration_ms=%.1f", durationMs)
            }
            if !extra.isEmpty,
               let data = try? JSONSerialization.data(withJSONObject: extra, options: [.sortedKeys]),
               let json = String(data: data, encoding: .utf8) {
                suffix += " \(json)"
            }
            let line = "\(timestamp) [\(component)] \(message)\(suffix)\n"
            append(line)
        }
    }

    static func timed<T>(
        _ component: String,
        _ step: String,
        extra: [String: Any] = [:],
        operation: () async throws -> T
    ) async rethrows -> T {
        let started = ContinuousClock.now
        log(component, "\(step) start", extra: extra)
        do {
            let value = try await operation()
            let elapsed = elapsedMs(since: started)
            log(component, "\(step) done", durationMs: elapsed, extra: extra)
            return value
        } catch {
            let elapsed = elapsedMs(since: started)
            var failure = extra
            failure["error"] = String(describing: error)
            log(component, "\(step) error", durationMs: elapsed, extra: failure)
            throw error
        }
    }

    static func revealInFinder() {
        let folder = logURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        if !FileManager.default.fileExists(atPath: logURL.path) {
            FileManager.default.createFile(atPath: logURL.path, contents: Data())
        }
        NSWorkspace.shared.activateFileViewerSelecting([logURL])
    }

    private static func append(_ line: String) {
        let folder = logURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        guard let data = line.data(using: .utf8) else { return }
        if FileManager.default.fileExists(atPath: logURL.path) {
            if let handle = try? FileHandle(forWritingTo: logURL) {
                defer { try? handle.close() }
                _ = try? handle.seekToEnd()
                try? handle.write(contentsOf: data)
            }
        } else {
            FileManager.default.createFile(atPath: logURL.path, contents: data)
        }
    }

    private static func elapsedMs(since start: ContinuousClock.Instant) -> Double {
        let duration = start.duration(to: ContinuousClock.now)
        return Double(duration.components.seconds) * 1000.0
            + Double(duration.components.attoseconds) / 1_000_000_000_000_000.0
    }
}
