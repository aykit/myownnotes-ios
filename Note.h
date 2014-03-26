//
//  Note.h
//  OwnCloud Notes
//
//  Created by Markus Klepp on 24/03/14.
//  Copyright (c) 2014 AyKit. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>


@interface Note : NSManagedObject

@property (nonatomic, retain) NSString * title;
@property (nonatomic, retain) NSString * content;
@property (nonatomic, retain) NSNumber * modified;

@end
