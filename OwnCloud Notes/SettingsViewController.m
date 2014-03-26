//
//  SettingsViewController.m
//  OwnCloud Notes
//
//  Created by Markus Klepp on 26/03/14.
//  Copyright (c) 2014 AyKit. All rights reserved.
//

#import "SettingsViewController.h"
#import "KeychainItemWrapper.h"
#import "NotesAPIClient.h"

@interface SettingsViewController ()

@end

@implementation SettingsViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.serverTextField.delegate = self;
    self.usernameTextField.delegate = self;
    self.passwordTextField.delegate = self;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    KeychainItemWrapper* keychain = [[KeychainItemWrapper alloc] initWithIdentifier:kNotesKeychainName accessGroup:nil];
    [keychain setObject:(__bridge id)(kSecAttrAccessibleWhenUnlocked) forKey:(__bridge id)(kSecAttrAccessible)];
    
    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    self.serverTextField.text = [prefs stringForKey:kNotesServerURL];
    self.usernameTextField.text = [keychain objectForKey:(__bridge id)(kSecAttrAccount)];
    self.passwordTextField.text = [keychain objectForKey:(__bridge id)(kSecValueData)];
    
    if (![prefs stringForKey:kNotesServerURL]) {
        self.closeButton.enabled = NO;
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)close:(id)sender
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

# pragma mark - TableView Delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 1) {
        [tableView deselectRowAtIndexPath:indexPath animated:true];
        
        //reset application data
        NSManagedObjectContext* context = [(id)[[UIApplication sharedApplication] delegate] managedObjectContext];
        NSFetchRequest * allNotes = [[NSFetchRequest alloc] init];
        [allNotes setEntity:[NSEntityDescription entityForName:kNotesEntityName inManagedObjectContext:context]];
        [allNotes setIncludesPropertyValues:NO]; //only fetch the managedObjectID
        
        NSError * error = nil;
        NSArray * notes = [context executeFetchRequest:allNotes error:&error];
   
        //error handling goes here
        for (NSManagedObject * note in notes) {
            [context deleteObject:note];
        }
        [context save:nil];
        
        NotesAPIClient* client = [[NotesAPIClient alloc] initWithBaseURL:[NSURL URLWithString:self.serverTextField.text]];
        [client setAuthorizationHeaderWithUsername:self.usernameTextField.text password:self.passwordTextField.text];
        
        [client getPath:@"notes" parameters:nil success:^(AFHTTPRequestOperation *operation, id responseObject) {
            self.closeButton.enabled = YES;
            
            KeychainItemWrapper* keychain = [[KeychainItemWrapper alloc] initWithIdentifier:kNotesKeychainName accessGroup:nil];
            [keychain setObject:(__bridge id)(kSecAttrAccessibleWhenUnlocked) forKey:(__bridge id)(kSecAttrAccessible)];
            
            NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
            [prefs setObject:self.serverTextField.text forKey:kNotesServerURL];
            [keychain setObject:self.usernameTextField.text forKey:(__bridge id)(kSecAttrAccount)];
            [keychain setObject:self.passwordTextField.text forKey:(__bridge id)(kSecValueData)];
            [prefs synchronize];
            
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Success!" message:@"Settings successfully stored" delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
            [alert show];
        } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Invalid Credentials!" message:@"Please check your settings" delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
            [alert show];
        }];
    }
}

# pragma mark - TextField Delegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    if ([textField isEqual:self.serverTextField]) {
        [self.usernameTextField becomeFirstResponder];
    }
    if ([textField isEqual:self.usernameTextField]) {
        [self.passwordTextField becomeFirstResponder];
    }
    if ([textField isEqual:self.passwordTextField]) {
        [textField resignFirstResponder];
    }
    return YES;
}
@end
