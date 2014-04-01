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

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(updateData:)
                                                 name:kNotesShouldUpdateNotification
                                               object:nil];
    
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
    
    _notes = [[NSMutableArray alloc]init];
    
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application
{
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
}

- (NSDictionary*)noteWithId:(NSNumber *)noteId
{
    for (NSDictionary* localNote in _notes) {
        NSNumber* localNoteId = [localNote valueForKey:kNotesId];
        if ([localNoteId isEqualToNumber:noteId]){
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
                                    
                                    return [modifiedObj1 compare:modifiedObj2];
                                }];
    
    [self insertObject:note inNotesAtIndex:newIndex];
}

- (void)updateData:(NSNotification *)note
{
    KeychainItemWrapper *keychain = [[KeychainItemWrapper alloc] initWithIdentifier:kNotesKeychainName accessGroup:nil];
    [keychain setObject:(__bridge id)(kSecAttrAccessibleWhenUnlocked) forKey:(__bridge id)(kSecAttrAccessible)];
    NSString* username = [keychain objectForKey:(__bridge id)(kSecAttrAccount)];
    NSString* password = [keychain objectForKey:(__bridge id)(kSecValueData)];
    
    AFHTTPRequestOperationManager *manager = [AFHTTPRequestOperationManager manager];
    
    manager.responseSerializer = [AFJSONResponseSerializer serializer];
    [manager.requestSerializer setAuthorizationHeaderFieldWithUsername:username password:password];
    
    NSDictionary *theData = [note userInfo];
    if (theData != nil) {
        NSDictionary* note = [theData valueForKey:kNotesNotificationItem];
        if ([note valueForKey:kNotesId]){
            //TODO: update existing Item
        }
        else {
            //TOOD: create new Item
        }
    }
    
    
    NSString* serverUrlString = [NSString stringWithFormat:@"%@%@", [[NSUserDefaults standardUserDefaults] valueForKey:kNotesServerURL], kServerPath];
    
    
    [manager GET:serverUrlString parameters:nil success:^(AFHTTPRequestOperation *operation, id responseObject) {
        NSArray* responseArray = responseObject;
        NSArray* localIds = [_notes valueForKey:kNotesId];
        NSArray* remoteIds = [responseArray valueForKey:kNotesId];
        
        NSMutableArray *deleted = [NSMutableArray arrayWithArray:localIds];
        [deleted removeObjectsInArray:remoteIds];
        
        for (NSNumber* noteId in deleted) {
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
        
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        NSLog(@"Error: %@", error);
        
    }];
    
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kNotesDidUpdateNotification object:self];
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
