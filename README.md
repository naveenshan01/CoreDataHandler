# CoreDataHandler

Helper class for multi threaded CoreData integration. 

One of the major tasks we are facing while integtrating core-data in an app is we need to handle the data changes between multiple NSManagedObjectContext.

Since NSManagedObject is not thread safe, most of the application requires multiple NSManagedObjectContext object, as because of it, its better to create separete NSManagedObjectContext object for each threads.

Hence we must need to merge the changes applied to a NSManagedObject on a specific NSManagedObjectContext to other atleast Main thread NSManagedObjectContext to immediate reflect in the UI.

Here comes the use of this 'CoreDataHandler' class - It take care all of such needs.

CoreDataHandler class is responsible to create NSManagedObjectContext for each thread and merge the changes applied in background thread context to main thread NSManagedObjectContext. It also save the NSManagedObjectContext for thread in its thread dictionary thus way we can ensure the NSManagedObjectContext is deallocated at the end of thread.

CoreDataHandler class also provide some helper methods to create new enity, delete entity, save entity, reset entity, rollback and refresh entity etc.

