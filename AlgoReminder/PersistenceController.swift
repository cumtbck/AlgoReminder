import CoreData
import os.log

struct PersistenceController {
    static let shared = PersistenceController()
    static let logger = Logger(subsystem: "com.algorehearser.app", category: "Persistence")

    static var preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        
        do {
            try viewContext.save()
        } catch {
            Self.logger.error("Failed to save preview context: \(error.localizedDescription)")
        }
        return result
    }()

    let container: NSPersistentCloudKitContainer

    init(inMemory: Bool = false) {
        container = NSPersistentCloudKitContainer(name: "AlgoRehearser")
        
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        } else {
            // Configure persistent store for better performance
            let description = container.persistentStoreDescriptions.first
            description?.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            description?.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        }
        
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                Self.logger.error("Unresolved error \(error), \(error.userInfo)")
                
                // Handle common Core Data errors gracefully
                switch error.code {
                case NSPersistentStoreIncompatibleVersionHashError:
                    Self.logger.warning("Database version mismatch, attempting to recover...")
                    // Handle version migration
                    break
                case NSPersistentStoreOpenError:
                    Self.logger.warning("Database open error, checking permissions...")
                    // Handle permission issues
                    break
                default:
                    // For other errors, we might want to reset the database in development
                    #if DEBUG
                    Self.logger.error("Critical database error in debug mode: \(error.localizedDescription)")
                    #else
                    fatalError("Unresolved error \(error), \(error.userInfo)")
                    #endif
                }
            }
        })
        
        // Configure view context for better performance
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        container.viewContext.undoManager = nil // Better performance for batch operations
        
        // Configure background context for heavy operations
        let backgroundContext = container.newBackgroundContext()
        backgroundContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        backgroundContext.undoManager = nil
    }
    
    func save() {
        saveContext(container.viewContext)
    }
    
    func saveContext(_ context: NSManagedObjectContext) {
        guard context.hasChanges else { return }
        
        do {
            try context.save()
            Self.logger.info("Context saved successfully")
        } catch {
            // 使用统一的错误处理器
            let wrappedError = UnifiedErrorHandler.shared.wrapCoreDataError(error, context: "Core Data Save")
            UnifiedErrorHandler.shared.handle(wrappedError, context: "Saving Core Data context")
            
            // 尝试恢复
            if let nsError = error as NSError? {
                switch nsError.code {
                case NSValidationMultipleErrorsError:
                    Self.logger.warning("Validation errors occurred, attempting to continue...")
                    context.rollback()
                case NSManagedObjectConstraintValidationError:
                    Self.logger.warning("Constraint validation error, rolling back...")
                    context.rollback()
                default:
                    context.rollback()
                }
            }
        }
    }
    
    func performBatchUpdate(_ updateBlock: @escaping (NSManagedObjectContext) -> Void) {
        let backgroundContext = container.newBackgroundContext()
        backgroundContext.perform {
            updateBlock(backgroundContext)
            self.saveContext(backgroundContext)
        }
    }
    
    func clearAllData() {
        let backgroundContext = container.newBackgroundContext()
        backgroundContext.perform {
            let entities = ["Problem", "ReviewPlan", "Note"]
            
            for entityName in entities {
                let fetchRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: entityName)
                let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
                
                do {
                    try backgroundContext.execute(deleteRequest)
                    Self.logger.info("Cleared all data for entity: \(entityName)")
                } catch {
                    Self.logger.error("Failed to clear data for entity \(entityName): \(error.localizedDescription)")
                }
            }
            
            self.saveContext(backgroundContext)
        }
    }
}