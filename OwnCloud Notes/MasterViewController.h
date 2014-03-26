//
//  MasterViewController.h
//  OwnCloud Notes
//
//  Created by Markus Klepp on 22/03/14.
//  Copyright (c) 2014 AyKit. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "DetailViewController.h"

#import <CoreData/CoreData.h>

@interface MasterViewController : UITableViewController <DetailViewControllerDelegate>

@property (strong, nonatomic) DetailViewController *detailViewController;

- (IBAction)showSettings:(id)sender;

@end
