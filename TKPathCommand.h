//
//  TKPathCommand.h
//  ThemeEngine
//
//  Created by Henri Normak on 28/11/2011.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

typedef enum { TKMoveTo, TKClosePath,
               TKLineTo, 
               TKCubicBezier, 
               TKQuadBezier } Command;

@interface TKPathCommand : NSObject {
    Command _command;
        
    CGPoint _endPoint;
    CGPoint _controlPoint1;
    CGPoint _controlPoint2;
}

@property (nonatomic) Command command;

@property (nonatomic) CGPoint endPoint;
@property (nonatomic) CGPoint controlPoint1;
@property (nonatomic) CGPoint controlPoint2;

- (id)initWithCommand: (Command)command;

@end
