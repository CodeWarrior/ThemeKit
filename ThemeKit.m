//
//  ThemeView.m
//  ThemeEngine
//
//  Created by Henri Normak on 13/11/2011.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "ThemeKit.h"
#import "TKPathCommand.h"
#import "TKView.h"

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
    
    // Check if size is enough
    int length = [string length];
    switch (length) {
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
        default:
            break;
    }
    
    // Storage for all the values
    unsigned int color;
    
    // Now we can proceed to calculate the values, start by creating a range of the string to look at
    [[NSScanner scannerWithString: string] scanHexInt: &color]; // Grabs color value
    
    // Return appropriate UIColor
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

#pragma mark - C helpers
void TKContextSetBlendModeForString(CGContextRef context, NSString *string);
void TKContextAddShadowWithOptions(CGContextRef context, NSDictionary *options);
void TKContextStrokePathWithOptions(CGContextRef context, NSDictionary *options);
void TKContextDrawGradientForOptions(CGContextRef context, NSDictionary *options, CGPoint startPoint, CGPoint endPoint);

CGRect TKShadowRectForRectAndOptions(CGRect rect, NSDictionary *options);
CGRect TKStrokeRectForRectAndWidth(CGRect rect, CGFloat width);
void TKBalanceCornerRadiiIntoSize(CGFloat *radii, CGSize size);
CGMutablePathRef TKRoundedPathInRectForRadii(CGFloat *radii, CGRect rect);

#pragma mark - Drawing Extension

@interface ThemeKit (DrawingExtensions)

#pragma mark - Factory methods
- (NSArray *)viewsForDescriptions: (NSArray *)descriptions;
- (UIView *)addSubviewsWithDescriptions: (NSArray *)descriptions toView: (UIView *)view;
- (UIView *)viewForDescription: (NSDictionary *)description;

#pragma mark - Primitives
- (TKView *)rectangleInFrame: (CGRect)frame options: (NSDictionary *)options;      // Rectangle
- (TKView *)circleInFrame: (CGRect)frame options: (NSDictionary *)options;         // Circle
- (TKView *)pathAtOrigin: (CGPoint)start forOptions: (NSDictionary *)options;      // Path

// Path, following SVG standard syntax
- (CGMutablePathRef)pathForSVGSyntax: (NSString *)description;

// SVG Paths, returns an array of TKPathCommand objects, 
// containing instructions on how to draw the description
- (NSArray *)arrayOfPathCommandsFromSVGDescription: (NSString *)description;
- (CGPoint)pointFromScanner: (NSScanner *)scanner relativeToPoint: (CGPoint)currentPoint;

// Cache
- (void)flushCache;

@end

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

#pragma mark - Drawing Implementation

@implementation ThemeKit (DrawingExtensions)

#pragma mark - Factory methods

- (NSArray *)viewsForDescriptions: (NSArray *)descriptions {
    // Create a mutable array to store the subviews in
    NSMutableArray *subviews = [NSMutableArray arrayWithCapacity: [descriptions count]];
        
    // Enumerate over the descriptions
    for (NSDictionary *info in descriptions) {
        [subviews insertObject: [self viewForDescription: info] atIndex: [descriptions indexOfObject: info]];
    }
    
    return [NSArray arrayWithArray: subviews];
}

- (UIView *)addSubviewsWithDescriptions: (NSArray *)descriptions toView: (UIView *)view {
    // Keep track of the origin, in case we need to adjust it
    CGPoint origin = CGPointMake(CGRectGetMinX(view.frame), CGRectGetMinY(view.frame));
    
    // Keep track of the size, in case the subviews have shadows or strokes that otherwise would extend outside
    // our frame
    CGSize finalSize = CGSizeMake(CGRectGetWidth(view.frame), CGRectGetHeight(view.frame));
    
    // Iterate over the descriptions and add the views as subviews
    for (NSDictionary *viewDesc in descriptions) {
        // Add the subview
        [view insertSubview: [self viewForDescription: viewDesc] atIndex: [descriptions indexOfObject: viewDesc]];
        
        // Check whether the view had a shadow or a stroke, if so adjust the origin
        CGFloat x, y;
        if ([viewDesc objectForKey: DropShadowOptionKey]) {
            NSDictionary *shadow = [viewDesc objectForKey: DropShadowOptionKey];
            x = [[[shadow objectForKey: OffsetParameterKey] objectForKey: XCoordinateParameterKey] floatValue];
            y = [[[shadow objectForKey: OffsetParameterKey] objectForKey: YCoordinateParameterKey] floatValue];
            
            // Only negative offsets affect the origin
            if (x < 0)
                origin.x += x;
            
            if (y < 0)
                origin.y += y;
        }
        
        // Stroke
        if ([viewDesc objectForKey: OuterStrokeOptionKey]) {
            // Stroke is uniform, hence grab the width
            CGFloat width = [[[viewDesc objectForKey: OuterStrokeOptionKey] objectForKey: WidthParameterKey] floatValue];
            
            // Round up, because fractional width are common (how the paths work)
            width = ceilf(width);
            
            // Check if width changes either of the axis
            if (width > fabs(x))
                origin.x -= (width - fabs(x));
            
            if (width > fabs(x))
                origin.y -= (width - fabs(y));
        }
        
        // Adjust the finalsize
        finalSize.width = MAX(finalSize.width, CGRectGetWidth(view.frame));
        finalSize.height = MAX(finalSize.height, CGRectGetHeight(view.frame));
    }
    
    // Adjust the view so that it matches the contents
    CGRect frame = view.frame;
    frame.size = finalSize;
    frame.origin = origin;
    view.frame = frame;
    
    return view;
}

- (UIView *)viewForDescription: (NSDictionary *)description {
    // First start by identifying the type of the view
    NSString *type = [description objectForKey: TypeParameterKey];
    
    // Get the frame of the view, they all need to have it = it's type independent (line is an exception)
    CGPoint origin = CGPointZero;
    if ([description objectForKey: OriginParameterKey]) {
        origin.x = [[[description objectForKey: OriginParameterKey] objectForKey: XCoordinateParameterKey] floatValue];
        origin.y = [[[description objectForKey: OriginParameterKey] objectForKey: YCoordinateParameterKey] floatValue];
    }
    
    CGRect frame = CGRectZero;
    // Size will be determined for views, paths don't need to have size specified (will be calculated)
    if (![type isEqualToString: PathTypeKey]) {
        frame = CGRectMake(origin.x, origin.y,
                           [[[description objectForKey: SizeParameterKey] objectForKey: WidthParameterKey] floatValue],
                           [[[description objectForKey: SizeParameterKey] objectForKey: HeightParameterKey] floatValue]);
    }
    
    // Resulting view
    UIView *result = nil;
    
    // Depending on the type use the appropriate drawing method
    if ([type isEqualToString: RectangleTypeKey]) {
        result = [self rectangleInFrame: frame options: description];
    } else if ([type isEqualToString: EllipseTypeKey]) {
        result = [self circleInFrame: frame options: description];
    } else if ([type isEqualToString: PathTypeKey]) {
        result = [self pathAtOrigin: origin forOptions: description];
    } else if ([type isEqualToString: LabelTypeKey]) {
        UILabel *label = [[[UILabel alloc] initWithFrame: frame] autorelease];
        label.backgroundColor = [UIColor clearColor];
        
        // Content
        if ([description objectForKey: ContentStringParameterKey]) {
            label.text = [description objectForKey: ContentStringParameterKey];
        }
        
        // Alignment
        if ([description objectForKey: ContentAlignmentParameterKey]) {
            NSString *alignment = [description objectForKey: ContentAlignmentParameterKey];
            if ([alignment isEqualToString: @"center"]) {
                label.textAlignment = UITextAlignmentCenter;
            } else if ([alignment isEqualToString: @"left"]) {
                label.textAlignment = UITextAlignmentLeft;
            } else if ([alignment isEqualToString: @"right"]) {
                label.textAlignment = UITextAlignmentRight;
            }
        }
        
        // Text color
        if ([description objectForKey: ColorParameterKey]) {
            label.textColor = [UIColor colorForWebColor: [description objectForKey: ColorParameterKey]];
        }
        
        // Alpha
        if ([description objectForKey: AlphaParameterKey]) {
            label.alpha = [[description objectForKey: AlphaParameterKey] floatValue];
        }
        
        // Font size & Font
        if ([description objectForKey: ContentFontSizeParameterKey]) {
            label.font = [UIFont systemFontOfSize: [[description objectForKey: ContentFontSizeParameterKey] floatValue]];
        }
        
        if ([description objectForKey: ContentFontWeightParameterKey]) {
            NSString *weight = [description objectForKey: ContentFontWeightParameterKey];
            
            if ([weight isEqualToString: @"bold"]) {
                label.font = [UIFont boldSystemFontOfSize: label.font.pointSize];
            } else {
                label.font = [UIFont systemFontOfSize: label.font.pointSize];
            }
        } else if ([description objectForKey: ContentFontNameParameterKey]) {
            label.font = [UIFont fontWithName: [description objectForKey: ContentFontNameParameterKey] size: label.font.pointSize];
        }
        
        // Shadow
        if ([description objectForKey: DropShadowOptionKey]) {
            label.shadowColor = [UIColor colorForWebColor: [[description objectForKey: DropShadowOptionKey] objectForKey: ColorParameterKey]];
            
            if ([[description objectForKey: DropShadowOptionKey] objectForKey: AlphaParameterKey]) {
                label.shadowColor = [label.shadowColor colorWithAlphaComponent: [[[description objectForKey: DropShadowOptionKey] objectForKey: AlphaParameterKey] floatValue]];
            }
            
            NSDictionary *offset = [[description objectForKey: DropShadowOptionKey] objectForKey: OffsetParameterKey];
            label.shadowOffset = CGSizeMake([[offset objectForKey: XCoordinateParameterKey] floatValue],
                                            [[offset objectForKey: YCoordinateParameterKey] floatValue]);
        }
        
        result = label;
    } else {
        NSLog(@"Unknown type \"%@\" encountered, ignoring", type);
        return nil;
    }
    
    // Check for additional subviews
    if ([description objectForKey: SubviewSectionKey]) {
        [self addSubviewsWithDescriptions: [description objectForKey: SubviewSectionKey] toView: result];
    }
        
    return result;
}

#pragma mark - Primitives

- (TKView *)rectangleInFrame: (CGRect)frame options: (NSDictionary *)options {
    // Keep note of any changes to the offset of drawing, this points to where, the main view should begin and how big it should be
    CGPoint origin = CGPointMake(0.0, 0.0);
    CGSize size = frame.size;
    
    // Additionally keep track of the canvasrect
    CGRect canvasRect = frame;
    
    // If outer stroke, enlarge the frame
    if ([options objectForKey: OuterStrokeOptionKey]) {
        CGFloat strokeWidth = [[[options objectForKey: OuterStrokeOptionKey] objectForKey: WidthParameterKey] floatValue];
        
        // Create a stroke rect
        CGRect strokeRect = TKStrokeRectForRectAndWidth(frame, strokeWidth);
        
        // Find a union between the canvas and stroke rect
        canvasRect = CGRectUnion(canvasRect, strokeRect);
    }
    
    // If drop shadow is present adjust the size
    if ([options objectForKey: DropShadowOptionKey]) {
        // Create a special frame for the shadow
        NSDictionary *dictionary = [options objectForKey: DropShadowOptionKey];
        CGRect shadowRect = TKShadowRectForRectAndOptions(frame, dictionary);
                        
        // Find the union between canvas and shadow
        canvasRect = CGRectUnion(canvasRect, shadowRect);
    }
    
    // Now as we have the frame, check cache for a view with same properties
    // As a key use the NSDictionary
    if (_isCached && [_cache objectForKey: options]) {
        TKDrawingBlock drawBlock = [_cache objectForKey: options];
        TKView *result = [TKView viewWithFrame: CGRectMake(frame.origin.x, frame.origin.y, 
                                                           canvasRect.size.width, canvasRect.size.height)
                               andDrawingBlock: drawBlock];

        return result;
    }
    
    // Adjust the inner origin, this is where the actual view is located
    origin.x = frame.origin.x - canvasRect.origin.x;
    origin.y = frame.origin.y - canvasRect.origin.y;
        
    // Create the drawing block
    TKDrawingBlock block = ^(CGContextRef context) {
        // Now if there are corner-radii defined, make sure all 4 have a value and balance
        NSObject *corners = [options valueForKey: CornerRadiusParameterKey];
        
        // Create an array into which well add the values
        CGFloat radii[4];
        
        // Few variables for rounded corners
        BOOL rounded = NO;
        CGMutablePathRef roundedPath;
        
        if (corners) {
            // Set the flag
            rounded = YES;
            
            // First check if it's an array or a simple value
            if ([corners respondsToSelector: @selector(objectAtIndex:)]) {
                // Mutate it
                NSMutableArray *adjustedCorners = [NSMutableArray arrayWithArray: (NSArray *)corners];
                
                // Array, make sure it's 4 long
                int count = 4 - [adjustedCorners count];
                if ([adjustedCorners count] < 4) {
                    for (int i = 0; i < count; i++) {
                        // i refers to the index were copying the value from
                        [adjustedCorners addObject: [adjustedCorners objectAtIndex: i]];
                    }
                }
                
                // Adjust the radii
                radii[0] = [[adjustedCorners objectAtIndex: 0] floatValue];
                radii[1] = [[adjustedCorners objectAtIndex: 1] floatValue];
                radii[2] = [[adjustedCorners objectAtIndex: 2] floatValue];
                radii[3] = [[adjustedCorners objectAtIndex: 3] floatValue];
                
                adjustedCorners = nil;  // Hurry up the memory cleaning
            } else {
                // Means it's one single value
                CGFloat radius = [(NSNumber *)corners floatValue];
                radii[0] = radius;
                radii[1] = radius;
                radii[2] = radius;
                radii[3] = radius;
            }
            
            // Balance the corners
            TKBalanceCornerRadiiIntoSize(radii, frame.size);
        }
        
        // Create the path incase the rectangle is rounded
        if (rounded)
            roundedPath = TKRoundedPathInRectForRadii(radii, CGRectMake(origin.x, origin.y, size.width, size.height));
        
        // Drawing code
        // Start with the main inner view
        CGContextSaveGState(context);
        
        // Alpha
        if ([options objectForKey: AlphaParameterKey]) {
            CGContextSetAlpha(context, [[options objectForKey: AlphaParameterKey] floatValue]);
        }
        
        // If shadow needed, add it to the context
        if ([options objectForKey: DropShadowOptionKey]) {
            TKContextAddShadowWithOptions(context, [options objectForKey: DropShadowOptionKey]);
        }
        
        // Apply the blend mode to the context if one is present
        if ([options objectForKey: BlendModeParameterKey]) {
            TKContextSetBlendModeForString(context, [options objectForKey: BlendModeParameterKey]);
        }
        
        // Load in the fill color
        if ([options objectForKey: ColorParameterKey])
            CGContextSetFillColorWithColor(context, [UIColor colorForWebColor: [options objectForKey: ColorParameterKey]].CGColor);
        else
            CGContextSetFillColorWithColor(context, [UIColor whiteColor].CGColor);
        
        // If rounded use the path, else just fill the rect
        if (rounded) {        
            // Add path to context and fill it
            CGContextAddPath(context, roundedPath);
            CGContextFillPath(context);
        } else {
            CGContextFillRect(context, CGRectMake(origin.x, origin.y, size.width, size.height));
        }
        
        CGContextRestoreGState(context);
        
        // Check if gradient is present, if so draw it over the fill
        if ([options objectForKey: GradientFillOptionKey]) {        
            CGContextSaveGState(context);
            
            // Gradient is present, first clip the context, either to a rect or to a path
            if (rounded) {            
                // Add path to context and fill it
                CGContextAddPath(context, roundedPath);
                CGContextClip(context);
            } else {
                CGContextClipToRect(context, CGRectMake(origin.x, origin.y, size.width, size.height));
            }
            
            NSDictionary *dictionary = [options objectForKey: GradientFillOptionKey];
            
            TKContextDrawGradientForOptions(context, dictionary, CGPointMake(origin.x, origin.y), CGPointMake(origin.x, origin.y + size.height));
            
            CGContextRestoreGState(context);
        }
        
        // Inner shadow
        if ([options objectForKey: InnerShadowOptionKey]) {
            CGContextSaveGState(context);
            
            NSDictionary *dictionary = [options objectForKey: InnerShadowOptionKey];
            
            // Start by clipping to the interior
            if (rounded) {            
                // Add path to context and fill it
                CGContextAddPath(context, roundedPath);            
            } else {
                CGContextAddRect(context, CGRectMake(origin.x, origin.y, size.width, size.height));
            }
            
            CGContextClip(context);
            
            // Add bounding
            CGContextAddRect(context, CGContextGetClipBoundingBox(context));
            
            // Add shifted interior by the offset of the inner shadow
            if (rounded) {
                CGRect rect = CGRectMake(origin.x + [[[dictionary objectForKey: OffsetParameterKey] objectForKey: XCoordinateParameterKey] floatValue],
                                         origin.y + [[[dictionary objectForKey: OffsetParameterKey] objectForKey: YCoordinateParameterKey] floatValue],
                                         size.width, size.height);
                CGMutablePathRef shadowRoundedPath = TKRoundedPathInRectForRadii(radii, rect);
                
                CGContextAddPath(context, shadowRoundedPath);            
            } else {
                CGContextAddRect(context, CGRectMake(origin.x + [[[dictionary objectForKey: OffsetParameterKey] objectForKey: XCoordinateParameterKey] floatValue],
                                                     origin.y + [[[dictionary objectForKey: OffsetParameterKey] objectForKey: YCoordinateParameterKey] floatValue],
                                                     size.width, size.height));
            }
            
            // Set the color and opacity
            if ([dictionary objectForKey: ColorParameterKey]) {
                CGContextSetFillColorWithColor(context, [UIColor colorForWebColor: [dictionary objectForKey: ColorParameterKey]].CGColor);
            }
            
            if ([dictionary objectForKey: AlphaParameterKey]) {
                CGContextSetAlpha(context, [[dictionary objectForKey: AlphaParameterKey] floatValue]);
            }
            
            // Set blend mode
            if ([dictionary objectForKey: BlendModeParameterKey]) {
                TKContextSetBlendModeForString(context, [dictionary objectForKey: BlendModeParameterKey]);
            }
            
            // Fill by using EO rule
            CGContextEOFillPath(context);
            
            CGContextRestoreGState(context);
        }
        
        // Strokes
        // Outer
        if ([options objectForKey: OuterStrokeOptionKey]) {
            CGContextSaveGState(context);
            
            // Parameters
            NSDictionary *dictionary = [options objectForKey: OuterStrokeOptionKey];
            
            // Width
            CGFloat strokeWidth = [[dictionary objectForKey: WidthParameterKey] floatValue];
            
            // There is a stroke, either create a path or enlarge the rect slightly
            CGFloat halfStroke = strokeWidth / 2.0;
            if (rounded) {
                // Use the radii to draw a path, but adjust the radii, to be correct for the center of the stroke
                CGFloat strokeRadii[4] = { radii[0] + halfStroke, radii[1] + halfStroke, radii[2] + halfStroke, radii[3] + halfStroke };
                
                CGRect rect = CGRectMake(origin.x - strokeWidth / 2.0, origin.y - strokeWidth / 2.0,
                                         size.width + strokeWidth, size.height + strokeWidth);
                CGMutablePathRef strokeRoundedPath = TKRoundedPathInRectForRadii(strokeRadii, rect);
                
                // Add path to context and fill it
                CGContextAddPath(context, strokeRoundedPath);            
            } else {
                // Not rounded, add the rect
                CGContextAddRect(context, CGRectMake(origin.x - halfStroke, origin.y - halfStroke, size.width + strokeWidth, size.height + strokeWidth));
            }
            
            TKContextStrokePathWithOptions(context, dictionary);
            
            CGContextRestoreGState(context);
        }
        
        // Inner
        if ([options objectForKey: InnerStrokeOptionKey]) {
            CGContextSaveGState(context);
            
            // Parameters
            NSDictionary *dictionary = [options objectForKey: InnerStrokeOptionKey];
            
            // Width
            CGFloat strokeWidth = [[dictionary objectForKey: WidthParameterKey] floatValue];
            
            // There is a stroke, either create a path or enlarge the rect slightly
            CGFloat halfStroke = strokeWidth / 2.0;
            if (rounded) {
                // Use the radii to draw a path, but adjust the radii, to be correct for the center of the stroke
                CGFloat strokeRadii[4] = { MAX(0.0, radii[0] - halfStroke), MAX(radii[1] - halfStroke, 0.0), MAX(0.0, radii[2] - halfStroke), MAX(0.0, radii[3] - halfStroke) };
                
                CGRect rect = CGRectMake(origin.x + strokeWidth / 2.0, origin.y + strokeWidth / 2.0,
                                         size.width - strokeWidth, size.height - strokeWidth);
                CGMutablePathRef strokeRoundedPath = TKRoundedPathInRectForRadii(strokeRadii, rect);
                
                // Add path to context and fill it
                CGContextAddPath(context, strokeRoundedPath);            
            } else {
                // Not rounded, add the rect
                CGContextAddRect(context, CGRectMake(origin.x + halfStroke, origin.y + halfStroke, size.width - strokeWidth, size.height - strokeWidth));
            }
            
            // Stroke the path
            TKContextStrokePathWithOptions(context, dictionary);
            
            CGContextRestoreGState(context);
        }
    };
    
    // Store into cache, if needed. Use the same key created before
    if (_isCached)
        [_cache setObject: Block_copy(block) forKey: options];
    
    // Wrap up and create the resulting view
    TKView *view = [TKView viewWithFrame: CGRectMake(frame.origin.x, frame.origin.y, 
                                                     canvasRect.size.width, canvasRect.size.height)
                         andDrawingBlock: block];
    
    return view;
}

- (TKView *)circleInFrame:(CGRect)frame options:(NSDictionary *)options {
    // Keep note of any changes to the offset of drawing, this points to where, the main view should begin and how big it should be
    CGPoint origin = CGPointMake(0.0, 0.0);
    CGSize size = frame.size;
    
    // Additionally keep track of the canvasrect
    CGRect canvasRect = frame;
    
    // Check if there is a need for a outer stroke
    if ([options objectForKey: OuterStrokeOptionKey]) {
        // Adjust the canvasrect
        CGFloat strokeWidth = [[[options objectForKey: OuterStrokeOptionKey] objectForKey: WidthParameterKey] floatValue];
        
        CGRect strokeRect = TKStrokeRectForRectAndWidth(frame, strokeWidth);
        
        // Union to the canvasrect
        canvasRect = CGRectUnion(canvasRect, strokeRect);
    }
    
    // Check if there is a need for a drop shadow
    if ([options objectForKey: DropShadowOptionKey]) {
        // Adjust the canvasrect, first get the property dictionary
        NSDictionary *shadow = [options objectForKey: DropShadowOptionKey];
        
        CGRect shadowRect = TKShadowRectForRectAndOptions(frame, shadow);
        
        // Union into the canvas
        canvasRect = CGRectUnion(canvasRect, shadowRect);
    }
    
    // Check cache
    if (_isCached && [_cache objectForKey: options]) {
        TKDrawingBlock block = [_cache objectForKey: options];
        
        TKView *view = [TKView viewWithFrame: CGRectMake(frame.origin.x, frame.origin.y, 
                                                         canvasRect.size.width, canvasRect.size.height)
                             andDrawingBlock: block];
        
        return view;
    }
    
    // Adjust the inner origin, this is where the actual view is located
    origin.x = frame.origin.x - canvasRect.origin.x;
    origin.y = frame.origin.y - canvasRect.origin.y;
    
    // Create the drawing block
    TKDrawingBlock drawBlock = ^(CGContextRef context) {
        // Alpha
        if ([options objectForKey: AlphaParameterKey]) {
            CGContextSetAlpha(context, [[options objectForKey: AlphaParameterKey] floatValue]);
        }
        
        // Start by drawing the main shape
        // Start with the main inner view
        CGContextSaveGState(context);
        
        // If shadow needed, draw it
        if ([options objectForKey: DropShadowOptionKey]) {
            NSDictionary *dictionary = [options objectForKey: DropShadowOptionKey];
            TKContextAddShadowWithOptions(context, dictionary);
        }
        
        // Get the blend mode and apply it to the context
        if ([options objectForKey: BlendModeParameterKey]) {
            TKContextSetBlendModeForString(context, [options objectForKey: BlendModeParameterKey]);
        }
        
        // Load in the fill color
        if ([options objectForKey: ColorParameterKey])
            CGContextSetFillColorWithColor(context, [UIColor colorForWebColor: [options objectForKey: ColorParameterKey]].CGColor);
        else
            CGContextSetFillColorWithColor(context, [UIColor whiteColor].CGColor);
        
        // Fill in the ellipse
        CGContextFillEllipseInRect(context, CGRectMake(origin.x, origin.y, size.width, size.height));
        
        CGContextRestoreGState(context);
        
        // Check if gradient is present, if so draw it over the fill
        if ([options objectForKey: GradientFillOptionKey]) {        
            CGContextSaveGState(context);
            
            // Gradient is present, clip to the ellipse
            CGContextAddEllipseInRect(context, CGRectMake(origin.x, origin.y, size.width, size.height));
            CGContextClip(context);
            
            // Draw the gradient
            NSDictionary *dictionary = [options objectForKey: GradientFillOptionKey];
            
            TKContextDrawGradientForOptions(context, dictionary, CGPointMake(origin.x, origin.y), CGPointMake(origin.x, origin.y + size.height));
            
            CGContextRestoreGState(context);
        }
        
        // Inner shadow
        if ([options objectForKey: InnerShadowOptionKey]) {
            CGContextSaveGState(context);
            
            NSDictionary *dictionary = [options objectForKey: InnerShadowOptionKey];
            
            // Start by clipping to the interior
            CGContextAddEllipseInRect(context, CGRectMake(origin.x, origin.y, size.width, size.height));
            
            CGContextClip(context);
            
            // Add bounding
            CGContextAddRect(context, CGContextGetClipBoundingBox(context));
            
            // Add shifted interior by the offset of the inner shadow
            CGContextAddEllipseInRect(context, CGRectMake(origin.x + [[[dictionary objectForKey: OffsetParameterKey] objectForKey: XCoordinateParameterKey] floatValue], 
                                                          origin.y + [[[dictionary objectForKey: OffsetParameterKey] objectForKey: YCoordinateParameterKey] floatValue], 
                                                          size.width, size.height));
            
            // Set the color and opacity
            if ([dictionary objectForKey: ColorParameterKey]) {
                CGContextSetFillColorWithColor(context, [UIColor colorForWebColor: [dictionary objectForKey: ColorParameterKey]].CGColor);
            }
            
            if ([dictionary objectForKey: AlphaParameterKey]) {
                CGContextSetAlpha(context, [[dictionary objectForKey: AlphaParameterKey] floatValue]);
            }
            
            // Set blend mode
            if ([dictionary objectForKey: BlendModeParameterKey]) {
                TKContextSetBlendModeForString(context, [dictionary objectForKey: BlendModeParameterKey]);
            }
            
            // Fill by using EO rule
            CGContextEOFillPath(context);
            
            CGContextRestoreGState(context);
        }
        
        // Strokes
        // Outer
        if ([options objectForKey: OuterStrokeOptionKey]) {
            CGContextSaveGState(context);
            
            // Parameters
            NSDictionary *dictionary = [options objectForKey: OuterStrokeOptionKey];
            
            // Stroke width
            CGFloat strokeWidth = [[dictionary objectForKey: WidthParameterKey] floatValue];
            
            // There is a stroke, add the ellipse to stroke
            CGContextAddEllipseInRect(context, CGRectMake(origin.x - strokeWidth / 2.0, origin.y - strokeWidth / 2.0, size.width + strokeWidth, size.height + strokeWidth));
            
            if ([dictionary objectForKey: AlphaParameterKey])
                CGContextSetAlpha(context, [[dictionary objectForKey: AlphaParameterKey] floatValue]);
            
            if ([dictionary objectForKey: ColorParameterKey])
                CGContextSetStrokeColorWithColor(context, [UIColor colorForWebColor: [dictionary objectForKey: ColorParameterKey]].CGColor);
            else
                CGContextSetStrokeColorWithColor(context, [UIColor blackColor].CGColor);
            
            // Stroke
            TKContextStrokePathWithOptions(context, dictionary);
            
            CGContextRestoreGState(context);
        }
        
        // Inner
        if ([options objectForKey: InnerStrokeOptionKey]) {
            CGContextSaveGState(context);
            
            // Parameters
            NSDictionary *dictionary = [options objectForKey: InnerStrokeOptionKey];
            
            // Stroke width
            CGFloat strokeWidth = [[dictionary objectForKey: WidthParameterKey] floatValue];
            
            // Add the ellipse
            CGContextAddEllipseInRect(context, CGRectMake(origin.x + strokeWidth / 2.0, origin.y + strokeWidth / 2.0, size.width - strokeWidth, size.height - strokeWidth));
            
            if ([dictionary objectForKey: AlphaParameterKey])
                CGContextSetAlpha(context, [[dictionary objectForKey: AlphaParameterKey] floatValue]);
            
            if ([dictionary objectForKey: ColorParameterKey])
                CGContextSetStrokeColorWithColor(context, [UIColor colorForWebColor: [dictionary objectForKey: ColorParameterKey]].CGColor);
            else
                CGContextSetStrokeColorWithColor(context, [UIColor blackColor].CGColor);
            
            // Stroke the path
            TKContextStrokePathWithOptions(context, dictionary);
            
            CGContextRestoreGState(context);
        }
    };
    
    // Store the block into cache
    if (_isCached)
        [_cache setObject: Block_copy(drawBlock) forKey: options];
    
    // Wrap up and create the view
    TKView *view = [TKView viewWithFrame: CGRectMake(canvasRect.origin.x, canvasRect.origin.y, 
                                                     canvasRect.size.width, canvasRect.size.height) 
                         andDrawingBlock: drawBlock];
        
    return view;
}

- (TKView *)pathAtOrigin: (CGPoint)start forOptions: (NSDictionary *)options {
    // Get the path described (__block as it will be mentioned within the drawingblock)
    __block CGMutablePathRef mainPath = [self pathForSVGSyntax: [options objectForKey: PathDescriptionKey]];
    
    // Keep note of any changes to the offset of drawing, this points to where, the main view should begin and how big it should be
    CGPoint origin = CGPointMake(0.0, 0.0);
    
    // Calculate the needed size for the rect
    CGRect bounding = CGPathGetBoundingBox(mainPath);
    
    // First determine the top left corner (the origin)
    CGPoint minBounding = bounding.origin;
    CGPoint topLeft = CGPointMake(MIN(minBounding.x, start.x), MIN(minBounding.y, start.y));
    CGPoint bottomRight = CGPointMake(CGRectGetMaxX(bounding), CGRectGetMaxY(bounding));
    CGRect frame = CGRectMake(topLeft.x, topLeft.y, bottomRight.x - topLeft.x, bottomRight.y - topLeft.y);
    
    // Store the size
    CGSize size = frame.size;
    
    // Adjust the drawing origin
    origin.x = topLeft.x - minBounding.x;
    origin.y = topLeft.y - minBounding.y;
    
    // Additionally keep track of the canvasrect, starts being the main frame
    CGRect canvasRect = frame;
    
    // If outer stroke, enlarge the frame
    if ([options objectForKey: OuterStrokeOptionKey]) {
        CGFloat strokeWidth = [[[options objectForKey: OuterStrokeOptionKey] objectForKey: WidthParameterKey] floatValue];
        
        // Create a stroke rect
        CGRect strokeRect = TKStrokeRectForRectAndWidth(frame, strokeWidth);
        
        // Find a union between the canvas and stroke rect
        canvasRect = CGRectUnion(canvasRect, strokeRect);
    }
    
    // If drop shadow is present adjust the size
    if ([options objectForKey: DropShadowOptionKey]) {
        // Create a special frame for the shadow
        NSDictionary *dictionary = [options objectForKey: DropShadowOptionKey];
        CGRect shadowRect = TKShadowRectForRectAndOptions(frame, dictionary);
        
        // Find the union between canvas and shadow
        canvasRect = CGRectUnion(canvasRect, shadowRect);
    }
    
    // Now as we have the frame, check cache for a view with same properties
    // As a key use the NSDictionary of the description
    if (_isCached && [_cache objectForKey: options]) {
        TKDrawingBlock drawBlock = [_cache objectForKey: options];
        TKView *view = [TKView viewWithFrame: CGRectMake(canvasRect.origin.x, canvasRect.origin.y, 
                                                         canvasRect.size.width, canvasRect.size.height)
                             andDrawingBlock: drawBlock];
        
        return view;
    }
    
    // Adjust the inner origin, this is where the actual view is located
    origin.x = frame.origin.x - canvasRect.origin.x;
    origin.y = frame.origin.y - canvasRect.origin.y;
    
    // Create the drawing block
    TKDrawingBlock drawBlock = ^(CGContextRef context) {
        // Drawing code
        // Start with the main inner view
        CGContextSaveGState(context);
        
        // Adjust the path for the origin
        CGAffineTransform transform = CGAffineTransformMakeTranslation(origin.x, origin.y);
        mainPath = CGPathCreateMutableCopyByTransformingPath(mainPath, &transform);
        [(id)mainPath autorelease];
        CGContextAddPath(context, mainPath);
        
        // If shadow needed, draw it
        if ([options objectForKey: DropShadowOptionKey]) {
            NSDictionary *dictionary = [options objectForKey: DropShadowOptionKey];        
            TKContextAddShadowWithOptions(context, dictionary);
        }
        
        // Alpha
        if ([options objectForKey: AlphaParameterKey]) {
            CGContextSetAlpha(context, [[options objectForKey: AlphaParameterKey] floatValue]);
        }
        
        // Check if blend mode is present
        if ([options objectForKey: BlendModeParameterKey]) {
            // Get the blend mode and apply it to the context
            TKContextSetBlendModeForString(context, [options objectForKey: BlendModeParameterKey]);
        }
        
        // Load in the fill color
        if ([options objectForKey: ColorParameterKey])
            CGContextSetFillColorWithColor(context, [UIColor colorForWebColor: [options objectForKey: ColorParameterKey]].CGColor);
        else
            CGContextSetFillColorWithColor(context, [UIColor whiteColor].CGColor);
        
        // Fill the path
        CGContextFillPath(context);
        
        CGContextRestoreGState(context);
        
        // Check if gradient is present, if so draw it over the fill
        if ([options objectForKey: GradientFillOptionKey]) {        
            CGContextSaveGState(context);
            
            // Gradient is present, first clip the context
            CGContextAddPath(context, mainPath);
            CGContextClip(context);
            
            // Draw the gradient
            NSDictionary *dictionary = [options objectForKey: GradientFillOptionKey];
            
            TKContextDrawGradientForOptions(context, dictionary, CGPointMake(origin.x, origin.y), CGPointMake(origin.x, origin.y + size.height));
            
            CGContextRestoreGState(context);
        }
        
        // Inner shadow
        if ([options objectForKey: InnerShadowOptionKey]) {
            CGContextSaveGState(context);
            
            NSDictionary *dictionary = [options objectForKey: InnerShadowOptionKey];
            
            // Start by clipping to the interior
            CGContextAddPath(context, mainPath);            
            CGContextClip(context);
            
            // Add bounding
            CGContextAddRect(context, CGContextGetClipBoundingBox(context));
            
            // Add shifted interior by the offset of the inner shadow
            NSDictionary *offset = [dictionary objectForKey: OffsetParameterKey];
            CGAffineTransform transform = CGAffineTransformMakeTranslation([[offset objectForKey: XCoordinateParameterKey] floatValue],
                                                                           [[offset objectForKey: YCoordinateParameterKey] floatValue]);
            CGPathRef transformedPath = CGPathCreateCopyByTransformingPath(mainPath, &transform);
            CGContextAddPath(context, transformedPath);
            CGPathRelease(transformedPath);
            
            // Set the color and opacity
            if ([dictionary objectForKey: ColorParameterKey]) {
                CGContextSetFillColorWithColor(context, [UIColor colorForWebColor: [dictionary objectForKey: ColorParameterKey]].CGColor);
            }
            
            if ([dictionary objectForKey: AlphaParameterKey]) {
                CGContextSetAlpha(context, [[dictionary objectForKey: AlphaParameterKey] floatValue]);
            }
            
            // Set blend mode
            if ([dictionary objectForKey: BlendModeParameterKey]) {
                TKContextSetBlendModeForString(context, [dictionary objectForKey: BlendModeParameterKey]);
            }
            
            // Fill by using EO rule
            CGContextEOFillPath(context);
            
            CGContextRestoreGState(context);
        }
        
        // Strokes
        // Outer
        if ([options objectForKey: OuterStrokeOptionKey]) {
            CGContextSaveGState(context);
            
            // Parameters
            NSDictionary *dictionary = [options objectForKey: OuterStrokeOptionKey];
            
            // There is a stroke, add the path to stroke
            CGContextAddPath(context, mainPath);
            
            if ([dictionary objectForKey: AlphaParameterKey])
                CGContextSetAlpha(context, [[dictionary objectForKey: AlphaParameterKey] floatValue]);
            
            if ([dictionary objectForKey: ColorParameterKey])
                CGContextSetStrokeColorWithColor(context, [UIColor colorForWebColor: [dictionary objectForKey: ColorParameterKey]].CGColor);
            
            // Stroke
            TKContextStrokePathWithOptions(context, dictionary);
            
            CGContextRestoreGState(context);
        }
    };   
    
    // Cache the block if needed
    if (_isCached) 
        [_cache setObject: Block_copy(drawBlock) forKey: options];
    
    // Create and return the view
    TKView *view = [TKView viewWithFrame: CGRectMake(canvasRect.origin.x, canvasRect.origin.y, 
                                                     canvasRect.size.width, canvasRect.size.height)
                         andDrawingBlock: drawBlock];
    
    return view;
}

#pragma mark - Path related

- (CGMutablePathRef)pathForSVGSyntax:(NSString *)description {
    // First convert the string into commands
    NSArray *commands = [self arrayOfPathCommandsFromSVGDescription: description];
    
    // Create the path
    CGMutablePathRef path = CGPathCreateMutable();
    
    // Now iterate over the commands
    CGPoint endPoint;
    CGPoint controlPoint1;
    CGPoint controlPoint2;
    for (TKPathCommand *command in commands) {
        switch ([command command]) {
            case TKMoveTo:
                endPoint = [command endPoint]; 
                CGPathMoveToPoint(path, NULL, endPoint.x, endPoint.y);
                break;
            case TKLineTo:
                endPoint = [command endPoint];
                CGPathAddLineToPoint(path, NULL, endPoint.x, endPoint.y);
                break;
            case TKCubicBezier:
                endPoint = [command endPoint];
                controlPoint1 = [command controlPoint1];
                controlPoint2 = [command controlPoint2];
                CGPathAddCurveToPoint(path, NULL, controlPoint1.x, controlPoint1.y, controlPoint2.x, controlPoint2.y, endPoint.x, endPoint.y);
                break;
            case TKQuadBezier:
                endPoint = [command endPoint];
                controlPoint1 = [command controlPoint1];
                CGPathAddQuadCurveToPoint(path, NULL, controlPoint1.x, controlPoint1.y, endPoint.x, endPoint.y);
                break;
            case TKClosePath:
                CGPathCloseSubpath(path);
                break;
            default:
                break;
        }
    }
    
    [(id)path autorelease];
    return path;
}

- (NSArray *)arrayOfPathCommandsFromSVGDescription: (NSString *)description {
    // Create a scanner for scanning the description
    NSScanner *scanner = [NSScanner scannerWithString: description];
    
    // The array of commands
    NSMutableArray *commands = [NSMutableArray array];
    
    // The character set that represents any non-relevant character in the SVG syntax
    NSCharacterSet *relevant = [NSCharacterSet characterSetWithCharactersInString: @"+-0123456789MmZzLlHhVvCcSsQqTt"];
    NSCharacterSet *nonrelevant = [relevant invertedSet];
    
    // Make the scanner scan over everything irrelevant
    [scanner setCharactersToBeSkipped: nonrelevant];
    
    // Keep pointers to the latest used values, 
    CGPoint currentLocation = CGPointMake(0.0, 0.0);

    // Create an empty pointer to a string
    NSString *temp;
    
    // Scan the string until we reach the end of it
    while (![scanner isAtEnd]) {
        // First grab the starting letter
        [scanner scanCharactersFromSet: [NSCharacterSet letterCharacterSet] intoString: &temp];
        
        // Depending on the letter decide whether the command is relative or absolute
        NSString *uppercase = [temp uppercaseString];
        BOOL relative = ![uppercase isEqualToString: temp];    // If it's uppercase, then it's not relative
        
        // Assign the command, based on the letter
        TKPathCommand *command = [[[TKPathCommand alloc] init] autorelease];
        if ([uppercase isEqualToString: @"M"]) {
            [command setCommand: TKMoveTo];
            
            // Scan in the numbers
            CGPoint pointHolder = relative ? [self pointFromScanner: scanner relativeToPoint: currentLocation] : [self pointFromScanner: scanner relativeToPoint: CGPointZero];

            // Adjust the command and store it in the array
            [command setEndPoint: pointHolder];
            [commands addObject: command];
            
            // Move the current absolute location
            currentLocation = pointHolder;
                                    
            // Now check if any numbers follow, if so, additional commands are required
            NSUInteger location = [scanner scanLocation];
            while ([scanner scanFloat: NULL]) {
                [scanner setScanLocation: location];
                
                pointHolder = relative ? [self pointFromScanner: scanner relativeToPoint: currentLocation] : [self pointFromScanner: scanner relativeToPoint: CGPointZero];
                
                TKPathCommand *additionalCommand = [[[TKPathCommand alloc] initWithCommand: TKLineTo] autorelease];
                [additionalCommand setEndPoint: pointHolder];
                [commands addObject: additionalCommand];
                
                // Move the current location
                currentLocation = pointHolder;
                                
                // Store the location
                location = [scanner scanLocation];
            }
        } else if ([uppercase isEqualToString: @"Z"]) {
            [command setCommand: TKClosePath];
            
            // Closepath has nothing else to it, add it to the commands
            [commands addObject: command];
        } else if ([uppercase isEqualToString: @"L"]) {
            [command setCommand: TKLineTo];
            
            // Find out the line point
            CGPoint pointHolder = relative ? [self pointFromScanner: scanner relativeToPoint: currentLocation] : [self pointFromScanner: scanner relativeToPoint: CGPointZero];
            
            // Adjust the command and store it in the array
            [command setEndPoint: pointHolder];
            [commands addObject: command];
            
            // Move current position
            currentLocation = pointHolder;
                        
            // Now check if any numbers follow, if so, additional commands are required
            NSUInteger location = [scanner scanLocation];
            while ([scanner scanFloat: NULL]) {
                [scanner setScanLocation: location];
                
                pointHolder = relative ? [self pointFromScanner: scanner relativeToPoint: currentLocation] : [self pointFromScanner: scanner relativeToPoint: CGPointZero];
                
                TKPathCommand *additionalCommand = [[[TKPathCommand alloc] initWithCommand: TKLineTo] autorelease];
                [additionalCommand setEndPoint: pointHolder];
                [commands addObject: additionalCommand];
                
                // Move the current location
                currentLocation = pointHolder;
                
                // Store the location
                location = [scanner scanLocation];
            }
        } else if ([uppercase isEqualToString: @"H"]) {
            [command setCommand: TKLineTo];
                        
            // Only a single number follows
            float nextFloat;
            [scanner scanFloat: &nextFloat];
            
            // Put together the point
            CGPoint pointHolder = relative ? CGPointMake(currentLocation.x + nextFloat, currentLocation.y) : CGPointMake(nextFloat, currentLocation.y);
            
            // Adjust the command and the current location
            [command setEndPoint: pointHolder];
            currentLocation = pointHolder;
            
            // Store the command
            [commands addObject: command];
                        
            // Now check if any numbers follow, if so, additional commands are required
            while ([scanner scanFloat: &nextFloat]) {
                // Get the Y coordinate and create the command
                pointHolder.x = relative ? currentLocation.x + nextFloat : nextFloat;
                
                TKPathCommand *additionalCommand = [[[TKPathCommand alloc] initWithCommand: TKLineTo] autorelease];
                [additionalCommand setEndPoint: pointHolder];
                [commands addObject: additionalCommand];
                
                // Move the current location
                currentLocation = pointHolder;
            }
        } else if ([uppercase isEqualToString: @"V"]) {
            [command setCommand: TKLineTo];
                        
            // Only a single number follows
            float nextFloat;
            [scanner scanFloat: &nextFloat];
            
            // Put together the point
            CGPoint pointHolder = relative ? CGPointMake(currentLocation.x, currentLocation.y + nextFloat) : CGPointMake(currentLocation.x, nextFloat);
            
            // Adjust the command and the current location
            [command setEndPoint: pointHolder];
            currentLocation = pointHolder;
            
            // Store the command
            [commands addObject: command];
                        
            // Now check if any numbers follow, if so, additional commands are required
            while ([scanner scanFloat: &nextFloat]) {
                // Get the Y coordinate and create the command
                pointHolder.y = relative ? currentLocation.y + nextFloat : nextFloat;
                
                TKPathCommand *additionalCommand = [[[TKPathCommand alloc] initWithCommand: TKLineTo] autorelease];
                [additionalCommand setEndPoint: pointHolder];
                [commands addObject: additionalCommand];
                
                // Move the current location
                currentLocation = pointHolder;
            }
        } else if ([uppercase isEqualToString: @"C"]) {
            [command setCommand: TKCubicBezier];
                        
            // First control point
            CGPoint pointHolder = relative ? [self pointFromScanner: scanner relativeToPoint: currentLocation] : [self pointFromScanner: scanner relativeToPoint: CGPointZero];
            [command setControlPoint1: pointHolder];
                        
            // Second control point
            pointHolder = relative ? [self pointFromScanner: scanner relativeToPoint: currentLocation] : [self pointFromScanner: scanner relativeToPoint: CGPointZero];
            [command setControlPoint2: pointHolder];
                        
            // End point
            pointHolder = relative ? [self pointFromScanner: scanner relativeToPoint: currentLocation] : [self pointFromScanner: scanner relativeToPoint: CGPointZero];
            [command setEndPoint: pointHolder];
            
            // Move the current location
            currentLocation = pointHolder;
            
            // Store the command
            [commands addObject: command];
                        
            // Loop around if more are present
            NSUInteger location = [scanner scanLocation];
            while ([scanner scanFloat: NULL]) {
                // There are more curves present, at least one is here
                // Back up the scanner
                [scanner setScanLocation: location];
                
                // Additional command
                TKPathCommand *additionalCommand = [[[TKPathCommand alloc] initWithCommand: TKCubicBezier] autorelease];
                
                // First control point
                CGPoint pointHolder = relative ? [self pointFromScanner: scanner relativeToPoint: currentLocation] : [self pointFromScanner: scanner relativeToPoint: CGPointZero];
                [additionalCommand setControlPoint1: pointHolder];
                                
                // Second control point
                pointHolder = relative ? [self pointFromScanner: scanner relativeToPoint: currentLocation] : [self pointFromScanner: scanner relativeToPoint: CGPointZero];
                [additionalCommand setControlPoint2: pointHolder];
                                
                // End point
                pointHolder = relative ? [self pointFromScanner: scanner relativeToPoint: currentLocation] : [self pointFromScanner: scanner relativeToPoint: CGPointZero];
                [additionalCommand setEndPoint: pointHolder];
                
                // Move the current location
                currentLocation = pointHolder;
                                
                // Store the command
                [commands addObject: additionalCommand];
                
                // Store the location
                location = [scanner scanLocation];
            }
        } else if ([uppercase isEqualToString: @"S"]) {
            [command setCommand: TKCubicBezier];
            
            // As this is a "smooth" version, we need to see whether the previous command was a Cubic Bezier or not
            TKPathCommand *lastCommand = [commands lastObject];
            
            // Check if smoothing is available
            if ([lastCommand command] == TKCubicBezier) {
                // We can make it smooth, means we need to find out the last control point and reflect it
                CGPoint previousControlPoint = [lastCommand controlPoint2];
                
                CGSize offset = CGSizeMake(currentLocation.x - previousControlPoint.x, currentLocation.y - previousControlPoint.y);
                
                CGPoint nextControlPoint = CGPointMake(currentLocation.x + offset.width, currentLocation.y + offset.height);
                [command setControlPoint1: nextControlPoint];
            } else {
                [command setControlPoint1: currentLocation];
            }
                        
            // Second control point
            CGPoint pointHolder = relative ? [self pointFromScanner: scanner relativeToPoint: currentLocation] : [self pointFromScanner: scanner relativeToPoint: CGPointZero];
            [command setControlPoint2: pointHolder];
                        
            // End point
            pointHolder = relative ? [self pointFromScanner: scanner relativeToPoint: currentLocation] : [self pointFromScanner: scanner relativeToPoint: CGPointZero];
            [command setEndPoint: pointHolder];
            
            // Store the command
            [commands addObject: command];
            
            // Move the current point
            currentLocation = pointHolder;
                        
            // Loop around if more are present
            NSUInteger location = [scanner scanLocation];
            
            // Adjust the controlpoint to be reflective of the second controlPoint
            CGPoint previousControlPoint = [command controlPoint2];
            while ([scanner scanFloat: NULL]) {
                // There are more curves present, at least one is here
                // Back up the scanner
                [scanner setScanLocation: location];
                
                // Additional command
                TKPathCommand *additionalCommand = [[[TKPathCommand alloc] initWithCommand: TKCubicBezier] autorelease];
                
                // First control point, as this is supposed to be smooth, it has to be relative to the second control point of the previous curve
                CGSize offset = CGSizeMake(currentLocation.x - previousControlPoint.x, currentLocation.y - previousControlPoint.y);
                
                CGPoint nextControlPoint = CGPointMake(currentLocation.x + offset.width, currentLocation.y + offset.height);
                [additionalCommand setControlPoint1: nextControlPoint];
                                
                // Second control point
                pointHolder = relative ? [self pointFromScanner: scanner relativeToPoint: currentLocation] : [self pointFromScanner: scanner relativeToPoint: CGPointZero];
                [additionalCommand setControlPoint2: pointHolder];
                previousControlPoint = pointHolder;
                                
                // End point
                pointHolder = relative ? [self pointFromScanner: scanner relativeToPoint: currentLocation] : [self pointFromScanner: scanner relativeToPoint: CGPointZero];
                [additionalCommand setEndPoint: pointHolder];
                
                // Move the current location
                currentLocation = pointHolder;
                                
                // Store the command
                [commands addObject: additionalCommand];
                
                // Store the location
                location = [scanner scanLocation];
            }
        } else if ([uppercase isEqualToString: @"Q"]) {
            [command setCommand: TKQuadBezier];
                        
            // Control point
            CGPoint pointHolder = relative ? [self pointFromScanner: scanner relativeToPoint: currentLocation] : [self pointFromScanner: scanner relativeToPoint: CGPointZero];
            [command setControlPoint1: pointHolder];
                                    
            // End point
            pointHolder = relative ? [self pointFromScanner: scanner relativeToPoint: currentLocation] : [self pointFromScanner: scanner relativeToPoint: CGPointZero];
            [command setEndPoint: pointHolder];
            
            // Move the current location
            currentLocation = pointHolder;
            
            // Store the command
            [commands addObject: command];
                        
            // Loop around if more are present
            NSUInteger location = [scanner scanLocation];
            while ([scanner scanFloat: NULL]) {
                // There are more curves present, at least one is here
                // Back up the scanner
                [scanner setScanLocation: location];
                
                // Additional command
                TKPathCommand *additionalCommand = [[[TKPathCommand alloc] initWithCommand: TKQuadBezier] autorelease];
                
                // Control point
                CGPoint pointHolder = relative ? [self pointFromScanner: scanner relativeToPoint: currentLocation] : [self pointFromScanner: scanner relativeToPoint: CGPointZero];
                [additionalCommand setControlPoint1: pointHolder];
                                                
                // End point
                pointHolder = relative ? [self pointFromScanner: scanner relativeToPoint: currentLocation] : [self pointFromScanner: scanner relativeToPoint: CGPointZero];
                [additionalCommand setEndPoint: pointHolder];
                
                // Move the current location
                currentLocation = pointHolder;
                
                // Store the command
                [commands addObject: additionalCommand];
                
                // Store the location
                location = [scanner scanLocation];
            }
        } else if ([uppercase isEqualToString: @"T"]) {
            [command setCommand: TKQuadBezier];
                        
            // As this is a "smooth" version, we need to see whether the previous command was a Cubic Bezier or not
            TKPathCommand *lastCommand = [commands lastObject];
            
            // Check if smoothing is available
            if ([lastCommand command] == TKQuadBezier) {
                // We can make it smooth, means we need to find out the last control point
                CGPoint previousControlPoint = [lastCommand controlPoint2];
                
                CGSize offset = CGSizeMake(currentLocation.x - previousControlPoint.x, currentLocation.y - previousControlPoint.y);
                
                CGPoint nextControlPoint = CGPointMake(currentLocation.x + offset.width, currentLocation.y + offset.height);
                [command setControlPoint1: nextControlPoint];
            } else {
                [command setControlPoint1: currentLocation];
            }
                                    
            // End point
            CGPoint pointHolder = relative ? [self pointFromScanner: scanner relativeToPoint: currentLocation] : [self pointFromScanner: scanner relativeToPoint: CGPointZero];
            [command setEndPoint: pointHolder];
            
            // Store the command
            [commands addObject: command];
            
            // Move the current point
            currentLocation = pointHolder;
                        
            // Loop around if more are present
            NSUInteger location = [scanner scanLocation];
            
            // Adjust the controlpoint to be reflective of the second controlPoint
            CGPoint previousControlPoint = [command controlPoint1];
            while ([scanner scanFloat: NULL]) {
                // There are more curves present, at least one is here
                // Back up the scanner
                [scanner setScanLocation: location];
                
                // Additional command
                TKPathCommand *additionalCommand = [[[TKPathCommand alloc] initWithCommand: TKQuadBezier] autorelease];
                
                // Control point, as this is supposed to be smooth, it has to be relative to the second control point of the previous curve
                CGSize offset = CGSizeMake(currentLocation.x - previousControlPoint.x, currentLocation.y - previousControlPoint.y);
                
                CGPoint nextControlPoint = CGPointMake(currentLocation.x + offset.width, currentLocation.y + offset.height);
                [additionalCommand setControlPoint1: nextControlPoint];
                previousControlPoint = nextControlPoint;
                                
                // End point
                pointHolder = relative ? [self pointFromScanner: scanner relativeToPoint: currentLocation] : [self pointFromScanner: scanner relativeToPoint: CGPointZero];
                [additionalCommand setEndPoint: pointHolder];
                
                // Move the current location
                currentLocation = pointHolder;
                                
                // Store the command
                [commands addObject: additionalCommand];
                
                // Store the location
                location = [scanner scanLocation];
            }
        } else {
            // Error, unknown command
            NSLog(@"Syntax error, path drawing command \"%@\" does not exist", temp);
            return nil;
        }
    }
    
    return [NSArray arrayWithArray: commands];
}

- (CGPoint)pointFromScanner: (NSScanner *)scanner relativeToPoint: (CGPoint)currentPoint {
    // If not relative just pass in CGPointZero as the relativeToPoint, making it absolute
    NSCharacterSet *numerical = [NSCharacterSet characterSetWithCharactersInString: @"+-0123456789"];
    
    // Scan in the numbers, ignoring anything in the middle
    CGPoint pointHolder = CGPointZero;
    float nextFloat;
    [scanner scanFloat: &nextFloat];
    pointHolder.x = nextFloat;
    
    // Skip anything not numerical and or not numerical signs, because there has to be a next float in there
    [scanner scanUpToCharactersFromSet: numerical intoString: NULL];
    
    // Scan the second part of the coordinate and form it
    [scanner scanFloat: &nextFloat];
    pointHolder.y = nextFloat;
    pointHolder = CGPointMake(currentPoint.x + pointHolder.x, currentPoint.y + pointHolder.y);
    
    return pointHolder;
}

#pragma mark - Cache

- (void)flushCache {    
    // Simply empty out the cache dictionary
    if (_isCached) {
        [_cache removeAllObjects];
    }
}

@end

#pragma mark - Implementation

@implementation ThemeKit

// Singleton and initialization
+ (ThemeKit *)defaultEngine {
    static dispatch_once_t pred;
    static ThemeKit *shared = nil;
        
    dispatch_once(&pred, ^{
        shared = [[ThemeKit alloc] init];
    });
    
    return shared;
}

- (id)init {
    self = [super init];
    
    if (self) {
        _isCached = YES;
        _cache = [[NSMutableDictionary alloc] init];
                
        // Observe notification about memory warning
        [[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(flushCache) name: UIApplicationDidReceiveMemoryWarningNotification object: nil];
    }
    
    return self;
}

- (UIView *)viewHierarchyForJSONAtPath:(NSString *)path {
    // Check the cache for the path, if present return the view right away
    if (_isCached && [_cache objectForKey: path])
        return [_cache objectForKey: path];
    
    // Not present
    UIView *view = [self viewHierarchyFromJSON: [NSData dataWithContentsOfFile: path]];
    
    if (_isCached)
        [_cache setObject: view forKey: path];
    
    return view;
}

// View creation
- (UIView *)viewHierarchyFromJSON: (NSData *)JSONData {
    // First deserialize the JSON
    // If NSJSONSerialization is available, prefer that, if not, fall back to JSONKit
    // NSJSONSerialization has benefits, such as speed, but also future support in iOS
    NSDictionary *JSONDictionary;
    if (NSClassFromString(@"NSJSONSerialization")) {
        NSError *error = nil;
        JSONDictionary = [NSJSONSerialization JSONObjectWithData: JSONData options: 0 error: &error];
        
        if (error) {
            NSLog(@"NSJSONSerialization error while parsing JSON: %@", [error description]);
        }
    } else {
        JSONDictionary = [[JSONDecoder decoder] objectWithData: JSONData];
    }
    
    // If cache enabled, search for the view
    if (_isCached && [_cache objectForKey: JSONData])
        return [_cache objectForKey: JSONData];
    
    // Next get the size parameters of the main dictionary - that is the size of outermost view
    CGSize size;
    if ([JSONDictionary objectForKey: SizeParameterKey]) {
        size = CGSizeMake([[[JSONDictionary objectForKey: SizeParameterKey] objectForKey: WidthParameterKey] floatValue],
                         [[[JSONDictionary objectForKey: SizeParameterKey] objectForKey: HeightParameterKey] floatValue]);
    } else {
        NSLog(@"Error! No size specified for the outermost view, will result in no view being drawn");
        size = CGSizeZero;
    }
    
    // Grab the origin, if present
    CGPoint origin;
    if ([JSONDictionary objectForKey: OriginParameterKey]) {
        origin = CGPointMake([[[JSONDictionary objectForKey: OriginParameterKey] objectForKey: XCoordinateParameterKey] floatValue],
                             [[[JSONDictionary objectForKey: OriginParameterKey] objectForKey: YCoordinateParameterKey] floatValue]);
    } else {
        // No origin means default to 0.0 0.0
        origin = CGPointZero;
    }
    
    // Create the container view
    UIView *view = [[[UIView alloc] initWithFrame: CGRectMake(origin.x, origin.y, size.width, size.height)] autorelease];
    [view setBackgroundColor: [UIColor clearColor]];
    
    if (view) {
        // Grab the subviews
        NSArray *options = [JSONDictionary objectForKey: SubviewSectionKey];
        
        // Add them all as subviews
        [self addSubviewsWithDescriptions: options toView: view];
    }
    
    // If cache enabled, store the final view (additional layer of caching, incase an identical view hierarchy is used later)
    if (_isCached) {
        [_cache setObject: view forKey: JSONData];
    }
        
    return view;
}

- (UIImage *)compressedImageForView: (UIView *)view {
    // Create a suitable context and draw the view's layer into it (iOS 4 > uses the scaled version)
    if (NULL != UIGraphicsBeginImageContextWithOptions)
        UIGraphicsBeginImageContextWithOptions(view.frame.size, NO, [[UIScreen mainScreen] scale]);
    else
        UIGraphicsBeginImageContext(view.frame.size);
    
    // Grab the context
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    // -renderInContext: renders in the coordinate space of the layer,
    // so we must first apply the layer's geometry to the graphics context 
    // (i.e move the context to where the layer is)
    CGContextSaveGState(context);
    // Center the context around the view's anchor point
    //CGContextTranslateCTM(context, [view center].x, [view center].y);
    // Apply the view's transform about the anchor point
    //CGContextConcatCTM(context, [view transform]);
    // Offset by the portion of the bounds left of and above the anchor point
    /*CGContextTranslateCTM(context, 
                          -[view bounds].size.width * [[view layer] anchorPoint].x,
                          -[view bounds].size.height * [[view layer] anchorPoint].y);*/
    
    // Render the layer hierarchy to the current context
    [[view layer] renderInContext:context];
    
    // Restore the context
    CGContextRestoreGState(context);
    
    // Retrieve the screenshot image
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    
    UIGraphicsEndImageContext();
    
    NSLog(@"View frame: %@ image size: %@", NSStringFromCGRect(view.frame), NSStringFromCGSize(image.size));
    
    return image;
}

- (void)dealloc {
    // Remove observer for the memory warning
    [[NSNotificationCenter defaultCenter] removeObserver: self name: UIApplicationDidReceiveMemoryWarningNotification object: nil];
    
    [_cache release];
    [super dealloc];
}

@end