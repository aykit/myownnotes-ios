//
//  MasterViewController.h
//  OwnCloud Notes
//
//  Created by Markus Klepp on 22/03/14.
//  Copyright (c) 2014 AyKit. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "DetailViewController.h"

@interface MasterViewController : UITableViewController

@property (strong, nonatomic) DetailViewController *detailViewController;

- (IBAction)createNote:(id)sender;

@end
