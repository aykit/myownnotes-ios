//
//  AppDelegate.m
//  OwnCloud Notes
//
//  Created by Markus Klepp on 22/03/14.
//  Copyright (c) 2014 AyKit. All rights reserved.
//

#import "AppDelegate.h"

#import "MasterViewController.h"
#import "AFNetworkActivityIndicatorManager.h"
#import <AFNetworking.h>
#import "KeychainItemWrapper.h"

@interface AppDelegate (){
    
    AFHTTPRequestOperationManager* _httpOperationManager;
}
@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    
    NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults registerDefaults:@{kNotesRemoved: [NSArray array], kNotesEdited: [NSArray array], kNotesAdded: [NSArray array], kNotes: [NSArray array]}];
    [userDefaults synchronize];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(updateData:)
                                                 name:kNotesShouldUpdateNotification
                                               object:nil];
    
    _httpOperationManager = [AFHTTPRequestOperationManager manager];
    
    _httpOperationManager.responseSerializer = [AFJSONResponseSerializer serializer];
    _httpOperationManager.requestSerializer = [AFJSONRequestSerializer serializer];
    
    BOOL isLoggedIn = [[NSUserDefaults standardUserDefaults] stringForKey:kNotesServerURL] != nil;
    
    NSString *storyboardId = isLoggedIn ? @"list" : @"settings";
    
    self.window.rootViewController = [self.window.rootViewController.storyboard instantiateViewControllerWithIdentifier:storyboardId];
    [self.window makeKeyAndVisible];
    
    
    // Override point for customization after application launch.
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        if (isLoggedIn) {
            UISplitViewController *splitViewController = (UISplitViewController *)self.window.rootViewController;
            UINavigationController *navigationController = [splitViewController.viewControllers lastObject];
            splitViewController.delegate = (id)navigationController.topViewController;
        }
        else {
            [[self.window.rootViewController.childViewControllers firstObject] performSegueWithIdentifier:@"settingsSegue" sender:nil];
        }
    }
    
    [[AFNetworkActivityIndicatorManager sharedManager] setEnabled:YES];
    
    _notes = [[NSMutableArray alloc] init];
    
    for (NSDictionary* note in [[NSUserDefaults standardUserDefaults] valueForKey:kNotes]) {
        [self insertNoteSorted:note];
    }
    
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application
{
    [self persistNotes];
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self persistNotes];
}

- (NSDictionary*)noteWithId:(id)noteId
{
    for (NSDictionary* localNote in _notes) {
        NSString* localNoteId = [localNote valueForKey:kNotesId];
        if ([[localNoteId description] isEqualToString:[noteId description]]){
            return localNote;
        }
    }
    
    return nil;
}

- (void) insertNoteSorted:(NSDictionary*) note
{
    NSUInteger newIndex = [_notes indexOfObject:note
                                  inSortedRange:(NSRange){0, [_notes count]}
                                        options:NSBinarySearchingInsertionIndex
                                usingComparator:^(id obj1, id obj2) {
                                    
                                    NSNumber* modifiedObj1 = [obj1 valueForKey:kNotesModified];
                                    NSNumber* modifiedObj2 = [obj2 valueForKey:kNotesModified];
                                    
                                    //order descending
                                    return [modifiedObj2 compare:modifiedObj1];
                                }];
    
    [self insertObject:note inNotesAtIndex:newIndex];
}

- (void)updateData:(NSNotification *)note
{
    NSString* serverUrlString = [NSString stringWithFormat:@"%@%@", [[NSUserDefaults standardUserDefaults] valueForKey:kNotesServerURL], kServerPath];
    
    KeychainItemWrapper *keychain = [[KeychainItemWrapper alloc] initWithIdentifier:kNotes accessGroup:nil];
    [keychain setObject:(__bridge id)(kSecAttrAccessibleWhenUnlocked) forKey:(__bridge id)(kSecAttrAccessible)];
    NSString* username = [keychain objectForKey:(__bridge id)(kSecAttrAccount)];
    NSString* password = [keychain objectForKey:(__bridge id)(kSecValueData)];
    
    [_httpOperationManager.requestSerializer setAuthorizationHeaderFieldWithUsername:username password:password];
    
    NSOperation* lastOperation = nil;
    
    NSArray* cachedCreated = [self chachedNotesForCache:kNotesAdded];
    for (NSDictionary* note in cachedCreated) {
        NSOperation* newOperation = [self createNote:[note valueForKey:kNotesId] onServerWithContent:[note valueForKey:kNotesContent]];
        if (lastOperation) {
            [lastOperation addDependency:newOperation];
        }
        lastOperation = newOperation;
    }
    
    NSArray* cachedEdited = [self chachedNotesForCache:kNotesEdited];
    for (NSDictionary* note in cachedEdited) {
        if (![note valueForKey:kNoteIsNew]) {
            NSOperation* newOperation = [self updateNote:[note valueForKey:kNotesId] onServerWithContent:[note valueForKey:kNotesContent]];
            if (lastOperation) {
                [lastOperation addDependency:newOperation];
            }
            lastOperation = newOperation;
        }
    }
    
    NSArray* cachedDeleted = [self chachedNotesForCache:kNotesRemoved];
    for (NSDictionary* note in cachedDeleted) {
        NSOperation* newOperation = [self deleteNoteFromServer:[note valueForKey:kNotesId]];
        if (lastOperation) {
            [lastOperation addDependency:newOperation];
        }
        lastOperation = newOperation;
    }
    
    NSDictionary *theData = [note userInfo];
    if (theData != nil) {
        
        NSDictionary* deletedNote = [theData valueForKey:kNotesNotificationDeleteItem];
        if (deletedNote){
            
            [self cacheNote:deletedNote in:kNotesRemoved];
            [self removeNotesObject:deletedNote];
            
            NSOperation* newOperation = [self deleteNoteFromServer:[deletedNote valueForKey:kNotesId]];
            if (lastOperation) {
                [lastOperation addDependency:newOperation];
            }
            lastOperation = newOperation;
        }
        
        NSDictionary* note = [theData valueForKey:kNotesNotificationItem];
        if (note) {
            if ([note valueForKey:kNoteIsNew]){
                [self cacheNote:note in:kNotesAdded];
                NSOperation* newOperation = [self createNote:[note valueForKey:kNotesId] onServerWithContent:[note valueForKey:kNotesContent]];
                if (lastOperation) {
                    [lastOperation addDependency:newOperation];
                }
                lastOperation = newOperation;
            }
            else {
                [self cacheNote:note in:kNotesEdited];
                [self removeNotesObject:[self noteWithId:[note valueForKey:kNotesId]]];
                NSOperation* newOperation = [self updateNote:[note valueForKey:kNotesId] onServerWithContent:[note valueForKey:kNotesContent]];
                if (lastOperation) {
                    [lastOperation addDependency:newOperation];
                }
                lastOperation = newOperation;
            }
            
            [self insertNoteSorted:note];
            
        }
    }
    
    
    NSOperation* newOperation = [_httpOperationManager GET:serverUrlString parameters:nil success:^(AFHTTPRequestOperation *operation, id responseObject) {
        NSArray* responseArray = responseObject;
        NSArray* localIds = [_notes valueForKey:kNotesId];
        NSArray* remoteIds = [responseArray valueForKey:kNotesId];
        
        NSMutableArray *deleted = [NSMutableArray arrayWithArray:localIds];
        [deleted removeObjectsInArray:remoteIds];
        
        for (NSString* noteId in deleted) {
            [self removeNotesObject:[self noteWithId:noteId]];
        }
        
        NSMutableArray *inserted = [NSMutableArray arrayWithArray:remoteIds];
        [inserted removeObjectsInArray:localIds];
        
        for (NSDictionary* remoteNote in responseArray) {
            NSDictionary* localNote = [self noteWithId:[remoteNote valueForKey:kNotesId]];
            
            if(!localNote){
                [self insertNoteSorted:remoteNote];
            }
            else {
                NSNumber* remoteModified = [remoteNote valueForKey:kNotesModified];
                NSNumber* localModified = [localNote valueForKey:kNotesModified];
                if (![remoteModified isEqualToNumber:localModified]){
                    [self removeNotesObject:localNote];
                    [self insertNoteSorted:remoteNote];
                }
            }
        }
        
        [[NSNotificationCenter defaultCenter] postNotificationName:kNotesDidUpdateNotification object:self];
        
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        NSLog(@"Error: %@", error);
        [[NSNotificationCenter defaultCenter] postNotificationName:kNotesDidUpdateNotification object:self];
    }];
    
    if (lastOperation) {
        [lastOperation addDependency:newOperation];
    }
}

- (void)persistNotes
{
    NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults setValue:_notes forKey:kNotes];
    [userDefaults synchronize];
}

- (NSDictionary*) fetchNoteWithId:(NSString*) noteId fromCache:(NSString*) cacheConstant
{
    NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
    NSArray* cachedArray = [userDefaults valueForKey:cacheConstant];
    NSArray* filteredArray = [cachedArray filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"id==%@", noteId]];
    return [filteredArray firstObject];
}

- (void) cacheNote:(NSDictionary*) note in:(NSString*) cacheConstant
{
    NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
    NSMutableArray* arr = [NSMutableArray arrayWithArray:[userDefaults valueForKey:cacheConstant]];
    [arr addObject:note];
    [userDefaults setObject:arr forKey:cacheConstant];
    [userDefaults synchronize];
}

- (void) deleteChachedNoteWithId:(NSString*) noteId from:(NSString*) cacheConstant
{
    NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
    NSMutableArray* arr = [NSMutableArray arrayWithArray:[userDefaults valueForKey:cacheConstant]];
    [arr removeObjectsInArray:[arr filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"id==%@", noteId]]];
    [userDefaults setObject:arr forKey:cacheConstant];
    [userDefaults synchronize];
}

- (void) updateOfflineNoteId:(NSString*) localNoteId withId:(NSString*) serverNoteId in:(NSString*) cacheConstant
{
    NSMutableDictionary* localEditedNote = [NSMutableDictionary dictionaryWithDictionary:[self fetchNoteWithId:localNoteId fromCache:kNotesEdited]];
    if (localEditedNote) {
        [localEditedNote setValue:serverNoteId forKey:kNotesId];
        [self cacheNote:localEditedNote in:kNotesEdited];
        [self deleteChachedNoteWithId:localNoteId from:kNotesEdited];
    }

}

- (NSOperation*) deleteNoteFromServer: (NSString*) noteId
{
    NSString* serverUrlString = [NSString stringWithFormat:@"%@%@", [[NSUserDefaults standardUserDefaults] valueForKey:kNotesServerURL], kServerPath];
    
    return [_httpOperationManager DELETE:[NSString stringWithFormat:@"%@/%@", serverUrlString, noteId] parameters:nil
                                 success:^(AFHTTPRequestOperation *operation, id responseObject) {
                                     [self deleteChachedNoteWithId:noteId from:kNotesRemoved];
                                 }
                                 failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                                     NSLog(@"Error: %@", error);
                                 }];
}

- (NSOperation*) updateNote:(NSString*) noteId onServerWithContent: (NSString*) content
{
    NSString* serverUrlString = [NSString stringWithFormat:@"%@%@", [[NSUserDefaults standardUserDefaults] valueForKey:kNotesServerURL], kServerPath];
    
    NSDictionary* onlyContentDict = [NSDictionary dictionaryWithObject:content forKey:kNotesContent];
    return [_httpOperationManager PUT:[NSString stringWithFormat:@"%@/%@", serverUrlString, noteId] parameters:onlyContentDict
                              success:^(AFHTTPRequestOperation *operation, id responseObject) {
                                  [self removeNotesObject:[self noteWithId:[responseObject valueForKey:kNotesId]]];
                                  [self insertNoteSorted:responseObject];
                                  [self deleteChachedNoteWithId:noteId from:kNotesEdited];
                              }
                              failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                                  NSLog(@"Error: %@", error);
                              }];
}

- (NSOperation*) createNote:(NSString*) localNoteId onServerWithContent: (NSString*) content
{
    NSString* serverUrlString = [NSString stringWithFormat:@"%@%@", [[NSUserDefaults standardUserDefaults] valueForKey:kNotesServerURL], kServerPath];
    
    NSDictionary* onlyContentDict = [NSDictionary dictionaryWithObject:content forKey:kNotesContent];
    return [_httpOperationManager POST:serverUrlString parameters:onlyContentDict
                               success:^(AFHTTPRequestOperation *operation, id responseObject) {
                                   
                                   [self insertNoteSorted:responseObject];
                                   [self deleteChachedNoteWithId:localNoteId from:kNotesAdded];
                                   
                                   // if note was created and edited offline, replace offline UUID with server generated id
                                   [self updateOfflineNoteId:localNoteId withId:[(NSDictionary*) responseObject valueForKey:kNotesId] in:kNotesEdited];
                                   // same goes with deleted
                                   [self updateOfflineNoteId:localNoteId withId:[(NSDictionary*) responseObject valueForKey:kNotesId] in:kNotesRemoved];
                               }
                               failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                                   NSLog(@"Error: %@", error);
                               }];
}

- (NSArray*) chachedNotesForCache:(NSString*) cacheConstant
{
    return [[NSUserDefaults standardUserDefaults] valueForKey:cacheConstant];
}

- (NSUInteger)countOfNotes {
    return [self.notes count];
}

- (id)objectInNotesAtIndex:(NSUInteger)index
{
    return [_notes objectAtIndex:index];
}

- (void)insertObject:(NSDictionary *)note inNotesAtIndex:(NSUInteger)index
{
    [self.notes insertObject:note atIndex:index];
    return;
}

- (void) removeNotesObject:(NSDictionary *)note
{
    [self removeObjectFromNotesAtIndex:[_notes indexOfObject:note]];
}

- (void) removeObjectFromNotesAtIndex:(NSUInteger)index
{
    [self.notes removeObjectAtIndex:index];
}

- (void) replaceObjectInNotesAtIndex:(NSUInteger)index withObject:(NSDictionary*)note
{
    [self.notes replaceObjectAtIndex:index withObject:note];
}

#pragma mark - Application's Documents directory

// Returns the URL to the application's Documents directory.
- (NSURL *)applicationDocumentsDirectory
{
    return [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
}

@end
