//
//  TKView.m
//  ThemeEngine
//
//  Created by Henri Normak on 15/12/2011.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "TKView.h"

@implementation TKView
@synthesize drawBlock;

+ (TKView *)viewWithFrame: (CGRect)frame andDrawingBlock: (TKDrawingBlock)block {
    TKView *view = [[TKView alloc] initWithFrame: frame];
    view.drawBlock = block;
    view.opaque = NO;

    return [view autorelease];
}

#pragma mark - Drawing

- (void)drawRect: (CGRect)rect {
    // Check if drawing block is present, if so, use it
    if (drawBlock) {
        drawBlock(UIGraphicsGetCurrentContext(), rect);
    }
}

#pragma mark - Memory management

- (void)dealloc {
    [(id)drawBlock release];
    
    [super dealloc];
}

@end
