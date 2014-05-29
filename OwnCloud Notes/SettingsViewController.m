//
//  SettingsViewController.m
//  OwnCloud Notes
//
//  Created by Markus Klepp on 26/03/14.
//  Copyright (c) 2014 AyKit. All rights reserved.
//

#import "SettingsViewController.h"
#import "KeychainItemWrapper.h"
#import "AppDelegate.h"
#import <AFNetworking.h>

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
    
    KeychainItemWrapper* keychain = [[KeychainItemWrapper alloc] initWithIdentifier:kNotes accessGroup:nil];
    [keychain setObject:(__bridge id)(kSecAttrAccessibleWhenUnlocked) forKey:(__bridge id)(kSecAttrAccessible)];
    
    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    self.serverTextField.text = [prefs stringForKey:kNotesServerURL];
    self.usernameTextField.text = [keychain objectForKey:(__bridge id)(kSecAttrAccount)];
    self.passwordTextField.text = [keychain objectForKey:(__bridge id)(kSecValueData)];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)close:(id)sender
{
    if (self.serverTextField.text.length == 0){
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Error", @"Error") message:NSLocalizedString(@"Please enter a server name",@"Setup message") delegate:self cancelButtonTitle:NSLocalizedString(@"OK", @"OK") otherButtonTitles:nil];
        [alert show];
    }
    else {
        // reset local cache and settings
        NSDictionary *defaultsDictionary = [[NSUserDefaults standardUserDefaults] dictionaryRepresentation];
        for (NSString *key in [defaultsDictionary allKeys]) {
            [[NSUserDefaults standardUserDefaults] removeObjectForKey:key];
        }
        [[NSUserDefaults standardUserDefaults] synchronize];
        
        NSString* serverUrlString = [NSString stringWithFormat:@"%@%@", self.serverTextField.text, kServerPath];
        
        AFHTTPRequestOperationManager *manager = [AFHTTPRequestOperationManager manager];
        manager.responseSerializer = [AFJSONResponseSerializer serializer];
        [manager.requestSerializer setAuthorizationHeaderFieldWithUsername:self.usernameTextField.text password:self.passwordTextField.text];
        [manager GET:serverUrlString parameters:nil success:^(AFHTTPRequestOperation *operation, id responseObject) {
            
            KeychainItemWrapper* keychain = [[KeychainItemWrapper alloc] initWithIdentifier:kNotes accessGroup:nil];
            [keychain setObject:(__bridge id)(kSecAttrAccessibleWhenUnlocked) forKey:(__bridge id)(kSecAttrAccessible)];
            
            NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
            [prefs setObject:self.serverTextField.text forKey:kNotesServerURL];
            [keychain setObject:self.usernameTextField.text forKey:(__bridge id)(kSecAttrAccount)];
            [keychain setObject:self.passwordTextField.text forKey:(__bridge id)(kSecValueData)];
            [prefs synchronize];
            
            UIStoryboard *storyboard = self.storyboard;
            UIViewController* listRootVC = [storyboard instantiateViewControllerWithIdentifier:@"list"];
            
            if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
                UISplitViewController *splitViewController = (UISplitViewController *)listRootVC;
                UINavigationController *navigationController = [splitViewController.viewControllers lastObject];
                splitViewController.delegate = (id)navigationController.topViewController;
                
                AppDelegate *app = (AppDelegate *)[[UIApplication sharedApplication] delegate];
                
                UIViewController *currentController = app.window.rootViewController;
                app.window.rootViewController = splitViewController;
                app.window.rootViewController = currentController;
                
                [UIView transitionWithView:self.navigationController.view.window
                                  duration:0.75
                                   options:UIViewAnimationOptionTransitionFlipFromRight
                                animations:^{
                                    app.window.rootViewController = splitViewController;
                                }
                                completion:nil];
            }
            else {
                [self presentViewController:listRootVC animated:YES completion:nil];
            }
        } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Error", @"Error") message:NSLocalizedString(@"Check connection and settings", @"Setup error message") delegate:self cancelButtonTitle:NSLocalizedString(@"OK", @"OK") otherButtonTitles:NSLocalizedString(@"Link to guideline", @"Unsigned Cert info"), nil];

            [alert show];
        }];
        
    }
}

# pragma mark - AlertView Delegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    switch (buttonIndex) {
        case 1:
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"http://aykit.org/sites/myownnotes.html"]];
            break;
            
        default:
            break;
    }
}

# pragma mark - TableView Delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 2) {
        [tableView deselectRowAtIndexPath:indexPath animated:true];
        
        [self close:nil];
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
