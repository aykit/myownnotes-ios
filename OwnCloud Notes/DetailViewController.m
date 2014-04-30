//
//  DetailViewController.m
//  OwnCloud Notes
//
//  Created by Markus Klepp on 22/03/14.
//  Copyright (c) 2014 AyKit. All rights reserved.
//

#import "DetailViewController.h"

@interface DetailViewController ()
@property (strong, nonatomic) UIPopoverController *masterPopoverController;
- (void)configureView;
@end

@implementation DetailViewController

#pragma mark - Managing the detail item

- (void)setDetailItem:(id)newDetailItem
{
    if (_detailItem != newDetailItem) {
        _detailItem = newDetailItem;
        
        // Update the view.
        [self configureView];
    }
    
    if (self.masterPopoverController != nil) {
        [self.masterPopoverController dismissPopoverAnimated:YES];
    }
}

- (void)configureView
{
    NSDateFormatter *dateFormat = [[NSDateFormatter alloc] init];
    [dateFormat setDateStyle:NSDateFormatterMediumStyle];
    [dateFormat setTimeStyle:NSDateFormatterMediumStyle];
    
    if (self.detailItem) {
        
        self.title = [self.detailItem valueForKey:kNotesTitle];
        
        
        NSNumber *unixtimestamp = [self.detailItem valueForKey:kNotesModified];
        NSDate* date = [NSDate dateWithTimeIntervalSince1970:[unixtimestamp integerValue]];
        self.detailDateLabel.text = [dateFormat stringFromDate:date];
        
        self.detailContentTextView.text = [self.detailItem valueForKey:kNotesContent];
        
        if ([self.detailItem valueForKey:kNoteIsOffline]){
            self.offlineInfoButton.hidden = false;
        }
    }
    else {
        self.title = @"New Note";
        
        self.detailDateLabel.text = [dateFormat stringFromDate:[NSDate date]];
        self.detailContentTextView.text = @"";
    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    
    [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(keyboardWasShown:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(keyboardWillBeHidden:) name:UIKeyboardWillHideNotification object:nil];
    
    [self configureView];
}

- (void)keyboardWasShown:(NSNotification*)aNotification
{
    NSDictionary* info = [aNotification userInfo];
    CGSize kbSize = [[info objectForKey:UIKeyboardFrameBeginUserInfoKey] CGRectValue].size;
    
    float keyboardHeight = kbSize.width;
    
    if ([UIApplication sharedApplication].statusBarOrientation == UIInterfaceOrientationPortrait ||
        [UIApplication sharedApplication].statusBarOrientation == UIInterfaceOrientationPortraitUpsideDown)
    {
        keyboardHeight = kbSize.height;
    }
    
    UIEdgeInsets contentInsets = UIEdgeInsetsMake(0.0, 0.0, keyboardHeight, 0.0);
    self.detailContentTextView.contentInset = contentInsets;
    self.detailContentTextView.scrollIndicatorInsets = contentInsets;
}

- (void)keyboardWillBeHidden:(NSNotification*)aNotification
{
    UIEdgeInsets contentInsets = UIEdgeInsetsZero;
    self.detailContentTextView.contentInset = contentInsets;
    self.detailContentTextView.scrollIndicatorInsets = contentInsets;
}

- (void) saveAndClose:(id)sender
{
    NSNumber* modifiedDate = [NSNumber numberWithInt:[[NSDate date] timeIntervalSince1970]];
    
    NSString* firstLine = [[self.detailContentTextView.text componentsSeparatedByString: @"\n"] firstObject];
    if (!firstLine) {
        firstLine = NSLocalizedString(@"New Note", @"Default Title");
    }
    
    NSString* content = self.detailContentTextView.text;
    if (!content) {
        content = @"";
    }
    
    if ([[content stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceAndNewlineCharacterSet]] isEqualToString:@""]) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"No Content", @"No Content warning") message:@"" delegate:self cancelButtonTitle:NSLocalizedString(@"OK", @"OK") otherButtonTitles:nil];
        [alert show];
    }
    else {
        
        NSString* noteId = nil;
        
        NSMutableDictionary* note = [NSMutableDictionary dictionary];
        
        if (self.detailItem) {
            noteId = [self.detailItem valueForKey:kNotesId];
        }
        else {
            noteId = [[NSUUID UUID] UUIDString];
            [note setValue:@YES forKey:kNoteIsNew];
        }
        
        [note setValue:@YES forKey:kNoteIsOffline];
        [note setValue:noteId forKey:kNotesId];
        [note setValue:firstLine forKey:kNotesTitle];
        [note setValue:content forKey:kNotesContent];
        [note setValue:modifiedDate forKey:kNotesModified];
        
        NSDictionary *dataDict = [NSDictionary dictionaryWithObject:note
                                                             forKey:kNotesNotificationItem];
        [[NSNotificationCenter defaultCenter] postNotificationName:kNotesShouldUpdateNotification object:self userInfo:dataDict];
        
        
        // Dismiss the modal view to return to the main list
        [self.navigationController popViewControllerAnimated:YES];
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Split view

- (void)splitViewController:(UISplitViewController *)splitController willHideViewController:(UIViewController *)viewController withBarButtonItem:(UIBarButtonItem *)barButtonItem forPopoverController:(UIPopoverController *)popoverController
{
    barButtonItem.title = NSLocalizedString(@"Notes", @"Notes");
    [self.navigationItem setLeftBarButtonItem:barButtonItem animated:YES];
    self.masterPopoverController = popoverController;
}

- (void)splitViewController:(UISplitViewController *)splitController willShowViewController:(UIViewController *)viewController invalidatingBarButtonItem:(UIBarButtonItem *)barButtonItem
{
    // Called when the view is shown again in the split view, invalidating the button and popover controller.
    [self.navigationItem setLeftBarButtonItem:nil animated:YES];
    self.masterPopoverController = nil;
}

-(IBAction)showOfflineMessage:(id)sender
{
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Offline", @"Offline title")
                                                    message:NSLocalizedString(@"This note is not yet synched with the server", @"Offline Message")
                                                   delegate:nil
                                          cancelButtonTitle:NSLocalizedString(@"OK",@"OK")
                                          otherButtonTitles:nil];
    [alert show];
}
@end
