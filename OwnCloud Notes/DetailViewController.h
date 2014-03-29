//
//  DetailViewController.h
//  OwnCloud Notes
//
//  Created by Markus Klepp on 22/03/14.
//  Copyright (c) 2014 AyKit. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Note.h"

@protocol DetailViewControllerDelegate;

@interface DetailViewController : UIViewController <UISplitViewControllerDelegate>

@property (strong, nonatomic) Note *detailItem;

@property (weak, nonatomic) IBOutlet UILabel *detailDateLabel;
@property (weak, nonatomic) IBOutlet UITextView *detailContentTextField;

@property (nonatomic, weak) id <DetailViewControllerDelegate> delegate;

-(IBAction) saveAndClose:(id)sender;

@end

@protocol DetailViewControllerDelegate
- (void)detailViewController:(DetailViewController *)controller didFinishWithSave:(BOOL)save;
@end
