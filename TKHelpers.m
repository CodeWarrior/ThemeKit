//
//  TKHelpers.c
//  ThemeEngine
//
//  Created by Henri Normak on 30/06/2012.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "TKHelpers.h"
#import "TKConstants.h"

#pragma mark - C helpers

void TKContextSetBlendModeForString(CGContextRef context, NSString *string) {
    CGBlendMode blendMode;
    if ([string isEqualToString: @"overlay"]) {
        blendMode = kCGBlendModeOverlay;
    } else if ([string isEqualToString: @"multiply"]) {
        blendMode = kCGBlendModeMultiply;
    } else if ([string isEqualToString: @"softlight"]) {
        blendMode = kCGBlendModeSoftLight;
    } else {
        blendMode = kCGBlendModeNormal;
    }
    
    CGContextSetBlendMode(context, blendMode);
}
void TKContextAddShadowWithOptions(CGContextRef context, NSDictionary *options) {
    NSDictionary *offsetOptions = [options objectForKey: OffsetParameterKey];
    
    CGSize offset = CGSizeMake([[offsetOptions objectForKey: XCoordinateParameterKey] floatValue], [[offsetOptions objectForKey: YCoordinateParameterKey] floatValue]);
    CGFloat blur = 0.0;
    
    // Adjust blur if key is present
    if ([options objectForKey: BlurParameterKey]) {
        blur = [[options objectForKey: BlurParameterKey] floatValue];
    }
    
    CGFloat alpha = 1.0;
    
    if ([options objectForKey: AlphaParameterKey])
        alpha = [[options objectForKey: AlphaParameterKey] floatValue];
    
    if ([options objectForKey: ColorParameterKey])
        CGContextSetShadowWithColor(context, offset, blur, [[UIColor colorForWebColor: [options objectForKey: ColorParameterKey]] colorWithAlphaComponent: alpha].CGColor);
    else
        CGContextSetShadowWithColor(context, offset, blur, [[UIColor blackColor] colorWithAlphaComponent: alpha].CGColor);
}
void TKContextStrokePathWithOptions(CGContextRef context, NSDictionary *options) {
    // Check if blend mode is present
    if ([options objectForKey: BlendModeParameterKey]) {
        // Get the blend mode and apply it to the context
        TKContextSetBlendModeForString(context, [options objectForKey: BlendModeParameterKey]);
    }
    
    if ([options objectForKey: AlphaParameterKey])
        CGContextSetAlpha(context, [[options objectForKey: AlphaParameterKey] floatValue]);
    
    if ([options objectForKey: ColorParameterKey])
        CGContextSetStrokeColorWithColor(context, [UIColor colorForWebColor: [options objectForKey: ColorParameterKey]].CGColor);
    else
        CGContextSetStrokeColorWithColor(context, [UIColor blackColor].CGColor);
    
    // Set the width
    CGContextSetLineWidth(context, [[options objectForKey: WidthParameterKey] floatValue]);
    
    // Stroke it
    CGContextStrokePath(context);
}
void TKContextDrawGradientForOptions(CGContextRef context, NSDictionary *options, CGPoint startPoint, CGPoint endPoint) {
    // Apply the blend mode to the context if one is present
    if ([options objectForKey: BlendModeParameterKey]) {
        TKContextSetBlendModeForString(context, [options objectForKey: BlendModeParameterKey]);
    }
    
    // Check if alpha is present
    if ([options objectForKey: AlphaParameterKey]) {
        CGContextSetAlpha(context, [[options objectForKey: AlphaParameterKey] floatValue]); 
    }
    
    // Create the gradient
    NSArray *colors = [options objectForKey: GradientColorsParameterKey];
    NSMutableArray *CGColors = [NSMutableArray arrayWithCapacity: [colors count]];
    for (NSString *color in colors) {
        [CGColors insertObject: (id)[UIColor colorForWebColor: color].CGColor atIndex: [colors indexOfObject: color]];
    }
    
    // And then the locations
    colors = [options objectForKey: GradientPositionsParameterKey];
    CGFloat *positions = (CGFloat *)calloc(sizeof(CGFloat), [colors count]);
    for (NSNumber *number in colors) {
        positions[[colors indexOfObject: number]] = [number floatValue];
    }
    
    CGColorSpaceRef rgbSpace = CGColorSpaceCreateDeviceRGB();
	CGGradientRef gradient = CGGradientCreateWithColors(rgbSpace, (CFArrayRef)CGColors, positions);
    CGColorSpaceRelease(rgbSpace);
    free(positions);
    
    //Draw the gradient
    CGContextDrawLinearGradient(context, gradient, startPoint, endPoint, 0);
    
    // Release the gradient
    CGGradientRelease(gradient);
}

CGRect TKShadowRectForRectAndOptions(CGRect rect, NSDictionary *options) {
    NSDictionary *offsetDictionary = [options objectForKey: OffsetParameterKey];
    CGSize offset = CGSizeMake([[offsetDictionary objectForKey: XCoordinateParameterKey] floatValue], [[offsetDictionary objectForKey: YCoordinateParameterKey] floatValue]);
    CGFloat blur = [[options objectForKey: BlurParameterKey] floatValue];
    
    // Create the shadow rect
    CGRect shadowRect = rect;
    
    CGPoint shadowOrigin = shadowRect.origin;
    shadowOrigin.x += offset.width - blur;
    shadowOrigin.y += offset.height - blur;
    shadowRect.origin = shadowOrigin;
    
    CGSize shadowSize = shadowRect.size;
    shadowSize.width += 2 * blur;
    shadowSize.height += 2 * blur;
    shadowRect.size = shadowSize;
    
    // Return the resulting rect
    return shadowRect;
}
CGRect TKStrokeRectForRectAndWidth(CGRect rect, CGFloat width) {
    // Create a stroke rect
    CGRect strokeRect = rect;
    CGPoint strokeOrigin = strokeRect.origin;
    strokeOrigin.x -= width;
    strokeOrigin.y -= width;
    strokeRect.origin = strokeOrigin;
    
    CGSize strokeSize = strokeRect.size;
    strokeSize.width += 2 * width;
    strokeSize.height += 2 * width;
    strokeRect.size = strokeSize;
    
    // Return the result
    return strokeRect;
}
void TKBalanceCornerRadiiIntoSize(CGFloat *radii, CGSize size) {
    // This method is passed an array of floats always 4 long, compare each pair
    // The order is top-right bottom-right bottom-left top-left (clockwise, beginning in the top-right)    
    // None should be larger than half of the either side
    // (as they both connect the width to height, we need to make 8 comparisons)
    CGFloat halfWidth = roundf(size.width / 2.0);
    CGFloat halfHeight = roundf(size.height / 2.0);
    
    // Top right
    radii[0] = radii[0] > halfWidth ? halfWidth : radii[0];
    radii[0] = radii[0] > halfHeight ? halfHeight : radii[0];
    
    // Bottom right
    radii[1] = radii[1] > halfWidth ? halfWidth : radii[1];
    radii[1] = radii[1] > halfHeight ? halfHeight : radii[1];
    
    // Bottom left
    radii[2] = radii[2] > halfWidth ? halfWidth : radii[2];
    radii[2] = radii[2] > halfHeight ? halfHeight : radii[2];
    
    // Top left
    radii[3] = radii[3] > halfWidth ? halfWidth : radii[3];
    radii[3] = radii[3] > halfHeight ? halfHeight : radii[3];
}
CGMutablePathRef TKRoundedPathInRectForRadii(CGFloat *radii, CGRect rect) {
    // There has to be 4 values in the radii array
    CGMutablePathRef roundedPath = CGPathCreateMutable();
    CGPathMoveToPoint(roundedPath, NULL, rect.origin.x + radii[3], rect.origin.y);
    CGPathAddArc(roundedPath, NULL, rect.origin.x + radii[3], rect.origin.y + radii[3], 
                 radii[3], -M_PI / 2.0, M_PI, 1);
    
    CGPathAddLineToPoint(roundedPath, NULL, rect.origin.x, rect.origin.y + rect.size.height - radii[2]);
    CGPathAddArc(roundedPath, NULL, rect.origin.x + radii[2], rect.origin.y + rect.size.height - radii[2], 
                 radii[2], M_PI, M_PI / 2.0, 1);
    
    CGPathAddLineToPoint(roundedPath, NULL, rect.origin.x + rect.size.width - radii[1], rect.origin.y + rect.size.height);
    CGPathAddArc(roundedPath, NULL, rect.origin.x + rect.size.width - radii[1], rect.origin.y + rect.size.height - radii[1], 
                 radii[1], M_PI / 2.0, 0.0f, 1);
    
    CGPathAddLineToPoint(roundedPath, NULL, rect.origin.x + rect.size.width, rect.origin.y + radii[0]);
    CGPathAddArc(roundedPath, NULL, rect.origin.x + rect.size.width - radii[0], rect.origin.y + radii[0],
                 radii[0], 0.0f, -M_PI / 2.0, 1);
    
    CGPathAddLineToPoint(roundedPath, NULL, rect.origin.x + radii[3], rect.origin.y);
    
    [(id)roundedPath autorelease];
    return roundedPath;
}


#pragma mark - UIColor Extension

@implementation UIColor (Extensions)

// Converting web colors into UIColor objects
+ (UIColor *)colorForWebColor: (NSString *)colorCode {
    // Start by mutating the string
    NSMutableString *string = [NSMutableString stringWithString: colorCode];
    
    // Remove all #
    [string replaceOccurrencesOfString: @"#" withString: @"" options: 0 range: NSMakeRange(0, [string length])];
    
    // Check if clear color needed
    if ([string isEqualToString: @"clear"]) {
        return [UIColor clearColor];
    }
    
    // By default no alpha value is in the string
    BOOL alpha = NO;
    
    // Check if size is enough
    switch ([string length]) {
        case 1:
            // The pattern is easy to form
            [string appendFormat: @"%@%@%@%@%@", string, string, string, string, string];
            break;
        case 2:
            // Once again, repeat the pattern
            [string appendFormat: @"%@%@", string, string];
            break;
        case 3:
            // And again, repeat the pattern
            [string appendFormat: @"%@", string];
            break;
        case 4:
            // Now it's a bit more difficult, repeat, but then cut the end off
            [string appendString: [string substringToIndex: 2]];
            break;
        case 5:
            // Same as with four, but add one less
            [string appendString: [string substringToIndex: 1]];
            break;
        case 8:
            // We have alpha as well
            alpha = YES;
            break;
        default:
            break;
    }
    
    // Storage for all the values
    unsigned int color;
    
    // Now we can proceed to calculate the values, start by creating a range of the string to look at
    [[NSScanner scannerWithString: string] scanHexInt: &color]; // Grabs color value
    
    // Return appropriate UIColor
    if (alpha) {
        return [UIColor colorWithRed: (float)(((color >> 16) & 0xFF) / 255.0)
                               green: (float)(((color >> 8) & 0xFF) / 255.0)
                                blue: (float)((color & 0xFF) / 255.0)
                               alpha: (float)(((color >> 24) & 0xFF) / 255.0)];
    }
    
    return [UIColor colorWithRed: (float)(((color >> 16) & 0xFF) / 255.0)
                           green: (float)(((color >> 8) & 0xFF) / 255.0)
                            blue: (float)((color & 0xFF) / 255.0)
                           alpha: 1.0];
}

- (NSString *)hexValue {
    // Get all the components
    const CGFloat *c = CGColorGetComponents(self.CGColor);
    
    CGFloat a = MIN(MAX(c[CGColorGetNumberOfComponents(self.CGColor) - 1], 0), 1);
    CGFloat r = MIN(MAX(c[0], 0), 1);
    CGFloat g = MIN(MAX(c[0], 0), 1);
    CGFloat b = MIN(MAX(c[0], 0), 1);
    
    if (CGColorSpaceGetModel(CGColorGetColorSpace(self.CGColor)) != kCGColorSpaceModelMonochrome) {
        g = MIN(MAX(c[1], 0), 1);
        b = MIN(MAX(c[2], 0), 1);
    }
    
    // Convert to hex string between 0x00 and 0xFF
    return [NSString stringWithFormat:@"0x%02X%02X%02X%02X",
            (NSInteger)(a * 255), (NSInteger)(r * 255), (NSInteger)(g * 255), (NSInteger)(b * 255)];
}

@end