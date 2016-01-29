//
//  CoreDataHandler.swift
//  
//
//  Created by Naveen Shan.
//  Copyright © 2015. All rights reserved.
//

import CoreData

let kManagedObjectContextKey = "NSManagedObjectContextForThreadKey" as String

public class CoreDataHandler: NSObject {
    private var _managedObjectModel: NSManagedObjectModel?
    private var _persistentStoreCoordinator: NSPersistentStoreCoordinator?
    
    public var modelURL: NSURL?
    public var storeURL: NSURL?
    
    public var mainManagedObjectContext: NSManagedObjectContext?
    
    //MARK: -
    
    var managedObjectModel: NSManagedObjectModel {
        get {
            if self._managedObjectModel != nil {
                return self._managedObjectModel!
            } else {
                if self.modelURL == nil {
                    NSException(name:"CoreDataHandler", reason:"Data Model Not Found", userInfo:nil).raise()
                }
                
                self._managedObjectModel = NSManagedObjectModel(contentsOfURL: self.modelURL!)
                return self._managedObjectModel!
            }
        }
    }

    var persistentStoreCoordinator: NSPersistentStoreCoordinator {
        get {
            if self._persistentStoreCoordinator != nil {
                return self._persistentStoreCoordinator!
            } else {
                if self.storeURL == nil {
                    let applicationName: String = NSBundle.mainBundle().infoDictionary![kCFBundleNameKey as String] as! String
                    let dataStoreName: String = String(format: "%@.sqlite",applicationName)
                    
                    self.storeURL = NSURL(fileURLWithPath: String(format: "%@/%@", self.defaultDatabaseDirectory(),dataStoreName))
                    NSLog("\n Data Store URL Not Found - Set to Default Store URL : %@", self.storeURL!);
                }
                
                self.createIntermediateDirectory();
                
                let options = [NSMigratePersistentStoresAutomaticallyOption: true, NSInferMappingModelAutomaticallyOption: true]
                
                self._persistentStoreCoordinator = NSPersistentStoreCoordinator.init(managedObjectModel: self.managedObjectModel)
                do {
                    try self._persistentStoreCoordinator?.addPersistentStoreWithType(NSSQLiteStoreType, configuration: nil, URL: self.storeURL, options: options)
                }
                catch let error as NSError {
                    NSLog("\n Error unresolved error while creating Persistent Store Coordinator \n \(error.localizedDescription) \n Aborting....");
                    abort();
                }
                NSLog("\n Create a Persistent Store Coordinator Sucessfully.... \n Coordinator : %@", self._persistentStoreCoordinator!);
                
                return self._persistentStoreCoordinator!
            }
        }
    }
    
    //MARK: - Private Methods
    
    func defaultDatabaseDirectory() -> String {
        let applicationName: String = NSBundle.mainBundle().infoDictionary![kCFBundleNameKey as String] as! String
        let defaultDatabaseDirectory = NSHomeDirectory().stringByAppendingString(String(format: "/Library/Caches/%@/Database",applicationName))
        return defaultDatabaseDirectory
    }
    
    func createIntermediateDirectory() {
        var error: NSError?
        if self.storeURL!.checkResourceIsReachableAndReturnError(&error) {
            return
        }
        
        let directoryPath: NSURL = (self.storeURL?.URLByDeletingLastPathComponent)!
        do {
            try NSFileManager.defaultManager().createDirectoryAtURL(directoryPath, withIntermediateDirectories: true, attributes: nil)
        } catch let error as NSError {
            NSLog("\n Error Occured While creating Intermediate Directory\(error.localizedDescription)")
        }
    }

    //MARK: - Observers
    
    func startObserveContext(context: NSManagedObjectContext) {
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "mergeChanges:", name: NSManagedObjectContextDidSaveNotification, object: context)
    }
    
    func stopObservingContext(context: NSManagedObjectContext) {
        NSNotificationCenter.defaultCenter().removeObserver(self, name: NSManagedObjectContextDidSaveNotification, object: context)
    }
    
    //MARK: - Merging
    
    func mergeChanges(notification: NSNotification) {
        self.performSelectorOnMainThread("mergeChangesOnMainThreadContext:", withObject: notification, waitUntilDone: false)
    }
    
    func mergeChangesOnMainThreadContext(notification: NSNotification) {
        self.mainManagedObjectContext?.mergeChangesFromContextDidSaveNotification(notification)
    }
    
    //MARK: - Context
    
    public func managedObjectContext() -> NSManagedObjectContext {
        var context: NSManagedObjectContext?
        
        if NSThread.isMainThread() {
            if mainManagedObjectContext == nil {
                context = CoreDataHandler.contextForPersistentStoreCoordinator(self.persistentStoreCoordinator)
                mainManagedObjectContext = context
            }
            context = mainManagedObjectContext!
        } else {
            let threadDictionary: NSMutableDictionary = NSThread.currentThread().threadDictionary
            context = threadDictionary.objectForKey(kManagedObjectContextKey) as? NSManagedObjectContext
            
            if context == nil {
                context = CoreDataHandler.contextForPersistentStoreCoordinator(self.persistentStoreCoordinator)
                context?.undoManager = nil
                self.startObserveContext(context!)
                threadDictionary.setObject(context!, forKey: kManagedObjectContextKey)
            }
        }
        
        return context!
    }
    
    //MARK: - Class Methods
    
    class func contextForPersistentStoreCoordinator(coordinator: NSPersistentStoreCoordinator) -> NSManagedObjectContext {
        let context: NSManagedObjectContext = NSManagedObjectContext.init(concurrencyType: NSManagedObjectContextConcurrencyType.PrivateQueueConcurrencyType)
        context.mergePolicy = NSOverwriteMergePolicy
        context.persistentStoreCoordinator = coordinator
        return context
    }
    
    //MARK: - Interface Methods
    
    public func resetContext() {
        self.managedObjectContext().reset()
    }
    
    public func rollbackContext() {
        self.managedObjectContext().rollback()
    }
    
    public func refreshObject(managedObject: NSManagedObject) {
        self.managedObjectContext().refreshObject(managedObject, mergeChanges: false)
    }
    
    public func deleteObject(managedObject: NSManagedObject) {
        self.managedObjectContext().deleteObject(managedObject)
    }
    
    public func deleteAllObjects(entityName: String) -> Bool {
        let fetchRequest = NSFetchRequest(entityName: entityName)
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        
        do {
            try self.persistentStoreCoordinator.executeRequest(deleteRequest, withContext:self.managedObjectContext())
            return true
        } catch let error as NSError {
            NSLog("Error While deleteAllObjects Entity : %@", error.description);
            return false
        }
    }
    
    public func saveEntity() -> Bool {
        if self.managedObjectContext().hasChanges {
            do {
                try self.managedObjectContext().save()
            } catch let error as NSError {
                NSLog("Error While Saving Entity : %@", error.description);
                return false
            }
        }
        return true
    }
    
    public func entityForName(entityName: String) -> NSEntityDescription? {
        return NSEntityDescription.entityForName(entityName, inManagedObjectContext: self.managedObjectContext())
    }
    
    public func newEntityForName(entityName: String) -> NSManagedObject {
        return NSEntityDescription.insertNewObjectForEntityForName(entityName, inManagedObjectContext: self.managedObjectContext())
    }
}