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
#import "Note.h"

@interface MasterViewController () <NSFetchedResultsControllerDelegate> {
    NSFetchedResultsController *_fetchedResultsController;
}
- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath;


- (void)refetchData;
@end


@implementation MasterViewController

- (void)refetchData {
    _fetchedResultsController.fetchRequest.resultType = NSManagedObjectResultType;
    [_fetchedResultsController performFetch:nil];
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
    
    NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:kNotesEntityName];
    // Set the batch size to a suitable number.
    [fetchRequest setFetchBatchSize:20];
    
    // Edit the sort key as appropriate.
    NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"modified" ascending:NO];
    NSArray *sortDescriptors = @[sortDescriptor];
    
    [fetchRequest setSortDescriptors:sortDescriptors];
    fetchRequest.returnsObjectsAsFaults = NO;
    
    _fetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest managedObjectContext:[(id)[[UIApplication sharedApplication] delegate] managedObjectContext] sectionNameKeyPath:nil cacheName:nil];
    _fetchedResultsController.delegate = self;
    [_fetchedResultsController performFetch:nil];

    self.detailViewController = (DetailViewController *)[[self.splitViewController.viewControllers lastObject] topViewController];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    if (![[NSUserDefaults standardUserDefaults] stringForKey:kNotesServerURL]) {
        [self showSettings:nil];
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)showSettings:(id)sender
{
    UIStoryboard *storyboard = self.storyboard;
    UINavigationController* nav = [storyboard instantiateViewControllerWithIdentifier:@"settings"];
    
    [self presentViewController:nav animated:YES completion:nil];
}

#pragma mark - Table View

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return [[_fetchedResultsController sections] count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    id <NSFetchedResultsSectionInfo> sectionInfo = [_fetchedResultsController sections][section];
    return [sectionInfo numberOfObjects];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell" forIndexPath:indexPath];
    [self configureCell:cell atIndexPath:indexPath];
    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the specified item to be editable.
    return YES;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        NSManagedObjectContext *context = [(id)[[UIApplication sharedApplication] delegate] managedObjectContext];
        [context deleteObject:[_fetchedResultsController objectAtIndexPath:indexPath]];
        
        NSError *error = nil;
        if (![context save:&error]) {
             // Replace this implementation with code to handle the error appropriately.
             // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development. 
            NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
            abort();
        }
    }   
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    // The table view should not be re-orderable.
    return NO;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        Note *object = [_fetchedResultsController objectAtIndexPath:indexPath];
        self.detailViewController.detailItem = object;
    }
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    NSManagedObjectContext *editContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
    [editContext setParentContext:[(id)[[UIApplication sharedApplication] delegate] managedObjectContext]];
    
    DetailViewController* nextViewController = [segue destinationViewController];
    nextViewController.delegate = self;

    nextViewController.managedObjectContext = editContext;
    
    Note* note;
    
    if ([[segue identifier] isEqualToString:@"addNote"]) {
        note = (Note *)[NSEntityDescription insertNewObjectForEntityForName:kNotesEntityName inManagedObjectContext:editContext];
        note.modified = [NSNumber numberWithInt:[[NSDate date] timeIntervalSince1970]];
    }
    
    if ([[segue identifier] isEqualToString:@"editNote"]) {
        NSIndexPath *indexPath = [self.tableView indexPathForSelectedRow];
        note = [_fetchedResultsController objectAtIndexPath:indexPath];
    }
    
    [nextViewController setDetailItem:note];
    
    
}

- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller
{
    [self.tableView beginUpdates];
}

- (void)controller:(NSFetchedResultsController *)controller didChangeSection:(id <NSFetchedResultsSectionInfo>)sectionInfo
           atIndex:(NSUInteger)sectionIndex forChangeType:(NSFetchedResultsChangeType)type
{
    switch(type) {
        case NSFetchedResultsChangeInsert:
            [self.tableView insertSections:[NSIndexSet indexSetWithIndex:sectionIndex] withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeDelete:
            [self.tableView deleteSections:[NSIndexSet indexSetWithIndex:sectionIndex] withRowAnimation:UITableViewRowAnimationFade];
            break;
    }
}

- (void)controller:(NSFetchedResultsController *)controller didChangeObject:(id)anObject
       atIndexPath:(NSIndexPath *)indexPath forChangeType:(NSFetchedResultsChangeType)type
      newIndexPath:(NSIndexPath *)newIndexPath
{
    UITableView *tableView = self.tableView;
    
    switch(type) {
        case NSFetchedResultsChangeInsert:
            [tableView insertRowsAtIndexPaths:@[newIndexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeDelete:
            [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeUpdate:
            [self configureCell:[tableView cellForRowAtIndexPath:indexPath] atIndexPath:indexPath];
            break;
            
        case NSFetchedResultsChangeMove:
            [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
            [tableView insertRowsAtIndexPaths:@[newIndexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
    }
}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller
{
    [self.tableView endUpdates];
}

/*
// Implementing the above methods to update the table view in response to individual changes may have performance implications if a large number of changes are made simultaneously. If this proves to be an issue, you can instead just implement controllerDidChangeContent: which notifies the delegate that all section and object changes have been processed. 
 
 - (void)controllerDidChangeContent:(NSFetchedResultsController *)controller
{
    // In the simplest, most efficient, case, reload the table view.
    [self.tableView reloadData];
}
 */

- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath
{
    NSDateFormatter *dateFormat = [[NSDateFormatter alloc] init];
    [dateFormat setDateStyle:NSDateFormatterShortStyle];
    
    Note *note = [_fetchedResultsController objectAtIndexPath:indexPath];
    cell.textLabel.text = note.title;
    NSNumber *unixtimestamp = note.modified;
    NSDate* date = [NSDate dateWithTimeIntervalSince1970:[unixtimestamp integerValue]];
    cell.detailTextLabel.text = [dateFormat stringFromDate:date];
}

# pragma mark - Delegation

/*
 Add controller's delegate method; informs the delegate that the add operation has completed, and indicates whether the user saved the new book.
 */
- (void)detailViewController:(DetailViewController *)controller didFinishWithSave:(BOOL)save {
    
    if (save) {
        /*
         The new book is associated with the add controller's managed object context.
         This means that any edits that are made don't affect the application's main managed object context -- it's a way of keeping disjoint edits in a separate scratchpad. Saving changes to that context, though, only push changes to the fetched results controller's context. To save the changes to the persistent store, you have to save the fetch results controller's context as well.
         */
        NSError *error;
        NSManagedObjectContext *editManagedObjectContext = [controller managedObjectContext];
        if (![editManagedObjectContext save:&error]) {
            /*
             Replace this implementation with code to handle the error appropriately.
             
             abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
             */
            NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
            abort();
        }
        
        NSManagedObjectContext* context = [(id)[[UIApplication sharedApplication] delegate] managedObjectContext];
        
        if (![context save:&error]) {
            /*
             Replace this implementation with code to handle the error appropriately.
             
             abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
             */
            NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
            abort();
        }
    }
    
    // Dismiss the modal view to return to the main list
    [self.navigationController popViewControllerAnimated:YES];
}

@end
