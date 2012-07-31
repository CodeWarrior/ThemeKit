//
//  TKDMasterViewController.h
//  ThemeKitDemo
//
//  Created by Henri Normak on 01/07/2012.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>

@class TKDDetailViewController;

@interface TKDMasterViewController : UITableViewController

@property (strong, nonatomic) TKDDetailViewController *detailViewController;

@end
