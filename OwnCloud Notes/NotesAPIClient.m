//
//  NotesAPIClient.m
//  OwnCloud Notes
//
//  Created by Markus Klepp on 26/03/14.
//  Copyright (c) 2014 AyKit. All rights reserved.
//

#import "NotesAPIClient.h"
#import "KeychainItemWrapper.h"

// see: https://github.com/owncloud/notes/wiki/API-0.2#authentication--basics
static const NSString *serverPath = @"/index.php/apps/notes/api/v0.2/";

@implementation NotesAPIClient

+ (NotesAPIClient *)sharedClient {
    static NotesAPIClient *_sharedClient = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *serverURL = [[NSUserDefaults standardUserDefaults] stringForKey:kNotesServerURL];
        if (serverURL.length > 0) {
            _sharedClient = [[self alloc] initWithBaseURL:[NSURL URLWithString:serverURL]];
        }
    });
    
    return _sharedClient;
}

- (id)initWithBaseURL:(NSURL *)serverURL {
    self = [super initWithBaseURL:[NSURL URLWithString:[NSString stringWithFormat:@"%@%@", serverURL, serverPath]]];
    if (!self) {
        return nil;
    }
    
    BOOL allowInvalid = [[NSUserDefaults standardUserDefaults] boolForKey:kNotesAllowInvalidCertificates];
    self.allowsInvalidSSLCertificate = allowInvalid;
    
    KeychainItemWrapper *keychain = [[KeychainItemWrapper alloc] initWithIdentifier:kNotesKeychainName accessGroup:nil];
    [keychain setObject:(__bridge id)(kSecAttrAccessibleWhenUnlocked) forKey:(__bridge id)(kSecAttrAccessible)];

    [self setAuthorizationHeaderWithUsername:[keychain objectForKey:(__bridge id)(kSecAttrAccount)] password:[keychain objectForKey:(__bridge id)(kSecValueData)]];
    [self registerHTTPOperationClass:[AFJSONRequestOperation class]];
    [self setDefaultHeader:@"Accept" value:@"application/json"];
    
    return self;
}

@end
