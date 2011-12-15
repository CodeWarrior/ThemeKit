//
//  TKView.h
//  ThemeEngine
//
//  Created by Henri Normak on 15/12/2011.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ThemeKit.h"

#pragma mark - Drawing block typedef
typedef void (^TKDrawingBlock)(CGContextRef context);

@interface TKView : UIView {
    TKDrawingBlock drawBlock;
}

@property (nonatomic, copy) TKDrawingBlock drawBlock;

+ (TKView *)viewWithFrame: (CGRect)frame andDrawingBlock: (TKDrawingBlock)block;

@end
