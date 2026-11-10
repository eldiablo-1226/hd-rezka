import Foundation
import SwiftUI
import UIKit
import Photos
import UserNotifications

/// Downloads with a default or background URLSession. Metadata lives in
/// Application Support/Downloads/downloads.json (written on `storageQueue`); `.app` files sit next to it,
/// `.gallery` goes to the Photos album "HDrezka", `.files` to Documents (visible in Files).
class DownloadManager: NSObject, ObservableObject, URLSessionDownloadDelegate {
    static let shared = DownloadManager()

    @Published var downloads: [Download] = []
    @AppStorage("background_url_session") private var useBackgroundSession: Bool = true
    private let notification = UNUserNotificationCenter.current()
    private let fileManager = FileManager.default
    private lazy var defaultSession = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
    private lazy var backgroundSession: URLSession = {
        let configuration = URLSessionConfiguration.background(withIdentifier: "\(Bundle.main.bundleIdentifier ?? "me.keet.HDRezka").background")
        configuration.isDiscretionary = false
        configuration.sessionSendsLaunchEvents = true
        return URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }()
    private var tasks: [UUID: URLSessionDownloadTask] = [:]
    private let tasksLock = NSLock()
    private let storageQueue = DispatchQueue(label: "me.keet.HDRezka.downloads.storage")
    private(set) var lastProgressPersist: [UUID: Date] = [:]  // main thread only, like `downloads`

    private override init() {
        super.init()
        let saved = Self.loadMetadata(from: downloadsDirectory().appendingPathComponent("downloads.json"))
        downloads = saved.downloads
        reconcileOnLaunch(save: saved.intact)
    }

    /// The saved downloads, decoded one entry at a time so a bad entry costs only itself. When the file or an
    /// entry cannot be read, the raw file is copied to downloads.json.bak and `intact` is false: launch must
    /// not overwrite it with what was left.
    static func loadMetadata(from url: URL) -> (downloads: [Download], intact: Bool) {
        guard let data = try? Data(contentsOf: url) else { return ([], !FileManager.default.fileExists(atPath: url.path)) }
        let entries = try? JSONDecoder().decode([DecodedEntry].self, from: data)
        let downloads = entries?.compactMap(\.download) ?? []
        if entries?.count == downloads.count { return (downloads, true) }
        try? data.write(to: url.appendingPathExtension("bak"), options: .atomic)
        return (downloads, false)
    }

    /// One array element of downloads.json; nil when it is not a valid `Download`.
    private struct DecodedEntry: Decodable {
        let download: Download?
        init(from decoder: Decoder) throws { download = try? Download(from: decoder) }
    }

    var hasActiveDownloads: Bool {
        downloads.contains { $0.state == .downloading }
    }

    private var session: URLSession { useBackgroundSession ? backgroundSession : defaultSession }

    /// Starts a new download (inlined into callers in the binary; name/labels recovered from closure symbols).
    func download(title: String, subtitle: String, poster: String, quality: String, url: URL, destination: DownloadDestination) {
        requestAuthorization()
        if destination == .gallery, PHPhotoLibrary.authorizationStatus(for: .addOnly) == .notDetermined {
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { _ in }
        }
        let id = UUID()
        let download = Download(id: id, title: title, subtitle: subtitle, poster: poster, quality: quality,
                                sourceURL: url.absoluteString, fileName: id.uuidString + ".mp4", state: .downloading,
                                createdAt: Date(), destination: destination, receivedBytes: 0, totalBytes: 0)
        let task = session.downloadTask(with: url)
        task.taskDescription = download.id.uuidString
        setTask(task, for: download.id)
        DispatchQueue.main.async {
            self.downloads.insert(download, at: 0)
            self.saveMetadata()
        }
        task.resume()
    }

    func requestAuthorization() {
        notification.getNotificationSettings { settings in
            guard settings.authorizationStatus != .authorized, settings.authorizationStatus != .provisional else { return }
            self.notification.requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in }
        }
    }

    func delete(_ download: Download) {
        task(for: download.id)?.cancel()
        setTask(nil, for: download.id)
        try? fileManager.removeItem(at: downloadsDirectory().appendingPathComponent(download.fileName))
        try? fileManager.removeItem(at: resumeDataURL(for: download.id))
        DispatchQueue.main.async {
            self.downloads.removeAll { $0.id == download.id }
            self.saveMetadata()
        }
    }

    func pause(_ download: Download) {
        task(for: download.id)?.cancel(byProducingResumeData: { [weak self] data in
            guard let self else { return }
            if let data {
                try? data.write(to: self.resumeDataURL(for: download.id))
            }
            self.setTask(nil, for: download.id)
            DispatchQueue.main.async { self.setState(.paused, for: download.id) }
        })
    }

    func resume(_ download: Download) {
        let resumeURL = resumeDataURL(for: download.id)
        let task: URLSessionDownloadTask
        if let data = try? Data(contentsOf: resumeURL), !data.isEmpty {
            task = session.downloadTask(withResumeData: data)
            try? fileManager.removeItem(at: resumeURL)
        } else {
            guard let url = URL(string: download.sourceURL) else { return }
            task = session.downloadTask(with: url)
        }
        task.taskDescription = download.id.uuidString
        setTask(task, for: download.id)
        setState(.downloading, for: download.id)
        task.resume()
    }

    func localURL(for download: Download) -> URL? {
        guard download.state == .completed, download.destination == .app else { return nil }
        let url = downloadsDirectory().appendingPathComponent(download.fileName)
        return fileManager.fileExists(atPath: url.path) ? url : nil
    }

    // MARK: - URLSessionDownloadDelegate

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard let id = downloadTask.taskDescription.flatMap(UUID.init(uuidString:)) else { return }
        DispatchQueue.main.async {
            if let index = self.downloads.firstIndex(where: { $0.id == id }) {
                self.downloads[index].receivedBytes = totalBytesWritten
                self.downloads[index].totalBytes = totalBytesExpectedToWrite
            }
            let now = Date()
            if let last = self.lastProgressPersist[id], now.timeIntervalSince(last) < 2 { return }
            self.lastProgressPersist[id] = now
            self.saveMetadata()
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        // `location` is deleted once this returns, so the entry is looked up right now, on main where `downloads` lives.
        guard let id = downloadTask.taskDescription.flatMap(UUID.init(uuidString:)),
              let download = DispatchQueue.main.sync(execute: { downloads.first(where: { $0.id == id }) }) else { return }
        var failure: Error?
        do {
            try persistDownloadedFile(at: location, for: download)
        } catch {
            failure = error
        }
        setTask(nil, for: id)
        DispatchQueue.main.async {
            self.lastProgressPersist[id] = nil
            self.setState(failure == nil ? .completed : .failed, for: id)
        }
        if let failure {
            notificate(String(localized: "Download failed"), id.uuidString,
                       download.displayName + " " + String(localized: "failed to download") + "\n" + failure.localizedDescription)
        } else {
            notificate(String(localized: "Download successfully"), id.uuidString,
                       download.displayName + " " + String(localized: "downloaded"))
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error, let id = task.taskDescription.flatMap(UUID.init(uuidString:)) else { return }
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain, nsError.code == NSURLErrorCancelled {
            // Only a task killed with the app (force quit) keeps its resume data; pause/delete are handled at the call site.
            guard let resumeData = Self.forceQuitResumeData(nsError) else { return }
            try? resumeData.write(to: resumeDataURL(for: id))
            setTask(nil, for: id)
            DispatchQueue.main.async { self.setState(.paused, for: id) }
            return
        }
        setTask(nil, for: id)
        // `downloads` and `lastProgressPersist` are only touched on main.
        DispatchQueue.main.async {
            let name = self.downloads.first(where: { $0.id == id })?.displayName ?? ""
            self.lastProgressPersist[id] = nil
            self.setState(.failed, for: id)
            self.notificate(String(localized: "Download failed"), id.uuidString,
                            name + " " + String(localized: "failed to download") + "\n" + error.localizedDescription)
        }
    }

    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        DispatchQueue.main.async {
            (UIApplication.shared.delegate as? AppDelegate)?.backgroundCompletionHandler?()
        }
    }

    /// Non-empty resume data of a cancelled task, only when the cancel reason is a user force quit (0x1000b5df4).
    static func forceQuitResumeData(_ error: NSError) -> Data? {
        guard let resumeData = error.userInfo[NSURLSessionDownloadTaskResumeData] as? Data, !resumeData.isEmpty,
              let reason = error.userInfo[NSURLErrorBackgroundTaskCancelledReasonKey] as? Int,
              reason == NSURLErrorCancelledReasonUserForceQuitApplication else { return nil }
        return resumeData
    }

    // MARK: - Private

    /// Re-attaches tasks that survived in the background session; downloads that were running
    /// but have no task become paused (resume data on disk) or failed. Saved unless the metadata was damaged.
    private func reconcileOnLaunch(save: Bool) {
        backgroundSession.getAllTasks { [weak self] sessionTasks in
            guard let self else { return }
            var activeIDs = Set<UUID>()
            for case let task as URLSessionDownloadTask in sessionTasks {
                guard let id = task.taskDescription.flatMap(UUID.init(uuidString:)) else { continue }
                self.setTask(task, for: id)
                activeIDs.insert(id)
            }
            DispatchQueue.main.async {
                for index in self.downloads.indices where self.downloads[index].state == .downloading && !activeIDs.contains(self.downloads[index].id) {
                    let hasResumeData = self.fileManager.fileExists(atPath: self.resumeDataURL(for: self.downloads[index].id).path)
                    self.downloads[index].state = hasResumeData ? .paused : .failed
                }
                if save {
                    self.saveMetadata()
                }
            }
        }
    }

    private func task(for id: UUID) -> URLSessionDownloadTask? {
        tasksLock.lock()
        defer { tasksLock.unlock() }
        return tasks[id]
    }

    private func setTask(_ task: URLSessionDownloadTask?, for id: UUID) {
        tasksLock.lock()
        tasks[id] = task
        tasksLock.unlock()
    }

    private func setState(_ state: DownloadState, for id: UUID) {
        guard let index = downloads.firstIndex(where: { $0.id == id }) else { return }
        downloads[index].state = state
        saveMetadata()
    }

    private func notificate(_ title: String, _ identifier: String, _ subtitle: String?) {
        notification.getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }
            let content = UNMutableNotificationContent()
            content.title = title
            if let subtitle, !subtitle.isEmpty {
                content.subtitle = subtitle
            }
            content.sound = .default
            self.notification.add(UNNotificationRequest(identifier: identifier, content: content, trigger: nil), withCompletionHandler: nil)
        }
    }

    private func downloadsDirectory() -> URL {
        let url = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Downloads", isDirectory: true)
        try? fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func resumeDataURL(for id: UUID) -> URL {
        downloadsDirectory().appendingPathComponent(id.uuidString + ".resume")
    }

    private func saveMetadata() {
        let snapshot = downloads
        storageQueue.async {
            guard let data = try? JSONEncoder().encode(snapshot) else { return }
            try? data.write(to: self.downloadsDirectory().appendingPathComponent("downloads.json"), options: .atomic)
        }
    }

    private func persistDownloadedFile(at location: URL, for download: Download) throws {
        switch download.destination {
        case .app:
            let destination = downloadsDirectory().appendingPathComponent(download.fileName)
            try? fileManager.removeItem(at: destination)
            try fileManager.moveItem(at: location, to: destination)
        case .gallery:
            let temporary = fileManager.temporaryDirectory.appendingPathComponent(download.id.uuidString + ".mp4")
            try? fileManager.removeItem(at: temporary)
            try fileManager.moveItem(at: location, to: temporary)
            defer { try? fileManager.removeItem(at: temporary) }
            try saveVideoToAlbum(videoURL: temporary, albumName: "HDrezka")
        case .files:
            let documents = try fileManager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            let destination = documents.appendingPathComponent(suggestedFileName(for: download))
            try? fileManager.removeItem(at: destination)
            try fileManager.moveItem(at: location, to: destination)
        }
    }

    /// "<display name without /\:?%*|"<>> [<quality>].mp4", the UUID when there is no name.
    func suggestedFileName(for download: Download) -> String {
        let base = download.displayName.isEmpty ? download.id.uuidString : download.displayName
        let cleaned = base.components(separatedBy: CharacterSet(charactersIn: "/\\:?%*|\"<>")).joined(separator: " ")
        return cleaned + " [" + download.quality + "].mp4"
    }

    private func fetchAlbum(named name: String) -> PHAssetCollection? {
        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "title = %@", name)
        return PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: options).firstObject
    }

    private func saveVideoToAlbum(videoURL: URL, albumName: String) throws {
        if let album = fetchAlbum(named: albumName) {
            try saveVideo(videoURL: videoURL, to: album)
            return
        }
        var placeholder: PHObjectPlaceholder?
        try PHPhotoLibrary.shared().performChangesAndWait {
            placeholder = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: albumName).placeholderForCreatedAssetCollection
        }
        guard let placeholder,
              let album = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [placeholder.localIdentifier], options: nil).firstObject
        else { return }
        try saveVideo(videoURL: videoURL, to: album)
    }

    private func saveVideo(videoURL: URL, to album: PHAssetCollection) throws {
        try PHPhotoLibrary.shared().performChangesAndWait {
            guard let asset = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: videoURL)?.placeholderForCreatedAsset,
                  let albumRequest = PHAssetCollectionChangeRequest(for: album) else { return }
            albumRequest.addAssets([asset] as NSArray)
        }
    }
}
