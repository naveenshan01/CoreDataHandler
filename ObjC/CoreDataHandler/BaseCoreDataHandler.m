//
//  BaseCoreDataHandler.m
//  <>
//
//  Created by Naveen Shan.
//  Copyright (c) 2012. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "BaseCoreDataHandler.h"

#define kManagedObjectContextKey @"NSManagedObjectContextForThreadKey"

@implementation BaseCoreDataHandler

@synthesize managedObjectContext = _managedObjectContext;
@synthesize persistentStoreCoordinator = _persistentStoreCoordinator;

@synthesize modelURL = _modelURL;
@synthesize storeURL = _storeURL;

#pragma mark -

+ (NSManagedObjectContext *)contextForPersistentStoreCoordinator:(NSPersistentStoreCoordinator *)coordinator {
    NSManagedObjectContext *context = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
    [context setPersistentStoreCoordinator:coordinator];
    [context setMergePolicy:NSOverwriteMergePolicy];
    return context;
}

- (void)setManagedObjectContext:(NSManagedObjectContext *)context {
    if (![NSThread isMainThread]) {
        NSLog(@"\n Exception on setManagedObjectContext : setManagedObjectContext works only when calling through mainThread....");
        return;
    }
    _managedObjectContext = nil;
    _managedObjectContext = context;
}

#pragma mark - Private Methods

- (NSString *)defaultDatabaseDirectory {
    NSString *applicationName = [[[NSBundle mainBundle] infoDictionary] valueForKey:(NSString *) kCFBundleNameKey];
    NSString *defaultDatabaseDirectory = [[NSHomeDirectory() stringByAppendingPathComponent:@"Library/Caches/"] stringByAppendingPathComponent:[NSString stringWithFormat:@"%@/Database", applicationName]];

    return defaultDatabaseDirectory;
}

- (void)createIntermediateDirectory {
    NSURL *directoryPath = [self.storeURL URLByDeletingLastPathComponent];
    NSError *error;
    NSArray *array = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:directoryPath includingPropertiesForKeys:nil options:NSDirectoryEnumerationSkipsSubdirectoryDescendants error:&error];
    if (!array) {
        if (![[NSFileManager defaultManager] createDirectoryAtURL:directoryPath withIntermediateDirectories:YES attributes:nil error:&error]) {
            NSLog(@"\n Error Occured While creating Intermediate Directory : %@", [error description]);
        }
    }
}

#pragma mark - 

- (NSManagedObjectModel *)managedObjectModel {
    @try {
        if (managedObjectModel != nil) {
            return managedObjectModel;
        }

        if (!self.modelURL) {
            NSLog(@"\n Exception on managedObjectModel : Data Model Name Not Found....");
            [NSException raise:@"BaseCoreDataHandler" format:@"Data Model Not Found"];
        }

        BOOL isMultitaskingSupported = NO;
        if ([[UIDevice currentDevice] respondsToSelector:@selector(isMultitaskingSupported)]) {
            isMultitaskingSupported = [(id) [UIDevice currentDevice] isMultitaskingSupported];
        }
        if (isMultitaskingSupported) {
            managedObjectModel = isMultitaskingSupported ?
                    [[NSManagedObjectModel alloc] initWithContentsOfURL:self.modelURL] :
                    [NSManagedObjectModel mergedModelFromBundles:nil];
        }

        return managedObjectModel;
    }
    @catch (NSException *exception) {
        NSLog(@"\n Exception on managedObjectModel : %@", [exception description]);
    }
    @finally {

    }

    return nil;
}

- (NSPersistentStoreCoordinator *)persistentStoreCoordinator {
    @try {

        if (persistentStoreCoordinator != nil) {
            return persistentStoreCoordinator;
        }

        if (!self.storeURL) {
            NSString *applicationName = [[[NSBundle mainBundle] infoDictionary] valueForKey:(NSString *) kCFBundleNameKey];
            NSString *dataStoreName = [NSString stringWithFormat:@"%@.sqlite", applicationName];

            self.storeURL = [NSURL fileURLWithPath:[[self defaultDatabaseDirectory] stringByAppendingPathComponent:dataStoreName]];
            NSLog(@"\n Data Store URL Not Found - Set to Default Store URL : %@", self.storeURL);
        }

        [self createIntermediateDirectory];

        NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
                [NSNumber numberWithBool:YES], NSMigratePersistentStoresAutomaticallyOption,
                [NSNumber numberWithBool:YES], NSInferMappingModelAutomaticallyOption, nil];

        NSError *error = nil;
        persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc]
                initWithManagedObjectModel:[self managedObjectModel]];
        if (![persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType
                                                      configuration:nil URL:self.storeURL
                                                            options:options
                                                              error:&error]) {
            NSLog(@"\n Error unresolved error while creating Persistent Store Coordinator \n %@, %@ \n Aborting....", error, [error userInfo]);
            abort();
        }
        else {
            NSLog(@"\n Create a Persistent Store Coordinator Sucessfully.... \n Coordinator : %@", persistentStoreCoordinator);
        }

        return persistentStoreCoordinator;
    }
    @catch (NSException *exception) {
        NSLog(@"\n Exception on persistentStoreCoordinator : %@", [exception description]);
    }
    @finally {

    }

    return nil;
}

#pragma mark - Observers    

- (void)startObserveContext:(NSManagedObjectContext *)context {
    //NSLog(@"Start Observing Context : %@",context);
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(mergeChanges:)
                                                 name:NSManagedObjectContextDidSaveNotification
                                               object:context];
}

- (void)stopObservingContext:(NSManagedObjectContext *)context {
    //NSLog(@"Stop Observing Context : %@",context);
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:NSManagedObjectContextDidSaveNotification
                                                  object:context];
}

#pragma mark - Context

- (NSManagedObjectContext *)managedObjectContextForMain {
    return managedObjectContext;
}

- (NSManagedObjectContext *)managedObjectContext {
    NSManagedObjectContext *context = nil;

    if ([NSThread isMainThread]) {
        if (!_managedObjectContext) {
            NSManagedObjectContext *mainContext = [BaseCoreDataHandler contextForPersistentStoreCoordinator:[self persistentStoreCoordinator]];
            //NSLog(@"\n Create New Context : %@ \n For Main Thread : %@",context,[NSThread currentThread]);
            [self setManagedObjectContext:mainContext];
        }

        context = _managedObjectContext;
    } else {
        //find context for this thread.
        NSMutableDictionary *threadDictionary = [[NSThread currentThread] threadDictionary];
        context = [threadDictionary objectForKey:kManagedObjectContextKey];

        if (!context) {
            //create a new context for this thread.
            context = [BaseCoreDataHandler contextForPersistentStoreCoordinator:[self persistentStoreCoordinator]];
            [context setUndoManager:nil];
            [self startObserveContext:context];
            [threadDictionary setObject:context forKey:kManagedObjectContextKey];

            return [threadDictionary objectForKey:kManagedObjectContextKey];
        }
    }

    return context;
}

#pragma mark -

- (void)mergeChanges:(NSNotification *)notification {
    //merge changes into the main context on the main thread.
    [self performSelectorOnMainThread:@selector(mergeChangesOnMainThread:)
                           withObject:notification
                        waitUntilDone:NO];
}

- (void)mergeChangesOnMainThread:(NSNotification *)notification {
    [self.managedObjectContext mergeChangesFromContextDidSaveNotification:notification];
}

#pragma mark - Interfaces

- (void)refreshObject:(NSManagedObject *)managedObject {
    @try {
        if ([self managedObjectContext]) {
            if (managedObject != nil)
                [[self managedObjectContext] refreshObject:managedObject mergeChanges:NO];
        }
    }
    @catch (NSException *exception) {
        NSLog(@"Exception on refreshObject : %@", [exception description]);
    }
    @finally {

    }
}

- (void)resetContext {
    @try {
        if ([self managedObjectContext]) {
            [[self managedObjectContext] reset];
        }
    }
    @catch (NSException *exception) {
        NSLog(@"Exception on resetContext : %@", [exception description]);
    }
    @finally {

    }
}

// Entity description for given name.
- (id)entityForName:(NSString *)entityName {
    return [NSEntityDescription entityForName:entityName inManagedObjectContext:[self managedObjectContext]];
}

// Create a new entity for given name.
- (id)newEntityForName:(NSString *)entityName {
    return [NSEntityDescription insertNewObjectForEntityForName:entityName
                                         inManagedObjectContext:[self managedObjectContext]];
}

// To Delete a managed object.
- (void)deleteObject:(NSManagedObject *)object {
    [[self managedObjectContext] deleteObject:object];
}

// Save entity.
- (BOOL)saveEntity {
    BOOL success = NO;
    @try {
        NSError *error;
        if ([[self managedObjectContext] hasChanges]) {
            success = [[self managedObjectContext] save:&error];

            if (!success) {
                NSLog(@"Error While Saving Entity : %@", [error description]);
                error = nil;
            }
            else {
                NSLog(@"Entities Saved Successfully....");
            }
        }
    }
    @catch (NSException *exception) {
        NSLog(@"Exception on saveEntity : %@", [exception description]);
    }
    @finally {
        return success;
    }
}


@end
