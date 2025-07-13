//
//  CoreDataManager.swift
//  MazeBallAR
//
//  Created by Анатолий Александрович on 13.07.2025.
//


import CoreData

class CoreDataManager {
    static let shared = CoreDataManager()
    
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "MazeDataModel")
        container.loadPersistentStores { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }
        return container
    }()
    
    var context: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    func saveContext() {
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nserror = error as NSError
                fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
            }
        }
    }
    
    func fetchOrCreateStarCollection() -> StarCollection {
        let request: NSFetchRequest<StarCollection> = StarCollection.fetchRequest()
        
        do {
            let results = try context.fetch(request)
            if let existing = results.first {
                return existing
            }
        } catch {
            print("Fetch failed: \(error)")
        }
        
        let newCollection = StarCollection(context: context)
        newCollection.totalStars = 0
        saveContext()
        return newCollection
    }
    
    func updateTotalStars(_ count: Int) {
        let collection = fetchOrCreateStarCollection()
        collection.totalStars = Int64(count)
        saveContext()
    }
    
    func getTotalStars() -> Int {
        let collection = fetchOrCreateStarCollection()
        return Int(collection.totalStars)
    }
}
