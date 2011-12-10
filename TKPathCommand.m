//
//  TKPathCommand.m
//  ThemeEngine
//
//  Created by Henri Normak on 28/11/2011.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "TKPathCommand.h"

@interface TKPathCommand (HiddenMethod)

- (NSString *)commandDescription: (Command)value;

@end

@implementation TKPathCommand
@synthesize command = _command;

@synthesize endPoint = _endPoint;
@synthesize controlPoint1 = _controlPoint1;
@synthesize controlPoint2 = _controlPoint2;

- (id)initWithCommand:(Command)newCommand {
    
    if ((self = [super init])) {
        self.command = newCommand;
        
        // Defaults
        self.endPoint = CGPointZero;
        self.controlPoint1 = CGPointZero;
        self.controlPoint2 = CGPointZero;
    }
    
    return self;
}

- (NSString *)description {
    // Create a description string
    return [NSString stringWithFormat: @"Command: %@ endPoint: %@ controlPoint1: %@ controlPoint2: %@", [self commandDescription: _command], NSStringFromCGPoint(_endPoint), NSStringFromCGPoint(_controlPoint1), NSStringFromCGPoint(_controlPoint2)];
}

- (NSString *)commandDescription: (Command)value {
    switch (value) {
        case TKMoveTo:
            return @"TKMoveTo";
            break;
        case TKClosePath:
            return @"TKClosePath";
            break;
        case TKLineTo:
            return @"TKLineTo";
            break;
        case TKCubicBezier:
            return @"TKCubicBezier";
            break;
        case TKQuadBezier:
            return @"TKQuadBezier";
            break;
        default:
            break;
    }
    
    return @"Unknown command";
}

@end
