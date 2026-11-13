import Foundation
import CoreData

/// Playback positions in CoreData. The model is built in code (the app ships no .momd):
/// entity `PlaybackProgress` { key: String, time: Double = 0, updatedAt: Date }, all non-optional,
/// stored at Application Support/PlaybackProgress.sqlite. Keep this exact so existing stores load.
/// improvement: observable, so the page's «Смотреть» button picks up the position the player writes as it closes.
final class PlaybackProgressStore: ObservableObject {
    static let shared = PlaybackProgressStore()
    private let entityName = "PlaybackProgress"
    let container: NSPersistentContainer

    private init() {
        let entity = NSEntityDescription()
        entity.name = entityName
        entity.managedObjectClassName = NSStringFromClass(NSManagedObject.self)

        let key = NSAttributeDescription()
        key.name = "key"
        key.attributeType = .stringAttributeType
        key.isOptional = false

        let time = NSAttributeDescription()
        time.name = "time"
        time.attributeType = .doubleAttributeType
        time.isOptional = false
        time.defaultValue = 0.0

        let updatedAt = NSAttributeDescription()
        updatedAt.name = "updatedAt"
        updatedAt.attributeType = .dateAttributeType
        updatedAt.isOptional = false

        entity.properties = [key, time, updatedAt]
        let model = NSManagedObjectModel()
        model.entities = [entity]
        container = NSPersistentContainer(name: "PlaybackProgress", managedObjectModel: model)

        let storeURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PlaybackProgress.sqlite")
        try? FileManager.default.createDirectory(at: storeURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let description = NSPersistentStoreDescription(url: storeURL)
        description.shouldMigrateStoreAutomatically = true
        description.shouldInferMappingModelAutomatically = true
        container.persistentStoreDescriptions = [description]
        container.loadPersistentStores { _, error in
            if let error {
                print("PlaybackProgressStore load error: \(error)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        migrateAddressKeys()
    }

    /// "<page address>|<translatorId>|<season>|<episode>" -> "<post number>|…" (`String.titleKey`). improvement: a
    /// title's positions are found from every address of it: another mirror, the "-latest" address of «Досмотреть», search
    /// and «Обновления». 1.6.0 keyed them by the address the page was opened with, so they went missing there.
    static func storedKey(_ key: String) -> String {
        guard let bar = key.firstIndex(of: "|") else { return key.titleKey }
        return String(key[..<bar]).titleKey + key[bar...]
    }

    func save(time: Double, forKey key: String) {
        let key = Self.storedKey(key)
        let context = container.viewContext
        let object: NSManagedObject
        if let existing = (try? context.fetch(request(forKey: key)))?.first {
            object = existing
        } else {
            object = NSManagedObject(entity: container.managedObjectModel.entitiesByName[entityName]!, insertInto: context)
            object.setValue(key, forKey: "key")
        }
        object.setValue(time, forKey: "time")
        object.setValue(Date(), forKey: "updatedAt")
        do {
            try context.save()
            // On the next turn of the run loop: the player's last save runs while SwiftUI tears it down, inside a view
            // update, where publishing a change isn't allowed.
            DispatchQueue.main.async { self.objectWillChange.send() }
        } catch {
            print("PlaybackProgressStore save error: \(error)")
        }
    }

    /// improvement: whether any voice acting or episode of the title has a saved position ("<id>|…" keys); the page
    /// then opens on its «Смотреть» half.
    func hasProgress(forTitle id: String) -> Bool {
        let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
        request.predicate = NSPredicate(format: "key BEGINSWITH %@", id.titleKey + "|")
        request.fetchLimit = 1
        return ((try? container.viewContext.count(for: request)) ?? 0) > 0
    }

    /// improvement (critique r1): the newest position saved for the title at this season and episode ("0" and "0" for a
    /// film), in any voice acting; the «Досмотреть» cards name it as «с 23:14».
    func latestTime(forTitle id: String, season: String, episode: String) -> Double? {
        let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
        request.predicate = NSPredicate(format: "key BEGINSWITH %@ AND key ENDSWITH %@", id.titleKey + "|", "|\(season)|\(episode)")
        request.sortDescriptors = [NSSortDescriptor(key: "updatedAt", ascending: false)]
        request.fetchLimit = 1
        return (try? container.viewContext.fetch(request))?.first?.value(forKey: "time") as? Double
    }

    /// improvement: the season and episode of the position saved last since `since` in this voice acting. Autoplay moves
    /// on inside the player; when it closes, the page's choice follows (1.6.0 kept the episode it started with).
    func latestEpisode(forTitle id: String, translatorId: String, since: Date) -> (season: String, episode: String)? {
        let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
        request.predicate = NSPredicate(format: "key BEGINSWITH %@ AND updatedAt >= %@",
                                        id.titleKey + "|" + translatorId + "|", since as NSDate)
        request.sortDescriptors = [NSSortDescriptor(key: "updatedAt", ascending: false)]
        request.fetchLimit = 1
        guard let key = (try? container.viewContext.fetch(request))?.first?.value(forKey: "key") as? String else { return nil }
        let parts = key.split(separator: "|", omittingEmptySubsequences: false)
        guard parts.count == 4 else { return nil }
        return (String(parts[2]), String(parts[3]))
    }

    /// Moves rows saved under a page address (1.6.0 and builds before this one) to `storedKey`; where two addresses of
    /// one episode meet, the newest position stays. A failed save leaves every row as it was.
    func migrateAddressKeys() {
        let context = container.viewContext
        let old = NSFetchRequest<NSManagedObject>(entityName: entityName)
        old.predicate = NSPredicate(format: "key BEGINSWITH %@", "http")
        guard ((try? context.count(for: old)) ?? 0) > 0,
              let rows = try? context.fetch(NSFetchRequest<NSManagedObject>(entityName: entityName)) else { return }
        func key(_ row: NSManagedObject) -> String { row.value(forKey: "key") as? String ?? "" }
        func date(_ row: NSManagedObject) -> Date { row.value(forKey: "updatedAt") as? Date ?? .distantPast }
        for (stored, group) in Dictionary(grouping: rows, by: { Self.storedKey(key($0)) })
        where group.contains(where: { key($0) != stored }) {
            guard let newest = group.max(by: { date($0) < date($1) }) else { continue }
            group.filter { $0 !== newest }.forEach(context.delete)
            newest.setValue(stored, forKey: "key")
        }
        do {
            try context.save()
        } catch {
            context.rollback()
            print("PlaybackProgressStore migration error: \(error)")
        }
    }

    func time(forKey key: String) -> Double? {
        guard let object = (try? container.viewContext.fetch(request(forKey: Self.storedKey(key))))?.first else { return nil }
        return object.value(forKey: "time") as? Double
    }

    private func request(forKey key: String) -> NSFetchRequest<NSManagedObject> {
        let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
        request.predicate = NSPredicate(format: "key == %@", key)
        request.fetchLimit = 1
        return request
    }
}
