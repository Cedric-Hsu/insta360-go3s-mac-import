import AVFoundation
import AppKit
import CryptoKit
import SwiftUI

struct VideoThumbnail: Equatable {
    let cgImage: CGImage
    let displayWidth: CGFloat
    let durationSeconds: Double?

    var scale: CGFloat {
        max(1, CGFloat(cgImage.width) / displayWidth)
    }
}

private final class CGImageBox: NSObject {
    let image: CGImage
    init(_ image: CGImage) { self.image = image }
}

struct ThumbnailResult: Equatable {
    let thumbnail: VideoThumbnail
    let cacheKey: String
}

/// Generates thumbnails lazily with disk + memory cache and limited concurrency.
actor ThumbnailService {
    static let shared = ThumbnailService()

    private static let targetPixelWidth: CGFloat = 320
    private static let targetPixelHeight: CGFloat = 180
    static let displayWidth: CGFloat = 148
    private static let maxConcurrent = 2
    private static let remoteMaxConcurrent = 1

    private let memoryCache = NSCache<NSString, CGImageBox>()
    private let durationCache = NSCache<NSString, NSNumber>()
    private var inFlight = 0
    private var remoteInFlight = 0

    init() {
        memoryCache.countLimit = 160
        memoryCache.totalCostLimit = 64 * 1024 * 1024
        durationCache.countLimit = 300
    }

    func thumbnail(for url: URL, cacheRoot: URL, remoteCacheKey: String? = nil) async -> ThumbnailResult? {
        let key = cacheKey(for: url, remoteCacheKey: remoteCacheKey)
        if let cached = memoryCache.object(forKey: key as NSString) {
            let duration = durationCache.object(forKey: key as NSString)?.doubleValue
            return ThumbnailResult(
                thumbnail: VideoThumbnail(
                    cgImage: cached.image,
                    displayWidth: Self.displayWidth,
                    durationSeconds: duration
                ),
                cacheKey: key
            )
        }

        let diskURL = diskCacheURL(forKey: key, cacheRoot: cacheRoot)
        if let diskImage = loadDiskCache(diskURL) {
            let duration = loadDurationSidecar(for: diskURL)
            storeMemory(diskImage, key: key, duration: duration)
            return ThumbnailResult(
                thumbnail: VideoThumbnail(
                    cgImage: diskImage,
                    displayWidth: Self.displayWidth,
                    durationSeconds: duration
                ),
                cacheKey: key
            )
        }

        let isRemote = isRemoteURL(url)
        await acquireSlot(remote: isRemote)
        defer { releaseSlot(remote: isRemote) }

        if let cached = memoryCache.object(forKey: key as NSString) {
            let duration = durationCache.object(forKey: key as NSString)?.doubleValue
            return ThumbnailResult(
                thumbnail: VideoThumbnail(
                    cgImage: cached.image,
                    displayWidth: Self.displayWidth,
                    durationSeconds: duration
                ),
                cacheKey: key
            )
        }

        if !isRemote, !FileManager.default.isReadableFile(atPath: url.path) {
            return nil
        }

        guard let extracted = await extractFrame(from: url) else {
            return nil
        }

        storeMemory(extracted.image, key: key, duration: extracted.duration)
        writeDiskCache(extracted.image, to: diskURL)
        writeDurationSidecar(extracted.duration, for: diskURL)
        return ThumbnailResult(
            thumbnail: VideoThumbnail(
                cgImage: extracted.image,
                displayWidth: Self.displayWidth,
                durationSeconds: extracted.duration
            ),
            cacheKey: key
        )
    }

    func invalidate(path: String) {
        memoryCache.removeObject(forKey: cacheKey(for: URL(fileURLWithPath: path), remoteCacheKey: nil) as NSString)
    }

    func invalidateRemote(remotePath: String) {
        let key = "remote|\(remotePath)"
        memoryCache.removeObject(forKey: key as NSString)
        durationCache.removeObject(forKey: key as NSString)
    }

    private func isRemoteURL(_ url: URL) -> Bool {
        let scheme = url.scheme?.lowercased() ?? ""
        return scheme == "http" || scheme == "https"
    }

    private func acquireSlot(remote: Bool) async {
        let limit = remote ? Self.remoteMaxConcurrent : Self.maxConcurrent
        let check: () -> Int = remote ? { self.remoteInFlight } : { self.inFlight }
        let inc: () -> Void = remote ? { self.remoteInFlight += 1 } : { self.inFlight += 1 }
        while check() >= limit {
            try? await Task.sleep(nanoseconds: 25_000_000)
        }
        inc()
    }

    private func releaseSlot(remote: Bool) {
        if remote {
            remoteInFlight = max(0, remoteInFlight - 1)
        } else {
            inFlight = max(0, inFlight - 1)
        }
    }

    private struct ExtractedFrame {
        let image: CGImage
        let duration: Double?
    }

    private func extractFrame(from url: URL) async -> ExtractedFrame? {
        let asset = AVURLAsset(url: url)
        let duration = await loadDuration(for: asset)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(
            width: Self.targetPixelWidth,
            height: Self.targetPixelHeight
        )
        generator.requestedTimeToleranceBefore = CMTime(seconds: 0.12, preferredTimescale: 600)
        generator.requestedTimeToleranceAfter = CMTime(seconds: 0.12, preferredTimescale: 600)

        let seconds = sampleSecond(duration: duration)
        let time = CMTime(seconds: seconds, preferredTimescale: 600)
        guard let image = try? generator.copyCGImage(at: time, actualTime: nil) else {
            return nil
        }
        return ExtractedFrame(image: image, duration: duration)
    }

    private func loadDuration(for asset: AVURLAsset) async -> Double? {
        guard let loaded = try? await asset.load(.duration) else { return nil }
        let seconds = CMTimeGetSeconds(loaded)
        return seconds.isFinite && seconds > 0 ? seconds : nil
    }

    private func sampleSecond(duration: Double?) -> Double {
        guard let duration, duration > 1 else { return 1.0 }
        return min(max(duration * 0.08, 1.0), duration - 0.2)
    }

    private func cacheKey(for url: URL, remoteCacheKey: String?) -> String {
        if let remoteCacheKey {
            return "remote|\(remoteCacheKey)"
        }
        let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
        let mtime = values?.contentModificationDate?.timeIntervalSince1970 ?? 0
        let size = values?.fileSize ?? 0
        return "\(url.path)|\(mtime)|\(size)"
    }

    private func diskCacheURL(forKey key: String, cacheRoot: URL) -> URL {
        let digest = SHA256.hash(data: Data(key.utf8))
        let name = digest.prefix(12).map { String(format: "%02x", $0) }.joined()
        return cacheRoot
            .appendingPathComponent(".insta360-go3s-wifi/thumbs", isDirectory: true)
            .appendingPathComponent("\(name).jpg")
    }

    private func durationSidecarURL(for imageURL: URL) -> URL {
        imageURL.deletingPathExtension().appendingPathExtension("dur")
    }

    private func loadDiskCache(_ url: URL) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            return nil
        }
        return image
    }

    private func loadDurationSidecar(for imageURL: URL) -> Double? {
        let url = durationSidecarURL(for: imageURL)
        guard let text = try? String(contentsOf: url, encoding: .utf8),
              let value = Double(text.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return nil
        }
        return value
    }

    private func writeDiskCache(_ image: CGImage, to url: URL) {
        let dir = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        guard let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.jpeg" as CFString, 1, nil) else {
            return
        }
        let props = [kCGImageDestinationLossyCompressionQuality: 0.82] as CFDictionary
        CGImageDestinationAddImage(dest, image, props)
        CGImageDestinationFinalize(dest)
    }

    private func writeDurationSidecar(_ duration: Double?, for imageURL: URL) {
        guard let duration else { return }
        let url = durationSidecarURL(for: imageURL)
        try? String(duration).write(to: url, atomically: true, encoding: .utf8)
    }

    private func storeMemory(_ image: CGImage, key: String, duration: Double?) {
        let cost = image.width * image.height * 4
        memoryCache.setObject(CGImageBox(image), forKey: key as NSString, cost: cost)
        if let duration {
            durationCache.setObject(NSNumber(value: duration), forKey: key as NSString)
        }
    }
}

@MainActor
final class ThumbnailLoader: ObservableObject {
    @Published private(set) var images: [String: VideoThumbnail] = [:]
    @Published private(set) var remoteThumbnailProgress: (done: Int, total: Int)?
    private var loadingKeys = Set<String>()
    private var remoteQueue: [RemoteThumbnailJob] = []
    private var remoteBatchTask: Task<Void, Never>?
    private var queuedRemoteKeys = Set<String>()
    private var thumbnailDestination: URL?

    private static let remoteBatchSize = 4
    private static let remoteBatchDelayNs: UInt64 = 250_000_000

    private struct RemoteThumbnailJob: Hashable {
        let clipKey: String
        let remotePath: String
        let url: URL
    }

    func load(for clip: ClipItem, destination: URL) {
        let clipKey = clip.selectionKey
        if images[clipKey] != nil || loadingKeys.contains(clipKey) { return }

        if let localURL = clip.localThumbnailURL(destination: destination) {
            loadingKeys.insert(clipKey)
            Task(priority: .utility) {
                let result = await ThumbnailService.shared.thumbnail(for: localURL, cacheRoot: destination)
                await MainActor.run {
                    if let result {
                        images[clipKey] = result.thumbnail
                    }
                    loadingKeys.remove(clipKey)
                }
            }
            return
        }

        if let remoteURL = clip.remotePreviewURL(), let remotePath = clip.remotePath {
            enqueueRemote(clipKey: clipKey, remotePath: remotePath, url: remoteURL)
        }
    }

    func scheduleRemoteBatch(for clips: [ClipItem], destination: URL) {
        thumbnailDestination = destination
        for clip in clips where !clip.isImported && clip.remotePath != nil {
            guard let remoteURL = clip.remotePreviewURL(), let remotePath = clip.remotePath else { continue }
            enqueueRemote(clipKey: clip.selectionKey, remotePath: remotePath, url: remoteURL)
        }
        startRemoteBatchIfNeeded()
    }

    func thumbnail(for clip: ClipItem, destination: URL) -> VideoThumbnail? {
        images[clip.selectionKey]
    }

    func duration(for clip: ClipItem) -> Double? {
        images[clip.selectionKey]?.durationSeconds
    }

    func invalidate(path: String) {
        Task { await ThumbnailService.shared.invalidate(path: path) }
        let name = (path as NSString).lastPathComponent
        images = images.filter { key, _ in
            !(key == path || key.hasSuffix(name) || key.contains(name))
        }
    }

    private func enqueueRemote(clipKey: String, remotePath: String, url: URL) {
        guard images[clipKey] == nil,
              !loadingKeys.contains(clipKey),
              !queuedRemoteKeys.contains(clipKey) else { return }
        let job = RemoteThumbnailJob(clipKey: clipKey, remotePath: remotePath, url: url)
        remoteQueue.append(job)
        queuedRemoteKeys.insert(clipKey)
        startRemoteBatchIfNeeded()
    }

    private func startRemoteBatchIfNeeded() {
        guard remoteBatchTask == nil, !remoteQueue.isEmpty else { return }
        remoteBatchTask = Task(priority: .utility) {
            await processRemoteQueue()
            await MainActor.run {
                remoteBatchTask = nil
                remoteThumbnailProgress = nil
                if !remoteQueue.isEmpty {
                    startRemoteBatchIfNeeded()
                }
            }
        }
    }

    private func processRemoteQueue() async {
        guard let destination = await MainActor.run(body: { thumbnailDestination }) else { return }
        var done = 0
        let initialTotal = await MainActor.run { remoteQueue.count }

        while true {
            let batch: [RemoteThumbnailJob] = await MainActor.run {
                guard !remoteQueue.isEmpty else { return [] }
                let count = min(Self.remoteBatchSize, remoteQueue.count)
                let slice = Array(remoteQueue.prefix(count))
                remoteQueue.removeFirst(count)
                remoteThumbnailProgress = (done: done, total: max(initialTotal, done + remoteQueue.count))
                for job in slice {
                    loadingKeys.insert(job.clipKey)
                }
                return slice
            }
            if batch.isEmpty { break }

            for job in batch {
                let result = await ThumbnailService.shared.thumbnail(
                    for: job.url,
                    cacheRoot: destination,
                    remoteCacheKey: job.remotePath
                )
                await MainActor.run {
                    if let result {
                        images[job.clipKey] = result.thumbnail
                    }
                    loadingKeys.remove(job.clipKey)
                    queuedRemoteKeys.remove(job.clipKey)
                    done += 1
                    remoteThumbnailProgress = (done: done, total: max(initialTotal, done + remoteQueue.count))
                }
            }

            let hasMore = await MainActor.run { !remoteQueue.isEmpty }
            if hasMore {
                try? await Task.sleep(nanoseconds: Self.remoteBatchDelayNs)
            }
        }
    }
}

struct CrispThumbnailImage: View {
    let thumbnail: VideoThumbnail

    var body: some View {
        Image(
            decorative: thumbnail.cgImage,
            scale: thumbnail.scale,
            orientation: .up
        )
        .resizable()
        .interpolation(.high)
        .aspectRatio(contentMode: .fill)
    }
}
