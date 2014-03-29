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

@end
