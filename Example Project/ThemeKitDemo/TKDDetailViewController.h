//
//  TKDDetailViewController.h
//  ThemeKitDemo
//
//  Created by Henri Normak on 01/07/2012.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ThemeKit.h"

@interface TKDDetailViewController : UIViewController <UISplitViewControllerDelegate, UITextViewDelegate>

@property (strong, nonatomic) NSData *exampleJSONData;

@end
