import Foundation

enum SidebarSection: String, CaseIterable, Identifiable {
    case camera
    case library

    var id: String { rawValue }

    var title: String {
        switch self {
        case .camera: return L10n.sidebarCamera
        case .library: return L10n.sidebarLibrary
        }
    }

    var icon: String {
        switch self {
        case .camera: return "video.circle"
        case .library: return "folder"
        }
    }

    var subtitle: String {
        switch self {
        case .camera: return L10n.sidebarCameraSubtitle
        case .library: return L10n.sidebarLibrarySubtitle
        }
    }
}

enum CameraImportFilter: String, CaseIterable, Identifiable {
    case all
    case imported
    case notImported

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return L10n.filterAll
        case .imported: return L10n.imported
        case .notImported: return L10n.notImported
        }
    }
}

extension ClipItem {
    var selectionKey: String {
        remotePath ?? localPath ?? id
    }

    func localThumbnailURL(destination: URL) -> URL? {
        if let localPath {
            return URL(fileURLWithPath: localPath)
        }
        if isImported {
            let candidate = destination.appendingPathComponent(name)
            if FileManager.default.isReadableFile(atPath: candidate.path) {
                return candidate
            }
        }
        return nil
    }

    func thumbnailSourceURL(destination: URL) -> URL? {
        localThumbnailURL(destination: destination) ?? remotePreviewURL()
    }

    func canShowThumbnail(destination: URL) -> Bool {
        thumbnailSourceURL(destination: destination) != nil
    }

    var importStatusLabel: String? {
        if isImported { return L10n.imported }
        return nil
    }

    var showsPendingBadge: Bool {
        !isImported && remotePath != nil
    }

    func localPreviewURL(destination: URL) -> URL? {
        if let localPath, FileManager.default.isReadableFile(atPath: localPath) {
            return URL(fileURLWithPath: localPath)
        }
        let candidate = destination.appendingPathComponent(name)
        if FileManager.default.isReadableFile(atPath: candidate.path) {
            return candidate
        }
        return nil
    }

    func remotePreviewURL(host: String = CameraEndpoints.host) -> URL? {
        guard let remotePath else { return nil }
        let normalized = remotePath.hasPrefix("/") ? remotePath : "/\(remotePath)"
        return URL(string: "http://\(host)\(normalized)")
    }
}

struct ClipItem: Identifiable, Hashable {
    let id: String
    let name: String
    let remotePath: String?
    let localPath: String?
    let isImported: Bool
    let capturedAt: Date?
    let byteSize: Int64?

    var displayDate: String {
        guard let capturedAt else { return L10n.unknownDate }
        return ClipItem.dateFormatter.string(from: capturedAt)
    }

    var displaySize: String? {
        guard let byteSize, byteSize > 0 else { return nil }
        return ByteCountFormatter.string(fromByteCount: byteSize, countStyle: .file)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    static func refreshDateFormatterLocale() {
        dateFormatter.locale = L10n.resolvedLocale
    }

    static func fromRemote(
        _ path: String,
        imported: Bool,
        destination: URL? = nil
    ) -> ClipItem {
        let name = (path as NSString).lastPathComponent
        var localPath: String?
        if imported, let destination {
            let candidate = destination.appendingPathComponent(name)
            if FileManager.default.isReadableFile(atPath: candidate.path) {
                localPath = candidate.path
            }
        }
        return ClipItem(
            id: path,
            name: name,
            remotePath: path,
            localPath: localPath,
            isImported: imported,
            capturedAt: parseCaptureDate(from: name),
            byteSize: localFileSize(localPath)
        )
    }

    static func fromLocal(_ path: String, size: Int64? = nil) -> ClipItem {
        let name = (path as NSString).lastPathComponent
        let resolvedSize = size ?? localFileSize(path)
        return ClipItem(
            id: path,
            name: name,
            remotePath: nil,
            localPath: path,
            isImported: true,
            capturedAt: parseCaptureDate(from: name),
            byteSize: resolvedSize
        )
    }

    func thumbnailURL(destination: URL) -> URL? {
        localThumbnailURL(destination: destination)
    }

    private static func localFileSize(_ path: String?) -> Int64? {
        guard let path else { return nil }
        let attrs = try? FileManager.default.attributesOfItem(atPath: path)
        return (attrs?[.size] as? NSNumber)?.int64Value
    }

    static func parseCaptureDate(from filename: String) -> Date? {
        // VID_20260619_201755_00_140.mp4
        let stem = (filename as NSString).deletingPathExtension
        let parts = stem.split(separator: "_")
        guard parts.count >= 3 else { return nil }
        let datePart = String(parts[1])
        let timePart = String(parts[2])
        guard datePart.count == 8, timePart.count == 6 else { return nil }
        let raw = datePart + timePart
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMddHHmmss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.date(from: raw)
    }
}

struct ConnectionInfo: Equatable {
    var ok: Bool = false
    var ssid: String?
    var pingMessage: String = ""
    var looksLikeGo3s: Bool = false
    var wifiOnly: Bool = false

    var showsConnected: Bool { ok }

    var statusTitle: String {
        if ok { return L10n.connected }
        if wifiOnly || looksLikeGo3s { return L10n.wifiOnlyConnected }
        return L10n.notConnected
    }

    var statusColor: ConnectionStatusColor {
        if ok { return .connected }
        if wifiOnly || looksLikeGo3s { return .wifiOnly }
        return .disconnected
    }
}

enum ConnectionStatusColor {
    case connected
    case wifiOnly
    case disconnected
}

enum ImportPhase: Equatable {
    case idle
    case running(fileName: String, written: Int64, total: Int64?)
    case completed(downloaded: Int, skipped: Int)
    case cancelled(downloaded: Int)
    case failed(message: String)
}

struct ImportStreamEvent {
    let type: String
    let payload: [String: Any]

    var fileName: String? {
        payload["name"] as? String
    }

    var written: Int64? {
        if let value = payload["written"] as? Int { return Int64(value) }
        if let value = payload["written"] as? Int64 { return value }
        if let value = payload["written"] as? Double { return Int64(value) }
        return nil
    }

    var total: Int64? {
        if let value = payload["total"] as? Int { return Int64(value) }
        if let value = payload["total"] as? Int64 { return value }
        if let value = payload["total"] as? Double { return Int64(value) }
        return nil
    }
}
