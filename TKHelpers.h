//
//  TKHelpers.h
//  ThemeEngine
//
//  A variety of helpers that deal with parsing parameters in a dictionary into a options added on top of CGContext
//
//  Created by Henri Normak on 30/06/2012.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

#ifndef ThemeEngine_DrawingHelpers_h
#define ThemeEngine_DrawingHelpers_h

#pragma mark - C helpers
void TKContextSetBlendModeForString(CGContextRef context, NSString *string);
void TKContextAddShadowWithOptions(CGContextRef context, NSDictionary *options);
void TKContextStrokePathWithOptions(CGContextRef context, NSDictionary *options);
void TKContextDrawGradientForOptions(CGContextRef context, NSDictionary *options, CGPoint startPoint, CGPoint endPoint);

CGRect TKShadowRectForRectAndOptions(CGRect rect, NSDictionary *options);
CGRect TKStrokeRectForRectAndWidth(CGRect rect, CGFloat width);
void TKBalanceCornerRadiiIntoSize(CGFloat *radii, CGSize size);
CGMutablePathRef TKRoundedPathInRectForRadii(CGFloat *radii, CGRect rect);

#endif

#pragma mark - UIColor extension

@interface UIColor (Extensions)

// Method for converting web hex color into a UIColor object, pass in a string similar to "FFFFFF" or "#FFFFFF"
// If less than six characters long, will be used as a pattern - "FFA" will result in "FFAFFA" and "FFFA" results in "FFFAFF"
+ (UIColor *)colorForWebColor: (NSString *)colorCode;

// Reverse of the first method, returning a hex value of a UIColor
- (NSString *)hexValue;

@end
