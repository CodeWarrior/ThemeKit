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

- (UIView *)viewHierarchyForJSONDictionary: (NSDictionary *)JSON bindings: (NSDictionary **)bindings;

#pragma mark - Factory methods

- (UIView *)addSubviewsWithDescriptions: (NSArray *)descriptions toView: (UIView *)view bindings: (NSMutableDictionary *)bindings;
- (UIView *)viewForDescription: (NSDictionary *)description bindings: (NSMutableDictionary *)bindings;

#pragma mark - Quick images

- (UIImage *)patternGradientForGradientProperties: (NSDictionary *)properties height: (NSInteger)height;

#pragma mark - Primitives
- (TKView *)rectangleInFrame: (CGRect)frame options: (NSDictionary *)options;      // Rectangle
- (TKView *)circleInFrame: (CGRect)frame options: (NSDictionary *)options;         // Circle
- (TKView *)pathForOptions: (NSDictionary *)options;      // Path
- (UILabel *)labelInFrame: (CGRect)frame forOptions: (NSDictionary *)options;
- (UIButton *)buttonInFrame: (CGRect)frame forOptions: (NSDictionary *)options;

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

#pragma mark - Drawing Implementation

@implementation ThemeKit (DrawingExtensions)

- (UIView *)viewHierarchyForJSONDictionary: (NSDictionary *)JSON bindings: (NSDictionary **)bindings {
    // Create a dictionary into the bindings
    NSMutableDictionary *bindDictionary = nil;
    if (bindings != NULL) {
        bindDictionary = [NSMutableDictionary dictionary];
    }
    
    // Next get the size parameters of the main dictionary - that is the size of outermost view
    CGSize size;
    if ([JSON objectForKey: SizeParameterKey]) {
        size = CGSizeMake([[[JSON objectForKey: SizeParameterKey] objectForKey: WidthParameterKey] floatValue],
                          [[[JSON objectForKey: SizeParameterKey] objectForKey: HeightParameterKey] floatValue]);
    } else {
        NSLog(@"Error! No size specified for the outermost view, will result in no view being drawn");
        size = CGSizeZero;
    }
    
    // Grab the origin, if present
    CGPoint origin;
    if ([JSON objectForKey: OriginParameterKey]) {
        origin = CGPointMake([[[JSON objectForKey: OriginParameterKey] objectForKey: XCoordinateParameterKey] floatValue],
                             [[[JSON objectForKey: OriginParameterKey] objectForKey: YCoordinateParameterKey] floatValue]);
    } else {
        // No origin means default to 0.0 0.0
        origin = CGPointZero;
    }
    
    // Create the container view
    UIView *view = [[[UIView alloc] initWithFrame: CGRectMake(origin.x, origin.y, size.width, size.height)] autorelease];
    [view setBackgroundColor: [UIColor clearColor]];
    
    if (view) {
        // Grab the subviews
        NSArray *options = [JSON objectForKey: SubviewSectionKey];
        
        // Add them all as subviews
        [self addSubviewsWithDescriptions: options toView: view bindings: bindDictionary];
    }
    
    // Check if there is a binding
    if ([JSON objectForKey: BindingVariableName] && bindings != NULL) {
        [bindDictionary setObject: view forKey: [JSON objectForKey: BindingVariableName]];
    }
    
    // IF there is a binding, move the temporary dictionary to the final one
    if (bindings != NULL && [bindDictionary count] > 0) {
        *bindings = [NSDictionary dictionaryWithDictionary: bindDictionary];
    }
    
    return view;
}

#pragma mark - Factory methods

- (UIView *)addSubviewsWithDescriptions: (NSArray *)descriptions toView: (UIView *)view bindings: (NSMutableDictionary *)bindings {    
    // Keep track of the size, in case the subviews have shadows or strokes that otherwise would extend outside
    // our frame
    CGSize finalSize = CGSizeMake(CGRectGetWidth(view.frame), CGRectGetHeight(view.frame));
    
    // Iterate over the descriptions and add the views as subviews
    for (NSDictionary *viewDesc in descriptions) {
        // Add the subview
        UIView *subview = [self viewForDescription: viewDesc bindings: bindings];
        
        if ([view isKindOfClass: [UIButton class]]) {
            [subview setExclusiveTouch: NO];
            [subview setUserInteractionEnabled: NO];
        }
        
        [view insertSubview: subview atIndex: [descriptions indexOfObject: viewDesc] + 1];
        
        // Adjust the finalsize
        finalSize.width = MAX(finalSize.width, CGRectGetWidth(subview.frame));
        finalSize.height = MAX(finalSize.height, CGRectGetHeight(subview.frame));
    }
    
    // Adjust the view so that it matches the contents
    CGRect frame = view.frame;
    frame.size = finalSize;
    view.frame = frame;
    
    return view;
}

- (UIView *)viewForDescription: (NSDictionary *)description bindings: (NSMutableDictionary *)bindings {
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
        if ([description objectForKey: ContainerParameterKey]) {
            if ([[description objectForKey: ContainerParameterKey] boolValue]) {
                result = [[[UIView alloc] initWithFrame: frame] autorelease];
            } else {
                result = [self rectangleInFrame: frame options: description];
            }
        } else {
            result = [self rectangleInFrame: frame options: description];
        }
    } else if ([type isEqualToString: EllipseTypeKey]) {
        result = [self circleInFrame: frame options: description];
    } else if ([type isEqualToString: PathTypeKey]) {
        result = [self pathForOptions: description];
    } else if ([type isEqualToString: LabelTypeKey]) {
        result = [self labelInFrame: frame forOptions: description];
    } else if ([type isEqualToString: ButtonTypeKey]) {
        result = [self buttonInFrame: frame forOptions: description];
    } else {
        NSLog(@"Unknown type \"%@\" encountered, ignoring", type);
        return nil;
    }
    
    // Check if there is a binding
    if ([description objectForKey: BindingVariableName] && bindings) {
        // Store the view into the binding dictionary
        [bindings setObject: result forKey: [description objectForKey: BindingVariableName]];
    }
    
    // Check for additional subviews
    if ([description objectForKey: SubviewSectionKey]) {
        [self addSubviewsWithDescriptions: [description objectForKey: SubviewSectionKey] toView: result bindings: bindings];
    }
    
    return result;
}

#pragma mark - Quick images

- (UIImage *)patternGradientForGradientProperties: (NSDictionary *)properties height: (NSInteger)height { 
    // Start by creating the JSON description
    NSDictionary *size = [NSDictionary dictionaryWithObjectsAndKeys: [NSNumber numberWithInt: 3], WidthParameterKey, 
                          [NSNumber numberWithInteger: height], HeightParameterKey, nil];    
    NSDictionary *view = [NSDictionary dictionaryWithObjectsAndKeys: RectangleTypeKey, TypeParameterKey, 
                                                                                 size, SizeParameterKey,
                                                                           properties, GradientFillOptionKey, nil];
        
    // Create the image
    UIImage *image = [self compressedImageForView: 
                      [self viewForDescription: view bindings: NULL]];
    
    // Make it stretchable
    image = [image stretchableImageWithLeftCapWidth: 1.0 topCapHeight: height - 1.0];
    
    return image;
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
        TKView *result = [TKView viewWithFrame: CGRectMake(frame.origin.x - origin.x, frame.origin.y - origin.y, 
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
    TKView *view = [TKView viewWithFrame: CGRectMake(frame.origin.x - origin.x, frame.origin.y - origin.y, 
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
    
    // Adjust the inner origin, this is where the actual view is located
    origin.x = frame.origin.x - canvasRect.origin.x;
    origin.y = frame.origin.y - canvasRect.origin.y;
    
    // Check cache
    if (_isCached && [_cache objectForKey: options]) {
        TKDrawingBlock block = [_cache objectForKey: options];
        
        TKView *view = [TKView viewWithFrame: CGRectMake(frame.origin.x - origin.x, frame.origin.y - origin.x, 
                                                         canvasRect.size.width, canvasRect.size.height)
                             andDrawingBlock: block];
        
        return view;
    }
    
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
    TKView *view = [TKView viewWithFrame: CGRectMake(frame.origin.x - origin.x, frame.origin.y - origin.y, 
                                                     canvasRect.size.width, canvasRect.size.height) 
                         andDrawingBlock: drawBlock];
        
    return view;
}

- (TKView *)pathForOptions: (NSDictionary *)options {
    CGMutablePathRef mainPath = [self pathForSVGSyntax: [options objectForKey: PathDescriptionKey]];
    
    // Keep note of any changes to the offset of drawing, this points to where, the main view should begin and how big it should be
    CGPoint origin = CGPointMake(0.0, 0.0);
    
    // Calculate the needed size for the rect
    CGRect bounding = CGPathGetBoundingBox(mainPath);
    
    // Store the size
    CGSize size = bounding.size;
    
    // Additionally keep track of the canvasrect, starts being the main frame
    CGRect canvasRect = bounding;
    
    // If outer stroke, enlarge the frame
    if ([options objectForKey: OuterStrokeOptionKey]) {
        CGFloat strokeWidth = [[[options objectForKey: OuterStrokeOptionKey] objectForKey: WidthParameterKey] floatValue];
        
        // Create a stroke rect
        CGRect strokeRect = TKStrokeRectForRectAndWidth(bounding, strokeWidth);
        
        // Find a union between the canvas and stroke rect
        canvasRect = CGRectUnion(canvasRect, strokeRect);
    }
    
    // If drop shadow is present adjust the size
    if ([options objectForKey: DropShadowOptionKey]) {
        // Create a special frame for the shadow
        NSDictionary *dictionary = [options objectForKey: DropShadowOptionKey];
        CGRect shadowRect = TKShadowRectForRectAndOptions(bounding, dictionary);
        
        // Find the union between canvas and shadow
        canvasRect = CGRectUnion(canvasRect, shadowRect);
    }
    
    // Adjust the inner origin, this is where the actual view is located
    origin.x = bounding.origin.x - canvasRect.origin.x;
    origin.y = bounding.origin.y - canvasRect.origin.y;

    // Now as we have the frame, check cache for a view with same properties
    // As a key use the NSDictionary of the description
    if (_isCached && [_cache objectForKey: options]) {
        TKDrawingBlock drawBlock = [_cache objectForKey: options];
        TKView *view = [TKView viewWithFrame: canvasRect
                             andDrawingBlock: drawBlock];
        return view;
    }
    
    // Transform the path to the new origin
    CGAffineTransform transform = CGAffineTransformMakeTranslation(-bounding.origin.x + origin.x, -bounding.origin.y + origin.y);
    __block CGPathRef adjustedPath = CGPathCreateCopyByTransformingPath(mainPath, &transform);
    
    // Create the drawing block
    TKDrawingBlock drawBlock = ^(CGContextRef context) {
        // Drawing code
        // Start with the main inner view
        CGContextSaveGState(context);
        
        // Retain the path and add it to the context for filling
        CGContextAddPath(context, adjustedPath);
        
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
            CGContextAddPath(context, adjustedPath);
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
            CGContextAddPath(context, adjustedPath);            
            CGContextClip(context);
            
            // Add bounding
            CGContextAddRect(context, CGContextGetClipBoundingBox(context));
            
            // Add shifted interior by the offset of the inner shadow
            NSDictionary *offset = [dictionary objectForKey: OffsetParameterKey];
            CGAffineTransform transform = CGAffineTransformMakeTranslation([[offset objectForKey: XCoordinateParameterKey] floatValue],
                                                                           [[offset objectForKey: YCoordinateParameterKey] floatValue]);
            CGPathRef transformedPath = CGPathCreateCopyByTransformingPath(adjustedPath, &transform);
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
            CGContextAddPath(context, adjustedPath);
            
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
    TKView *view = [TKView viewWithFrame: canvasRect
                         andDrawingBlock: drawBlock];
    
    return view;
}

- (UILabel *)labelInFrame: (CGRect)frame forOptions: (NSDictionary *)description {
    UILabel *label = [[[UILabel alloc] initWithFrame: frame] autorelease];
    
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
    if ([description objectForKey: ContentColorParameterKey]) {
        label.textColor = [UIColor colorForWebColor: [description objectForKey: ContentColorParameterKey]];
    }
    
    // Background color
    if ([description objectForKey: ColorParameterKey]) {
        label.backgroundColor = [UIColor colorForWebColor: [description objectForKey: ColorParameterKey]];
    } else {
        label.backgroundColor = [UIColor clearColor];
    }
    
    // Gradient fill
    if ([description objectForKey: GradientFillOptionKey]) {
        // Compose the gradient from the colors and positions
        UIImage *pattern = [self patternGradientForGradientProperties: [description objectForKey: GradientFillOptionKey] height: frame.size.height];
        
        [label setTextColor: [UIColor colorWithPatternImage: pattern]];
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
        NSDictionary *shadow = [description objectForKey: DropShadowOptionKey];
        
        if ([shadow objectForKey: ColorParameterKey])
            label.shadowColor = [UIColor colorForWebColor: [shadow objectForKey: ColorParameterKey]];
        else
            label.shadowColor = [UIColor blackColor];
        
        if ([shadow objectForKey: AlphaParameterKey]) {
            label.shadowColor = [label.shadowColor colorWithAlphaComponent: [[shadow objectForKey: AlphaParameterKey] floatValue]];
        }
        
        NSDictionary *offset = [shadow objectForKey: OffsetParameterKey];
        label.shadowOffset = CGSizeMake([[offset objectForKey: XCoordinateParameterKey] floatValue],
                                        [[offset objectForKey: YCoordinateParameterKey] floatValue]);
    } else if ([description objectForKey: ContentShadowParameterKey]) {
        NSDictionary *shadow = [description objectForKey: ContentShadowParameterKey];
        
        if ([shadow objectForKey: ColorParameterKey])
            label.shadowColor = [UIColor colorForWebColor: [shadow objectForKey: ColorParameterKey]];
        else
            label.shadowColor = [UIColor blackColor];
        
        if ([shadow objectForKey: AlphaParameterKey]) {
            label.shadowColor = [label.shadowColor colorWithAlphaComponent: [[shadow objectForKey: AlphaParameterKey] floatValue]];
        }
        
        NSDictionary *offset = [shadow objectForKey: OffsetParameterKey];
        label.shadowOffset = CGSizeMake([[offset objectForKey: XCoordinateParameterKey] floatValue],
                                        [[offset objectForKey: YCoordinateParameterKey] floatValue]);
    }
    
    return label;
}

- (UIButton *)buttonInFrame: (CGRect)frame forOptions: (NSDictionary *)description {
    // A button, start by seeing if there are images
    // (if there is at least one, will use the custom type not the default rounded)
    BOOL custom = NO;
    
    NSMutableDictionary *states = [NSMutableDictionary dictionaryWithCapacity: 4]; // 4 is the max size
    NSMutableDictionary *stateImages = [NSMutableDictionary dictionaryWithCapacity: 4];
    
    // Normal state
    if ([description objectForKey: ButtonNormalStateView]) {
        custom = YES;
        
        NSDictionary *button = [description objectForKey: ButtonNormalStateView];
        
        // Check if there's a view
        if ([button objectForKey: SizeParameterKey]) {
            
            // Generate the view for the button and compress it into an image
            UIImage *image = [self compressedImageForView: 
                              [self viewForDescription: button bindings: NULL]];

            if ([button objectForKey: ButtonViewStretchable]) {
                // It is, the stretchable property contains 2 values, the left and top cap widths
                NSArray *values = [button objectForKey: ButtonViewStretchable];
                CGFloat top = [[values objectAtIndex: 1] floatValue];
                CGFloat left = [[values objectAtIndex: 0] floatValue];
                
                // Make the image stretchable
                image = [image stretchableImageWithLeftCapWidth: left topCapHeight: top];
            }
            
            // Check if an image is present
            if ([button objectForKey: ButtonContentImage]) {
                // There's an image, render and compress it
                UIImage *contentImage = [self compressedImageForView: [self viewForDescription: [button objectForKey: ButtonContentImage] bindings: NULL]];
                [stateImages setObject: contentImage forKey: ButtonNormalStateView];
            }
            
            // Assign the image to the correct state
            [states setObject: image forKey: ButtonNormalStateView];
        }
    }
    
    // Highlighted state
    if ([description objectForKey: ButtonHighlightedStateView]) {
        custom = YES;
        
        NSDictionary *button = [description objectForKey: ButtonHighlightedStateView];
        
        // Grab the view and compress it to an image
        if ([button objectForKey: SizeParameterKey]) {
            UIImage *image = [self compressedImageForView: [self viewForDescription: button bindings: NULL]];
            
            // Check if it's stretchable
            if ([button objectForKey: ButtonViewStretchable]) {
                // It is, the stretchable property contains 2 values, the left and top cap widths
                NSArray *values = [button objectForKey: ButtonViewStretchable];
                CGFloat top = [[values objectAtIndex: 1] floatValue];
                CGFloat left = [[values objectAtIndex: 0] floatValue];
                
                // Make the image stretchable
                image = [image stretchableImageWithLeftCapWidth: left topCapHeight: top];
            }
            
            // Check if an image is present
            if ([button objectForKey: ButtonContentImage]) {
                // There's an image, render and compress it
                UIImage *image = [self compressedImageForView: [self viewForDescription: [button objectForKey: ButtonContentImage] bindings: NULL]];
                [stateImages setObject: image forKey: ButtonHighlightedStateView];
            }
            
            // Assign the image to the key in the dictionary
            [states setObject: image forKey: ButtonHighlightedStateView];
        }
    }
    
    // Selected view
    if ([description objectForKey: ButtonSelectedStateView]) {
        custom = YES;
        
        NSDictionary *button = [description objectForKey: ButtonSelectedStateView];
        
        // Grab the view and compress it to an image
        if ([button objectForKey: SizeParameterKey]) {
            UIImage *image = [self compressedImageForView: [self viewForDescription: button bindings: NULL]];
            
            // Check if it's stretchable
            if ([button objectForKey: ButtonViewStretchable]) {
                // It is, the stretchable property contains 2 values, the left and top cap widths
                NSArray *values = [button objectForKey: ButtonViewStretchable];
                CGFloat top = [[values objectAtIndex: 1] floatValue];
                CGFloat left = [[values objectAtIndex: 0] floatValue];
                
                // Make the image stretchable
                image = [image stretchableImageWithLeftCapWidth: left topCapHeight: top];
            }
            
            // Check if an image is present
            if ([button objectForKey: ButtonContentImage]) {
                // There's an image, render and compress it
                UIImage *image = [self compressedImageForView: [self viewForDescription: [button objectForKey: ButtonContentImage] bindings: NULL]];
                [stateImages setObject: image forKey: ButtonSelectedStateView];
            }
            
            // Assign the image to the key in the dictionary
            [states setObject: image forKey: ButtonSelectedStateView];
        }
    }

    // Selected highlighted view
    if ([description objectForKey: ButtonHighlightedSelectedStateView]) {
        custom = YES;
        
        NSDictionary *button = [description objectForKey: ButtonHighlightedSelectedStateView];
        
        // Grab the view and compress it to an image
        if ([button objectForKey: SizeParameterKey]) {
            UIImage *image = [self compressedImageForView: [self viewForDescription: button bindings: NULL]];
            
            // Check if it's stretchable
            if ([button objectForKey: ButtonViewStretchable]) {
                // It is, the stretchable property contains 2 values, the left and top cap widths
                NSArray *values = [button objectForKey: ButtonViewStretchable];
                CGFloat top = [[values objectAtIndex: 1] floatValue];
                CGFloat left = [[values objectAtIndex: 0] floatValue];
                
                // Make the image stretchable
                image = [image stretchableImageWithLeftCapWidth: left topCapHeight: top];
            }
            
            // Check if an image is present
            if ([button objectForKey: ButtonContentImage]) {
                // There's an image, render and compress it
                UIImage *image = [self compressedImageForView: [self viewForDescription: [button objectForKey: ButtonContentImage] bindings: NULL]];
                [stateImages setObject: image forKey: ButtonHighlightedSelectedStateView];
            }
            
            // Assign the image to the key in the dictionary
            [states setObject: image forKey: ButtonHighlightedSelectedStateView];
        }
    }
    
    // Disabled view
    if ([description objectForKey: ButtonDisabledStateView]) {
        custom = YES;
        
        NSDictionary *button = [description objectForKey: ButtonDisabledStateView];
        
        // Grab the view and compress it to an image
        if ([button objectForKey: SizeParameterKey]) {
            // There is a size, means there is a view to draw
            UIImage *image = [self compressedImageForView: [self viewForDescription: button bindings: NULL]];
            
            // Check if it's stretchable
            if ([button objectForKey: ButtonViewStretchable]) {
                // It is, the stretchable property contains 2 values, the left and top cap widths
                NSArray *values = [button objectForKey: ButtonViewStretchable];
                CGFloat top = [[values objectAtIndex: 1] floatValue];
                CGFloat left = [[values objectAtIndex: 0] floatValue];
                
                // Make the image stretchable
                image = [image stretchableImageWithLeftCapWidth: left topCapHeight: top];
            }
            
            // Check if an image is present
            if ([button objectForKey: ButtonContentImage]) {
                // There's an image, render and compress it
                UIImage *image = [self compressedImageForView: [self viewForDescription: [button objectForKey: ButtonContentImage] bindings: NULL]];
                [stateImages setObject: image forKey: ButtonDisabledStateView];
            }
            
            // Assign the image to the key in the dictionary
            [states setObject: image forKey: ButtonDisabledStateView];
        }
    }
    
    // Create the button
    UIButton *button;
    if (custom) {
        button = [UIButton buttonWithType: UIButtonTypeCustom];
    } else
        button = [UIButton buttonWithType: UIButtonTypeRoundedRect];
    
    
    // Adjust content shadow
    if ([description objectForKey: ContentShadowParameterKey]) {
        NSDictionary *textShadow = [description objectForKey: ContentShadowParameterKey];
        if ([textShadow objectForKey: ColorParameterKey]) {
            UIColor *color = [UIColor colorForWebColor: [textShadow objectForKey: ColorParameterKey]];
            
            if ([textShadow objectForKey: AlphaParameterKey]) {
                color = [color colorWithAlphaComponent: [[textShadow objectForKey: AlphaParameterKey] floatValue]];
            }
            
            [button setTitleShadowColor: color forState: UIControlStateNormal];
        }
        
        if ([textShadow objectForKey: OffsetParameterKey]) {
            button.titleLabel.shadowOffset = CGSizeMake([[[textShadow objectForKey: OffsetParameterKey] 
                                                          objectForKey: XCoordinateParameterKey] floatValue],
                                                        [[[textShadow objectForKey: OffsetParameterKey]
                                                          objectForKey: YCoordinateParameterKey] floatValue]);
        }
    }
    
    // Adjust font
    // Font size & Font
    if ([description objectForKey: ContentFontSizeParameterKey]) {
        button.titleLabel.font = [UIFont systemFontOfSize: [[description objectForKey: ContentFontSizeParameterKey] floatValue]];
    }
    
    // Add the text
    if ([description objectForKey: ContentStringParameterKey])
        [button setTitle: [description objectForKey: ContentStringParameterKey] forState: UIControlStateNormal];
    
    if ([description objectForKey: ContentFontWeightParameterKey]) {
        NSString *weight = [description objectForKey: ContentFontWeightParameterKey];
        
        if ([weight isEqualToString: @"bold"]) {
            button.titleLabel.font = [UIFont boldSystemFontOfSize: button.titleLabel.font.pointSize];
        } else {
            button.titleLabel.font = [UIFont systemFontOfSize: button.titleLabel.font.pointSize];
        }
    } else if ([description objectForKey: ContentFontNameParameterKey]) {
        button.titleLabel.font = [UIFont fontWithName: [description objectForKey: ContentFontNameParameterKey] size: button.titleLabel.font.pointSize];
    }
    
    // Adjust every custom state, this means images, titles and colors, shadows etc.
    if ([description objectForKey: ButtonNormalStateView]) {
        NSDictionary *normal = [description objectForKey: ButtonNormalStateView];
        
        // Handle text color, shadow color and so on
        if ([normal objectForKey: ContentColorParameterKey]) {
            [button setTitleColor: [UIColor colorForWebColor: [normal objectForKey: ContentColorParameterKey]] 
                         forState: UIControlStateNormal];
        }
        
        if ([normal objectForKey: ContentShadowParameterKey]) {
            NSDictionary *textShadow = [normal objectForKey: ContentShadowParameterKey];
            if ([textShadow objectForKey: ColorParameterKey]) {
                UIColor *color = [UIColor colorForWebColor: [textShadow objectForKey: ColorParameterKey]];
                
                if ([textShadow objectForKey: AlphaParameterKey]) {
                    color = [color colorWithAlphaComponent: [[textShadow objectForKey: AlphaParameterKey] floatValue]];
                }
                
                [button setTitleShadowColor: color forState: UIControlStateNormal];
            }
        }
        
        if ([normal objectForKey: ContentStringParameterKey])
            [button setTitle: [normal objectForKey: ContentStringParameterKey] forState: UIControlStateNormal];
        
        if ([normal objectForKey: ContentGradientParameterKey]) {
            // Apply a gradient to the text
            UIImage *gradient = [self patternGradientForGradientProperties: [normal objectForKey: ContentGradientParameterKey]
                                                                    height: button.titleLabel.frame.size.height];
            
            [button setTitleColor: [UIColor colorWithPatternImage: gradient] forState: UIControlStateNormal];
        }
        
        if ([stateImages objectForKey: ButtonNormalStateView])
            [button setImage: [stateImages objectForKey: ButtonNormalStateView] forState: UIControlStateNormal];
        
        if ([states objectForKey: ButtonNormalStateView])
            [button setBackgroundImage: [states objectForKey: ButtonNormalStateView] forState: UIControlStateNormal];     
    }
    
    if ([description objectForKey: ButtonHighlightedStateView]) {
        NSDictionary *highlighted = [description objectForKey: ButtonHighlightedStateView];
        
        // Handle text color, shadow color and so on
        if ([highlighted objectForKey: ContentColorParameterKey]) {
            [button setTitleColor: [UIColor colorForWebColor: [highlighted objectForKey: ContentColorParameterKey]] 
                         forState: UIControlStateHighlighted | UIControlStateSelected];
        }
        
        if ([highlighted objectForKey: ContentShadowParameterKey]) {
            NSDictionary *textShadow = [highlighted objectForKey: ContentShadowParameterKey];
            if ([textShadow objectForKey: ColorParameterKey]) {
                UIColor *color = [UIColor colorForWebColor: [textShadow objectForKey: ColorParameterKey]];
                
                if ([textShadow objectForKey: AlphaParameterKey]) {
                    color = [color colorWithAlphaComponent: [[textShadow objectForKey: AlphaParameterKey] floatValue]];
                }
                
                [button setTitleShadowColor: color forState: UIControlStateHighlighted | UIControlStateSelected];
            }
        }
        
        if ([highlighted objectForKey: ContentStringParameterKey]) {
            [button setTitle: [highlighted objectForKey: ContentStringParameterKey] forState: UIControlStateHighlighted | UIControlStateSelected];
            [button setTitle: [highlighted objectForKey: ContentStringParameterKey] forState: UIControlStateHighlighted];
        }
        
        // Handle text color, shadow color and so on
        if ([highlighted objectForKey: ContentColorParameterKey]) {
            [button setTitleColor: [UIColor colorForWebColor: [highlighted objectForKey: ContentColorParameterKey]] 
                         forState: UIControlStateHighlighted];
        }
        
        if ([highlighted objectForKey: ContentShadowParameterKey]) {
            NSDictionary *textShadow = [highlighted objectForKey: ContentShadowParameterKey];
            if ([textShadow objectForKey: ColorParameterKey]) {
                UIColor *color = [UIColor colorForWebColor: [textShadow objectForKey: ColorParameterKey]];
                
                if ([textShadow objectForKey: AlphaParameterKey]) {
                    color = [color colorWithAlphaComponent: [[textShadow objectForKey: AlphaParameterKey] floatValue]];
                }
                
                [button setTitleShadowColor: color forState: UIControlStateHighlighted];
            }
        }
        
        // Check for content gradient, if one is present apply to the label
        if ([highlighted objectForKey: ContentGradientParameterKey]) {
            UIImage *image = [self patternGradientForGradientProperties: [highlighted objectForKey: ContentGradientParameterKey] 
                                                                 height: button.titleLabel.frame.size.height];
            
            [button setTitleColor: [UIColor colorWithPatternImage: image] forState: UIControlStateHighlighted];
            [button setTitleColor: [UIColor colorWithPatternImage: image] forState: UIControlStateHighlighted | UIControlStateSelected];
        }
        
        if ([stateImages objectForKey: ButtonHighlightedStateView]) {
            [button setImage: [stateImages objectForKey: ButtonHighlightedStateView] forState: UIControlStateHighlighted | UIControlStateSelected];
            [button setImage: [stateImages objectForKey: ButtonHighlightedStateView] forState: UIControlStateHighlighted];
        }
        
        if ([states objectForKey: ButtonHighlightedStateView]) {
            [button setBackgroundImage: [states objectForKey: ButtonHighlightedStateView] forState: UIControlStateHighlighted | UIControlStateSelected];
            [button setBackgroundImage: [states objectForKey: ButtonHighlightedStateView] forState: UIControlStateHighlighted];
        }
    }
    
    if ([description objectForKey: ButtonDisabledStateView]) {
        NSDictionary *disabled = [description objectForKey: ButtonDisabledStateView];
        
        // Handle text color, shadow color and so on
        if ([disabled objectForKey: ContentColorParameterKey]) {
            [button setTitleColor: [UIColor colorForWebColor: [disabled objectForKey: ContentColorParameterKey]] 
                         forState: UIControlStateDisabled];
        }
        
        if ([disabled objectForKey: ContentShadowParameterKey]) {
            NSDictionary *textShadow = [disabled objectForKey: ContentShadowParameterKey];
            if ([textShadow objectForKey: ColorParameterKey]) {
                UIColor *color = [UIColor colorForWebColor: [textShadow objectForKey: ColorParameterKey]];
                
                if ([textShadow objectForKey: AlphaParameterKey]) {
                    color = [color colorWithAlphaComponent: [[textShadow objectForKey: AlphaParameterKey] floatValue]];
                }
                
                [button setTitleShadowColor: color forState: UIControlStateDisabled];
            }
        }
        
        if ([disabled objectForKey: ContentStringParameterKey])
            [button setTitle: [disabled objectForKey: ContentStringParameterKey] forState: UIControlStateDisabled];
        
        // Check for content gradient, if present apply to the title
        if ([disabled objectForKey: ContentGradientParameterKey]) {
            UIImage *image = [self patternGradientForGradientProperties: [disabled objectForKey: ContentGradientParameterKey]
                                                                 height: button.titleLabel.frame.size.height];
            
            [button setTitleColor: [UIColor colorWithPatternImage: image] forState: UIControlStateDisabled];
        }
        
        if ([states objectForKey: ButtonDisabledStateView]) {
            [button setBackgroundImage: [states objectForKey: ButtonDisabledStateView] forState: UIControlStateDisabled];
        }
        
        if ([stateImages objectForKey: ButtonContentImage]) {
            [button setImage: [stateImages objectForKey: ButtonDisabledStateView] forState: UIControlStateDisabled];
        }
    }
    
    if ([description objectForKey: ButtonSelectedStateView]) {
        NSDictionary *selected = [description objectForKey: ButtonSelectedStateView];
        
        // Handle text color, shadow color and so on
        if ([selected objectForKey: ContentColorParameterKey]) {
            [button setTitleColor: [UIColor colorForWebColor: [selected objectForKey: ContentColorParameterKey]] 
                         forState: UIControlStateSelected];
        }
        
        if ([selected objectForKey: ContentShadowParameterKey]) {
            NSDictionary *textShadow = [selected objectForKey: ContentShadowParameterKey];
            if ([textShadow objectForKey: ColorParameterKey]) {
                UIColor *color = [UIColor colorForWebColor: [textShadow objectForKey: ColorParameterKey]];
                
                if ([textShadow objectForKey: AlphaParameterKey]) {
                    color = [color colorWithAlphaComponent: [[textShadow objectForKey: AlphaParameterKey] floatValue]];
                }
                
                [button setTitleShadowColor: color forState: UIControlStateSelected];
            }
        }
        
        if ([selected objectForKey: ContentStringParameterKey])
            [button setTitle: [selected objectForKey: ContentStringParameterKey] forState: UIControlStateSelected];
        
        // Check for content gradient
        if ([selected objectForKey: ContentGradientParameterKey]) {
            UIImage *image = [self patternGradientForGradientProperties: [selected objectForKey: ContentGradientParameterKey]
                                                                 height: button.titleLabel.frame.size.height];
            
            [button setTitleColor: [UIColor colorWithPatternImage: image] forState: UIControlStateSelected];
        }
        
        if ([stateImages objectForKey: ButtonSelectedStateView])
            [button setImage: [stateImages objectForKey: ButtonSelectedStateView] forState: UIControlStateSelected];
        
        if ([states objectForKey: ButtonSelectedStateView])
            [button setBackgroundImage: [states objectForKey: ButtonSelectedStateView] forState: UIControlStateSelected];
    }

    if ([description objectForKey: ButtonHighlightedSelectedStateView]) {
        NSDictionary *selected = [description objectForKey: ButtonHighlightedSelectedStateView];
        
        // Handle text color, shadow color and so on
        if ([selected objectForKey: ContentColorParameterKey]) {
            [button setTitleColor: [UIColor colorForWebColor: [selected objectForKey: ContentColorParameterKey]] 
                         forState: UIControlStateHighlighted | UIControlStateSelected];
        }
        
        if ([selected objectForKey: ContentShadowParameterKey]) {
            NSDictionary *textShadow = [selected objectForKey: ContentShadowParameterKey];
            if ([textShadow objectForKey: ColorParameterKey]) {
                UIColor *color = [UIColor colorForWebColor: [textShadow objectForKey: ColorParameterKey]];
                
                if ([textShadow objectForKey: AlphaParameterKey]) {
                    color = [color colorWithAlphaComponent: [[textShadow objectForKey: AlphaParameterKey] floatValue]];
                }
                
                [button setTitleShadowColor: color forState: UIControlStateHighlighted | UIControlStateSelected];
            }
        }
        
        if ([selected objectForKey: ContentStringParameterKey])
            [button setTitle: [selected objectForKey: ContentStringParameterKey] forState: UIControlStateHighlighted | UIControlStateSelected];
        
        // Check for content gradient
        if ([selected objectForKey: ContentGradientParameterKey]) {
            UIImage *image = [self patternGradientForGradientProperties: [selected objectForKey: ContentGradientParameterKey]
                                                                 height: button.titleLabel.frame.size.height];
            
            [button setTitleColor: [UIColor colorWithPatternImage: image] forState: UIControlStateHighlighted | UIControlStateSelected];
        }
        
        if ([stateImages objectForKey: ButtonHighlightedSelectedStateView])
            [button setImage: [stateImages objectForKey: ButtonHighlightedSelectedStateView] forState: UIControlStateHighlighted | UIControlStateSelected];
        
        if ([states objectForKey: ButtonHighlightedSelectedStateView])
            [button setBackgroundImage: [states objectForKey: ButtonHighlightedSelectedStateView] forState: UIControlStateHighlighted | UIControlStateSelected];
    }

    // Check the insets (image)
    if ([[description objectForKey: ButtonContentImageInsets] isKindOfClass: [NSArray class]]) {
        // We have an array of values
        NSArray *values = [description objectForKey: ButtonContentImageInsets];
        UIEdgeInsets insets = UIEdgeInsetsMake([[values objectAtIndex: 0] floatValue], [[values objectAtIndex: 1] floatValue],
                                                   [[values objectAtIndex: 2] floatValue], [[values objectAtIndex: 3] floatValue]);
        [button setImageEdgeInsets: insets];
    } else if ([description objectForKey: ButtonContentImageInsets]) {
        // One value, meant for them all
        CGFloat inset = [[description objectForKey: ButtonContentImageInsets] floatValue];
        [button setImageEdgeInsets: UIEdgeInsetsMake(inset, inset, inset, inset)];
    }
    
    // General
    if ([[description objectForKey: ButtonContentInsets] isKindOfClass: [NSArray class]]) {
        // We have an array of values
        NSArray *values = [description objectForKey: ButtonContentInsets];
        UIEdgeInsets insets = UIEdgeInsetsMake([[values objectAtIndex: 0] floatValue], [[values objectAtIndex: 1] floatValue],
                                               [[values objectAtIndex: 2] floatValue], [[values objectAtIndex: 3] floatValue]);
        [button setContentEdgeInsets: insets];
    } else if ([description objectForKey: ButtonContentInsets]) {
        // One value, meant for all edges
        CGFloat inset = [[description objectForKey: ButtonContentInsets] floatValue];
        [button setContentEdgeInsets: UIEdgeInsetsMake(inset, inset, inset, inset)];
    }
        
    // Set the frame of the button
    [button setFrame: frame];
    
    return button;
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
    // Simply empty out the cache dictionaries
    [_cache removeAllObjects];
    [_JSONCache removeAllObjects];
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
        _JSONCache = [[NSMutableDictionary alloc] init];
                
        // Observe notification about memory warning
        [[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(flushCache) name: UIApplicationDidReceiveMemoryWarningNotification object: nil];
    }
    
    return self;
}

- (UIView *)viewHierarchyForJSONAtPath:(NSString *)path bindings: (NSDictionary **)bindings {   
    // Check the cache first for JSON
    if (_isCached && [_JSONCache objectForKey: path]) {
        return [self viewHierarchyForJSONDictionary: [_JSONCache objectForKey: path] bindings: bindings];
    }
    
    // Convert the JSON into a NSDictionary
    // If NSJSONSerialization is available, prefer that, if not, fall back to JSONKit
    // NSJSONSerialization has benefits, such as speed, but also future support in iOS
    NSDictionary *JSONDictionary;
    NSData *JSONData = [NSData dataWithContentsOfFile: path];
    
    if (NSClassFromString(@"NSJSONSerialization")) {
        NSError *error = nil;
        JSONDictionary = [NSJSONSerialization JSONObjectWithData: JSONData options: 0 error: &error];
        
        if (error) {
            NSLog(@"NSJSONSerialization error while parsing JSON: %@", [error description]);
        }
    } else {
        JSONDictionary = [[JSONDecoder decoder] objectWithData: JSONData];
    }
    
    // Cache the JSON
    if (_isCached) {
        [_JSONCache setObject: JSONDictionary forKey: path];
    }
       
    // And return a brand new view with the JSON
    // - this is to avoid returning a view that is already in use
    return [self viewHierarchyForJSONDictionary: JSONDictionary bindings: bindings];
}

// View creation
- (UIView *)viewHierarchyFromJSON: (NSData *)JSONData bindings: (NSDictionary **)bindings {
    // First deserialize the JSON, this method does not cache the resulting JSON dictionary
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
    
    return [self viewHierarchyForJSONDictionary: JSONDictionary bindings: bindings];
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
        
    return image;
}

- (void)dealloc {
    // Remove observer for the memory warning
    [[NSNotificationCenter defaultCenter] removeObserver: self name: UIApplicationDidReceiveMemoryWarningNotification object: nil];
    
    [_cache release];
    [_JSONCache release];
    [super dealloc];
}

@end