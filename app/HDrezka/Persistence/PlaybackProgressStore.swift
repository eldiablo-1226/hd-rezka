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
    }

    func save(time: Double, forKey key: String) {
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
        request.predicate = NSPredicate(format: "key BEGINSWITH %@", id + "|")
        request.fetchLimit = 1
        return ((try? container.viewContext.count(for: request)) ?? 0) > 0
    }

    func time(forKey key: String) -> Double? {
        guard let object = (try? container.viewContext.fetch(request(forKey: key)))?.first else { return nil }
        return object.value(forKey: "time") as? Double
    }

    private func request(forKey key: String) -> NSFetchRequest<NSManagedObject> {
        let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
        request.predicate = NSPredicate(format: "key == %@", key)
        request.fetchLimit = 1
        return request
    }
}
