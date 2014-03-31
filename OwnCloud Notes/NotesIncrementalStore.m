//
//  NotesIncrementalStore.m
//  OwnCloud Notes
//
//  Created by Markus Klepp on 26/03/14.
//  Copyright (c) 2014 AyKit. All rights reserved.
//

#import "NotesIncrementalStore.h"
#import "NotesAPIClient.h"

@implementation NotesIncrementalStore

+ (void)initialize {
    [NSPersistentStoreCoordinator registerStoreClass:self forStoreType:[self type]];
}

+ (NSString *)type {
    return NSStringFromClass(self);
}

+ (NSManagedObjectModel *)model {
    return [[NSManagedObjectModel alloc] initWithContentsOfURL:[[NSBundle mainBundle] URLForResource:@"OwnCloud_Notes" withExtension:@"xcdatamodeld"]];
}

- (id <AFIncrementalStoreHTTPClient>)HTTPClient {
    return [NotesAPIClient sharedClient];
}

#pragma mark - Callback for fetch Request


-(void) gotFetchRequest:(NSArray*) remoteObjectIds inContext: (NSManagedObjectContext*) context
{
    NSManagedObjectContext* backingContext = context;
    
    //remove local objects not existing on server
    NSSet* storedObjects = [backingContext registeredObjects];
    
    //        NSArray* store[storedObjects valueForKeyPath:@"objectID"];
    
    for (NSManagedObject* storedObject in storedObjects) {
        NSString* resourceIdentifier = AFResourceIdentifierFromReferenceObject([self referenceObjectForObjectID: storedObject.objectID]);
        
        BOOL foundObject = false;
        
        for (NSString* remoteObjectId in remoteObjectIds){
            
            NSString* remoteIdentifier = AFResourceIdentifierFromReferenceObject([self referenceObjectForObjectID:(NSManagedObjectID*)remoteObjectId]);
            
            if ([resourceIdentifier isEqualToString:remoteIdentifier]) {
                foundObject = true;
                break;
            }
        }
        
        if (!foundObject){
            [backingContext deleteObject:storedObject];
        }
    }
    
}

@end
