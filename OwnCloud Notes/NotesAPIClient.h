//
//  NotesAPIClient.h
//  OwnCloud Notes
//
//  Created by Markus Klepp on 26/03/14.
//  Copyright (c) 2014 AyKit. All rights reserved.
//

#import "AFRESTClient.h"
#import "AFIncrementalStore.h"

@interface NotesAPIClient : AFRESTClient <AFIncrementalStoreHTTPClient>

+ (instancetype)sharedClient;

@end
