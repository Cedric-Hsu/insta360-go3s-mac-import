import Foundation

enum PythonBridgeError: LocalizedError {
    case cliRootNotFound
    case pythonMissing
    case commandFailed(String)
    case invalidJSON(String)
    case importCancelled

    var errorDescription: String? {
        switch self {
        case .cliRootNotFound:
            return L10n.cliRootNotFound
        case .pythonMissing:
            return L10n.pythonMissing
        case .commandFailed(let detail):
            return detail
        case .invalidJSON(let detail):
            return "\(L10n.jsonParseFailed)：\(detail)"
        case .importCancelled:
            return L10n.importCancelledBridge
        }
    }
}

final class ImportSession {
    let process: Process
    let cancelFlagURL: URL
    private(set) var cancelRequested = false

    init(process: Process, cancelFlagURL: URL) {
        self.process = process
        self.cancelFlagURL = cancelFlagURL
    }

    func cancel() {
        cancelRequested = true
        try? Data("1".utf8).write(to: cancelFlagURL)
        if process.isRunning {
            process.interrupt()
            DispatchQueue.global().asyncAfter(deadline: .now() + 1.5) { [weak self] in
                guard let self, self.process.isRunning else { return }
                self.process.terminate()
            }
        }
    }
}

final class PythonBridge: @unchecked Sendable {
    static let defaultRelativeCLI = "../insta360-go3s-wifi"

    let cliRoot: URL
    let pythonExecutable: URL
    private let pythonPath: String
    var uiLanguageCode: String = "en"
    private(set) var activeSession: ImportSession?
    private let jsonProcessLock = NSLock()
    private var activeJSONProcess: Process?

    init() throws {
        cliRoot = try Self.resolveCliRoot()
        pythonExecutable = try Self.resolvePythonExecutable(cliRoot: cliRoot)
        pythonPath = Self.buildPythonPath(cliRoot: cliRoot)
    }

    private static func resolvePythonExecutable(cliRoot: URL) throws -> URL {
        let candidates: [URL] = [
            cliRoot.appendingPathComponent(".venv/bin/python"),
            URL(fileURLWithPath: "/usr/bin/python3"),
            URL(fileURLWithPath: "/opt/homebrew/bin/python3"),
            URL(fileURLWithPath: "/usr/local/bin/python3"),
        ]
        for candidate in candidates where FileManager.default.isExecutableFile(atPath: candidate.path) {
            if canRunPython(at: candidate, pythonPath: buildPythonPath(cliRoot: cliRoot)) {
                return candidate
            }
        }
        throw PythonBridgeError.pythonMissing
    }

    private static func canRunPython(at executable: URL, pythonPath: String) -> Bool {
        let process = Process()
        process.executableURL = executable
        process.arguments = ["-c", "import insta360_go3s_wifi"]
        var env = ProcessInfo.processInfo.environment
        if !pythonPath.isEmpty {
            env["PYTHONPATH"] = pythonPath
        }
        process.environment = env
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    private static func buildPythonPath(cliRoot: URL) -> String {
        var paths: [String] = []
        let src = cliRoot.appendingPathComponent("src")
        if FileManager.default.fileExists(atPath: src.path) {
            paths.append(src.path)
        }
        let libRoot = cliRoot.appendingPathComponent(".venv/lib")
        if let versions = try? FileManager.default.contentsOfDirectory(atPath: libRoot.path) {
            for version in versions.sorted() where version.hasPrefix("python3.") {
                let site = libRoot.appendingPathComponent("\(version)/site-packages")
                if FileManager.default.fileExists(atPath: site.path) {
                    paths.append(site.path)
                }
            }
        }
        return paths.joined(separator: ":")
    }

    private static func resolveCliRoot() throws -> URL {
        if let env = ProcessInfo.processInfo.environment["INSTA360_CLI_ROOT"] {
            return URL(fileURLWithPath: env, isDirectory: true).standardizedFileURL
        }

        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let devCandidate = cwd.appendingPathComponent(Self.defaultRelativeCLI, isDirectory: true)
        if FileManager.default.fileExists(atPath: devCandidate.path) {
            return devCandidate.standardizedFileURL
        }

        if let resourceRoot = Bundle.main.resourceURL {
            let bundled = resourceRoot.appendingPathComponent("insta360-go3s-wifi", isDirectory: true)
            if FileManager.default.fileExists(atPath: bundled.path) {
                return bundled.standardizedFileURL
            }
        }

        let sibling = Bundle.main.bundleURL
            .deletingLastPathComponent()
            .appendingPathComponent("insta360-go3s-wifi", isDirectory: true)
        if FileManager.default.fileExists(atPath: sibling.path) {
            return sibling.standardizedFileURL
        }

        throw PythonBridgeError.cliRootNotFound
    }

    func runJSON(arguments: [String]) async throws -> [String: Any] {
        try await withTaskCancellationHandler {
            try await Task.detached(priority: .userInitiated) {
                try self.runProcessSync(arguments: arguments)
            }.value
        } onCancel: {
            self.terminateActiveJSONProcess()
        }
    }

    func cancelJSON() {
        terminateActiveJSONProcess()
    }

    func cancelImport() {
        activeSession?.cancel()
    }

    func runImportStreaming(
        dest: URL,
        newOnly: Bool,
        pathsFile: URL? = nil,
        onLine: @escaping (ImportStreamEvent) -> Void
    ) async throws {
        try await Task.detached(priority: .userInitiated) {
            try self.runImportStreamingSync(
                dest: dest,
                newOnly: newOnly,
                pathsFile: pathsFile,
                onLine: onLine
            )
        }.value
    }

    private func runImportStreamingSync(
        dest: URL,
        newOnly: Bool,
        pathsFile: URL?,
        onLine: @escaping (ImportStreamEvent) -> Void
    ) throws {
        var args = [
            "-m", "insta360_go3s_wifi.cli",
            "ui", "import",
            dest.path,
        ]
        if newOnly {
            args.append("--new-only")
        } else {
            args.append("--all")
        }
        if let pathsFile {
            args.append("--paths-file")
            args.append(pathsFile.path)
        }

        let cancelFlagURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("insta360-cancel-\(UUID().uuidString).flag")
        try? FileManager.default.removeItem(at: cancelFlagURL)

        let process = makeProcess(
            arguments: args,
            extraEnv: ["INSTA360_CANCEL_FILE": cancelFlagURL.path]
        )
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        process.standardInput = FileHandle.nullDevice

        let session = ImportSession(process: process, cancelFlagURL: cancelFlagURL)
        activeSession = session
        defer {
            activeSession = nil
            try? FileManager.default.removeItem(at: cancelFlagURL)
        }

        let stderrHandle = stderrPipe.fileHandleForReading
        stderrHandle.readabilityHandler = { handle in
            _ = handle.availableData
        }

        try process.run()

        let stdoutHandle = stdoutPipe.fileHandleForReading
        var buffer = ""
        while process.isRunning {
            let chunk = String(data: stdoutHandle.availableData, encoding: .utf8) ?? ""
            if chunk.isEmpty {
                Thread.sleep(forTimeInterval: 0.05)
                continue
            }
            buffer += chunk
            while let range = buffer.range(of: "\n") {
                let line = String(buffer[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                buffer = String(buffer[range.upperBound...])
                if !line.isEmpty {
                    try self.parseEventLine(line, onLine: onLine)
                }
            }
        }

        stderrHandle.readabilityHandler = nil
        _ = stderrHandle.readDataToEndOfFile()

        let tail = String(data: stdoutHandle.readDataToEndOfFile(), encoding: .utf8) ?? ""
        if !tail.isEmpty {
            buffer += tail
        }
        if !buffer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            try parseEventLine(buffer, onLine: onLine)
        }

        process.waitUntilExit()

        if session.cancelRequested {
            throw PythonBridgeError.importCancelled
        }
        if process.terminationStatus != 0 {
            let stderrText = String(data: stderrPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let detail = stderrText.isEmpty
                ? L10n.importExitCode(process.terminationStatus)
                : stderrText
            throw PythonBridgeError.commandFailed(detail)
        }
    }

    private func parseEventLine(
        _ line: String,
        onLine: (ImportStreamEvent) -> Void
    ) throws {
        guard let data = line.data(using: .utf8),
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else {
            if line.hasPrefix("{") {
                throw PythonBridgeError.invalidJSON(line)
            }
            return
        }
        onLine(ImportStreamEvent(type: type, payload: json))
    }

    private func runProcessSync(arguments: [String]) throws -> [String: Any] {
        let commandLabel = commandLabel(for: arguments)
        let started = ContinuousClock.now
        AppLogger.log("python_bridge", "run start", extra: ["command": commandLabel])

        terminateActiveJSONProcess()
        let process = makeProcess(arguments: arguments)
        registerJSONProcess(process)
        defer { unregisterJSONProcess(process) }

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        process.standardInput = FileHandle.nullDevice

        let stderrHandle = errorPipe.fileHandleForReading
        stderrHandle.readabilityHandler = { handle in
            _ = handle.availableData
        }

        do {
            try process.run()
            process.waitUntilExit()

            stderrHandle.readabilityHandler = nil
            let output = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            let error = String(data: stderrHandle.readDataToEndOfFile(), encoding: .utf8) ?? ""

            let elapsed = elapsedMs(since: started)
            if process.terminationReason == .uncaughtSignal {
                AppLogger.log(
                    "python_bridge",
                    "run cancelled",
                    durationMs: elapsed,
                    extra: ["command": commandLabel]
                )
                throw CancellationError()
            }
            if process.terminationStatus != 0 {
                let detail = error.isEmpty ? output : error
                AppLogger.log(
                    "python_bridge",
                    "run error",
                    durationMs: elapsed,
                    extra: [
                        "command": commandLabel,
                        "exit_code": process.terminationStatus,
                        "error": detail.trimmingCharacters(in: .whitespacesAndNewlines),
                    ]
                )
                throw PythonBridgeError.commandFailed(detail.trimmingCharacters(in: .whitespacesAndNewlines))
            }
            guard let data = output.data(using: .utf8),
                  let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                AppLogger.log(
                    "python_bridge",
                    "run invalid_json",
                    durationMs: elapsed,
                    extra: ["command": commandLabel]
                )
                throw PythonBridgeError.invalidJSON(String(output.prefix(200)))
            }
            AppLogger.log("python_bridge", "run done", durationMs: elapsed, extra: ["command": commandLabel])
            return json
        } catch let bridgeError as PythonBridgeError {
            throw bridgeError
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            let elapsed = elapsedMs(since: started)
            AppLogger.log(
                "python_bridge",
                "run error",
                durationMs: elapsed,
                extra: ["command": commandLabel, "error": String(describing: error)]
            )
            throw error
        }
    }

    private func commandLabel(for arguments: [String]) -> String {
        guard let uiIndex = arguments.firstIndex(of: "ui"),
              uiIndex + 1 < arguments.count else {
            return arguments.suffix(4).joined(separator: " ")
        }
        let tail = arguments[(uiIndex + 1)...]
        if tail.count >= 2, tail.dropFirst().first?.hasPrefix("-") != true {
            return "\(tail.first ?? "") \(tail.dropFirst().first ?? "")"
        }
        return tail.first ?? arguments.suffix(2).joined(separator: " ")
    }

    private func elapsedMs(since start: ContinuousClock.Instant) -> Double {
        let duration = start.duration(to: ContinuousClock.now)
        return Double(duration.components.seconds) * 1000.0
            + Double(duration.components.attoseconds) / 1_000_000_000_000_000.0
    }

    private func registerJSONProcess(_ process: Process) {
        jsonProcessLock.lock()
        activeJSONProcess = process
        jsonProcessLock.unlock()
    }

    private func unregisterJSONProcess(_ process: Process) {
        jsonProcessLock.lock()
        if activeJSONProcess === process {
            activeJSONProcess = nil
        }
        jsonProcessLock.unlock()
    }

    private func terminateActiveJSONProcess() {
        jsonProcessLock.lock()
        let process = activeJSONProcess
        jsonProcessLock.unlock()
        guard let process, process.isRunning else { return }
        process.terminate()
    }

    private func makeProcess(
        arguments: [String],
        extraEnv: [String: String] = [:]
    ) -> Process {
        let process = Process()
        process.executableURL = pythonExecutable
        process.arguments = arguments
        var env = ProcessInfo.processInfo.environment
        if !pythonPath.isEmpty {
            if let existing = env["PYTHONPATH"], !existing.isEmpty {
                env["PYTHONPATH"] = pythonPath + ":" + existing
            } else {
                env["PYTHONPATH"] = pythonPath
            }
        }
        env["INSTA360_PERF_LOG"] = "1"
        env["INSTA360_PERF_LOG_PATH"] = AppLogger.logURL.path
        env["INSTA360_UI_LANG"] = uiLanguageCode
        for (key, value) in extraEnv {
            env[key] = value
        }
        process.environment = env
        process.currentDirectoryURL = cliRoot
        return process
    }
}
