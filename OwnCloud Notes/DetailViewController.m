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
    // Update the user interface for the detail item.

    if (self.detailItem) {
        
        self.title = self.detailItem.title;
        
        NSDateFormatter *dateFormat = [[NSDateFormatter alloc] init];
        [dateFormat setDateStyle:NSDateFormatterMediumStyle];
        [dateFormat setTimeStyle:NSDateFormatterMediumStyle];
        NSNumber *unixtimestamp = [self.detailItem modified];
        NSDate* date = [NSDate dateWithTimeIntervalSince1970:[unixtimestamp integerValue]];
        self.detailDateLabel.text = [dateFormat stringFromDate:date];
        
        self.detailContentTextField.text = [self.detailItem content];
    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self configureView];
}

- (void) saveAndClose:(id)sender
{
    NSNumber* modifiedDate = [NSNumber numberWithInt:[[NSDate date] timeIntervalSince1970]];
    
    NSString* firstLine = [[self.detailContentTextField.text componentsSeparatedByString: @"\n"] firstObject];
    if (!firstLine) {
        firstLine = @"New Note";
    }
    
    NSString* content = self.detailContentTextField.text;
    if (!content) {
        content = @"New Note";
    }
    
    self.detailItem.title = firstLine;
    self.detailItem.content = content;
    self.detailItem.modified = modifiedDate;
    
//    [self.delegate detailViewController:self didFinishWithSave:YES];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Split view

- (void)splitViewController:(UISplitViewController *)splitController willHideViewController:(UIViewController *)viewController withBarButtonItem:(UIBarButtonItem *)barButtonItem forPopoverController:(UIPopoverController *)popoverController
{
    barButtonItem.title = NSLocalizedString(@"Master", @"Master");
    [self.navigationItem setLeftBarButtonItem:barButtonItem animated:YES];
    self.masterPopoverController = popoverController;
}

- (void)splitViewController:(UISplitViewController *)splitController willShowViewController:(UIViewController *)viewController invalidatingBarButtonItem:(UIBarButtonItem *)barButtonItem
{
    // Called when the view is shown again in the split view, invalidating the button and popover controller.
    [self.navigationItem setLeftBarButtonItem:nil animated:YES];
    self.masterPopoverController = nil;
}

@end
