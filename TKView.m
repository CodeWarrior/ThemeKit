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

    return [view autorelease];
}

#pragma mark - Drawing

- (id)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame: frame])) {
        self.opaque = NO;
    }
    
    return self;
}

- (void)setDrawBlock:(TKDrawingBlock)newDrawBlock {
    Block_release(drawBlock);
    drawBlock = Block_copy(newDrawBlock);
    
    // Redraw the view
    [self setNeedsDisplay];
}

- (void)drawRect: (CGRect)rect {
    // Check if drawing block is present, if so, use it
    if (drawBlock) {
        drawBlock(UIGraphicsGetCurrentContext(), rect);
    }
}

#pragma mark - Memory management

- (void)dealloc {
    Block_release(drawBlock);
    
    [super dealloc];
}

@end
