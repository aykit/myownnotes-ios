//
//  MasterViewController.m
//  OwnCloud Notes
//
//  Created by Markus Klepp on 22/03/14.
//  Copyright (c) 2014 AyKit. All rights reserved.
//

#import "MasterViewController.h"

#import "SettingsViewController.h"
#import "DetailViewController.h"
#import "AppDelegate.h"
#import "AFNetworking.h"

@interface MasterViewController ()
- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath;


- (void)fetchData;
@end


@implementation MasterViewController

- (void)fetchData
{
    [[NSNotificationCenter defaultCenter] postNotificationName:kNotesShouldUpdateNotification object:self];
}

- (void)awakeFromNib
{
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        self.clearsSelectionOnViewWillAppear = NO;
        self.preferredContentSize = CGSizeMake(320.0, 600.0);
    }
    [super awakeFromNib];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [(AppDelegate*)[[UIApplication sharedApplication] delegate] addObserver:self forKeyPath:@"notes" options:0 context:nil];
    
    self.navigationItem.leftBarButtonItem = self.editButtonItem;
    
    self.refreshControl = [[UIRefreshControl alloc]
                           init];
    [self.refreshControl addTarget:self action:@selector(fetchData) forControlEvents:UIControlEventValueChanged];
    
    [[NSNotificationCenter defaultCenter] addObserverForName:kNotesDidUpdateNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
        [self.refreshControl endRefreshing];
    }];
    
    
    self.detailViewController = (DetailViewController *)[[self.splitViewController.viewControllers lastObject] topViewController];
    
    [self fetchData];
}

- (void) viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        
        NSArray* notesArray = [(AppDelegate*)[[UIApplication sharedApplication] delegate] notes];
        self.detailViewController.detailItem = [notesArray firstObject];
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void) dealloc{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - KVO

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
    NSIndexSet *indices = [change objectForKey:NSKeyValueChangeIndexesKey];
    if (indices == nil)
        return; // Nothing to do
    
    
    // Build index paths from index sets
    NSUInteger indexCount = [indices count];
    NSUInteger buffer[indexCount];
    [indices getIndexes:buffer maxCount:indexCount inIndexRange:nil];
    
    NSMutableArray *indexPathArray = [NSMutableArray array];
    for (int i = 0; i < indexCount; i++) {
        NSUInteger indexPathIndices[2];
        indexPathIndices[0] = 0;
        indexPathIndices[1] = buffer[i];
        NSIndexPath *newPath = [NSIndexPath indexPathWithIndexes:indexPathIndices length:2];
        [indexPathArray addObject:newPath];
    }
    
    NSNumber *kind = [change objectForKey:NSKeyValueChangeKindKey];
    if ([kind integerValue] == NSKeyValueChangeInsertion)  // Rows were added
        [self.tableView insertRowsAtIndexPaths:indexPathArray withRowAnimation:UITableViewRowAnimationFade];
    else if ([kind integerValue] == NSKeyValueChangeRemoval)  // Rows were removed
        [self.tableView deleteRowsAtIndexPaths:indexPathArray withRowAnimation:UITableViewRowAnimationFade];
    
}

#pragma mark - Table View

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [[(AppDelegate*)[[UIApplication sharedApplication] delegate] notes] count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell" forIndexPath:indexPath];
    [self configureCell:cell atIndexPath:indexPath];
    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    return YES;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        
        NSDictionary* note = [[(AppDelegate*)[[UIApplication sharedApplication] delegate] notes] objectAtIndex:indexPath.row];
        NSDictionary *dataDict = [NSDictionary dictionaryWithObject:note
                                                             forKey:kNotesNotificationDeleteItem];
        [[NSNotificationCenter defaultCenter] postNotificationName:kNotesShouldUpdateNotification object:self userInfo:dataDict];
    }
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    return NO;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        NSArray* notesArray = [(AppDelegate*)[[UIApplication sharedApplication] delegate] notes];
        self.detailViewController.detailItem = [notesArray objectAtIndex: indexPath.row];
    }
}

- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath
{
    NSArray* notesArray = [(AppDelegate*)[[UIApplication sharedApplication] delegate] notes];
    NSDictionary* note = [notesArray objectAtIndex:indexPath.row];
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:[note valueForKey:kNotesTitle]
                                                    message:@"This note is not yet synched with the server"
                                                   delegate:nil
                                          cancelButtonTitle:@"OK"
                                          otherButtonTitles:nil];
    [alert show];
}

- (IBAction)createNote:(id)sender
{
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        self.detailViewController.detailItem = nil;
    }
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([[segue identifier] isEqualToString:@"addNote"] ||[[segue identifier] isEqualToString:@"editNote"]) {
        DetailViewController* nextViewController = [segue destinationViewController];
        
        NSDictionary* note = nil;
        
        if ([[segue identifier] isEqualToString:@"editNote"]) {
            NSIndexPath *indexPath = [self.tableView indexPathForSelectedRow];
            
            NSArray* notesArray = [(AppDelegate*)[[UIApplication sharedApplication] delegate] notes];
            note = [notesArray objectAtIndex: indexPath.row];
        }
        
        [nextViewController setDetailItem:note];
    }
}

- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath
{
    NSDateFormatter *dateFormat = [[NSDateFormatter alloc] init];
    [dateFormat setDateStyle:NSDateFormatterShortStyle];
    
    NSArray* notesArray = [(AppDelegate*)[[UIApplication sharedApplication] delegate] notes];
    
    NSDictionary* note = [notesArray objectAtIndex: indexPath.row];
    
    if ([note valueForKey:kNotesTitle]) {
        cell.textLabel.text = [note valueForKey: kNotesTitle];
        [cell.textLabel sizeToFit];
    }
    
    if ([note valueForKey:kNoteIsOffline]) {
        [cell setAccessoryType:UITableViewCellAccessoryDetailDisclosureButton];
    }
    else {
        [cell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
    }
    
    
    NSNumber *unixtimestamp = [note valueForKey:kNotesModified];
    NSDate* date = [NSDate dateWithTimeIntervalSince1970:[unixtimestamp integerValue]];
    cell.detailTextLabel.text = [dateFormat stringFromDate:date];
}

@end
