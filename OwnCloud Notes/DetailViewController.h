//
//  DetailViewController.h
//  OwnCloud Notes
//
//  Created by Markus Klepp on 22/03/14.
//  Copyright (c) 2014 AyKit. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface DetailViewController : UIViewController <UISplitViewControllerDelegate>

@property (strong, nonatomic) NSDictionary *detailItem;

@property (weak, nonatomic) IBOutlet UILabel *detailDateLabel;
@property (weak, nonatomic) IBOutlet UITextView *detailContentTextView;
@property (weak, nonatomic) IBOutlet UIButton *offlineInfoButton;

- (IBAction)showOfflineMessage:(id)sender;

@end