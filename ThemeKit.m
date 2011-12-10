//
//  ThemeView.m
//  ThemeEngine
//
//  Created by Henri Normak on 13/11/2011.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "ThemeKit.h"
#import "TKPathCommand.h"

#pragma mark - UIColor Extension

@interface UIColor (Extensions)

// Method for converting web hex color into a UIColor object, pass in a string similar to "FFFFFF" or "#FFFFFF"
// If less than six characters long, will be used as a pattern - "FFA" will result in "FFAFFA" and "FFFA" results in "FFFAFF"
+ (UIColor *)colorForWebColor: (NSString *)colorCode;

@end

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

@end

#pragma mark - Drawing Extension

@interface ThemeKit (DrawingExtensions)

// General processing
- (NSArray *)viewsForDescriptions: (NSArray *)descriptions;

// Primitive shapes
- (UIImageView *)rectangleInFrame: (CGRect)frame options: (NSDictionary *)options;      // Rectangle
- (UIImageView *)circleInFrame: (CGRect)frame options: (NSDictionary *)options;         // Circle
- (UIImageView *)lineFromPoint: (CGPoint)fromPoint toPoint: (CGPoint)toPoint options: (NSDictionary *)options;    // Line
- (UIImageView *)pathInFrame: (CGRect)frame options: (NSDictionary *)options;

// Paths, following SVG standard syntax
- (CGMutablePathRef)newPathForSVGSyntax: (NSString *)description;

// Helpers
- (void)balanceCornerRadiuses: (CGFloat *)radii toFitIntoSize: (CGSize)size;
- (CGMutablePathRef)newRoundedPathForRect: (CGRect)rect withRadiuses: (CGFloat *)radii;
- (CGGradientRef)newGradientForColors: (NSArray *)CGColors andLocations: (CGFloat[])locations;
- (CGBlendMode)blendModeForString: (NSString *)key;

// SVG Paths, returns an array of TKPathCommand objects, 
// containing instructions on how to draw the description
- (NSArray *)arrayOfPathCommandsFromSVGDescription: (NSString *)description;
- (CGPoint)pointFromScanner: (NSScanner *)scanner relativeToPoint: (CGPoint)currentPoint;

// Drawing
- (CGRect)shadowRectForRect: (CGRect)frame andOptions: (NSDictionary *)options;
- (CGRect)strokeRectForRect: (CGRect)frame andWidth: (CGFloat)strokeWidth;

// Cache
- (void)flushCache;

@end

@implementation ThemeKit (DrawingExtensions)

- (NSArray *)viewsForDescriptions: (NSArray *)descriptions {
    // Create a mutable array to store the subviews in
    NSMutableArray *subviews = [NSMutableArray arrayWithCapacity: [descriptions count]];
    
    // Enumerate over the descriptions, use concurrent enumeration to get a speed boost
    [descriptions enumerateObjectsWithOptions: NSEnumerationConcurrent
                                   usingBlock:^(id obj, NSUInteger idx, BOOL *stop) {                                       
                        // All the views will be represented by dictionaries
                        NSDictionary *view = (NSDictionary *)obj;
                                
                        // First start by identifying the type of the view
                        NSString *type = [view objectForKey: TypeParameterKey];
                                
                        // Get the frame of the view, they all need to have it = it's type independent (line is an exception)
                        CGRect frame = CGRectZero;
                        if (![type isEqualToString: LineTypeKey]) {
                            frame = CGRectMake([[[view objectForKey: OriginParameterKey] objectForKey: XCoordinateParameterKey] floatValue],
                                                [[[view objectForKey: OriginParameterKey] objectForKey: YCoordinateParameterKey] floatValue],
                                                [[[view objectForKey: SizeParameterKey] objectForKey: WidthParameterKey] floatValue],
                                                [[[view objectForKey: SizeParameterKey] objectForKey: HeightParameterKey] floatValue]);
                        }
                                
                        // Depending on the type use the appropriate drawing method
                        if ([type isEqualToString: RectangleTypeKey]) {
                            UIImageView *rectangle = [self rectangleInFrame: frame options: view];
                            
                            // Insert at the specific index, to guarantee correct ordering of layers
                            [subviews insertObject: rectangle atIndex: idx];
                            
                            // Check for additional subviews
                            if ([view objectForKey: SubviewSectionKey]) {
                                NSArray *nested = [self viewsForDescriptions: [view objectForKey: SubviewSectionKey]];
                                
                                [nested enumerateObjectsWithOptions: NSEnumerationConcurrent
                                                         usingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                                    [rectangle insertSubview: obj atIndex: idx];
                                }];
                            }
                        } else if ([type isEqualToString: CircleTypeKey]) {
                            UIImageView *circle = [self circleInFrame: frame options: view];
                            
                            // Insert to appropriate index
                            [subviews insertObject: circle atIndex: idx];
                            
                            // Check for additional subviews
                            if ([view objectForKey: SubviewSectionKey]) {
                                NSArray *nested = [self viewsForDescriptions: [view objectForKey: SubviewSectionKey]];
                                
                                [nested enumerateObjectsWithOptions: NSEnumerationConcurrent
                                                         usingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                                    [circle insertSubview: obj atIndex: idx];
                                }];
                            }
                        } else if ([type isEqualToString: LineTypeKey]) {
                            // Extract the two points
                            NSDictionary *start = [view objectForKey: StartPointParameterKey];
                            CGPoint startPoint = CGPointMake([[start objectForKey: XCoordinateParameterKey] floatValue], [[start objectForKey: YCoordinateParameterKey] floatValue]);
                            
                            NSDictionary *end = [view objectForKey: EndPointParameterKey];
                            CGPoint endPoint = CGPointMake([[end objectForKey: XCoordinateParameterKey] floatValue], [[end objectForKey: YCoordinateParameterKey] floatValue]);
                            
                            UIImageView *line = [self lineFromPoint: startPoint toPoint: endPoint options: view];
                            [subviews insertObject: line atIndex: idx];
                        } else if ([type isEqualToString: LabelTypeKey]) {
                            UILabel *label = [[[UILabel alloc] initWithFrame: frame] autorelease];
                            label.backgroundColor = [UIColor clearColor];
                            
                            // Content
                            if ([view objectForKey: ContentStringParameterKey]) {
                                label.text = [view objectForKey: ContentStringParameterKey];
                            }
                            
                            // Alignment
                            if ([view objectForKey: ContentAlignmentParameterKey]) {
                                NSString *alignment = [view objectForKey: ContentAlignmentParameterKey];
                                if ([alignment isEqualToString: @"center"]) {
                                    label.textAlignment = UITextAlignmentCenter;
                                } else if ([alignment isEqualToString: @"left"]) {
                                    label.textAlignment = UITextAlignmentLeft;
                                } else if ([alignment isEqualToString: @"right"]) {
                                    label.textAlignment = UITextAlignmentRight;
                                }
                            }
                            
                            // Text color
                            if ([view objectForKey: ColorParameterKey]) {
                                label.textColor = [UIColor colorForWebColor: [view objectForKey: ColorParameterKey]];
                            }
                            
                            // Alpha
                            if ([view objectForKey: AlphaParameterKey]) {
                                label.alpha = [[view objectForKey: AlphaParameterKey] floatValue];
                            }
                            
                            // Font size & Font
                            if ([view objectForKey: ContentFontSizeParameterKey]) {
                                label.font = [UIFont systemFontOfSize: [[view objectForKey: ContentFontSizeParameterKey] floatValue]];
                            }
                            
                            if ([view objectForKey: ContentFontWeightParameterKey]) {
                                NSString *weight = [view objectForKey: ContentFontWeightParameterKey];
                                
                                if ([weight isEqualToString: @"bold"]) {
                                    label.font = [UIFont boldSystemFontOfSize: label.font.pointSize];
                                } else {
                                    label.font = [UIFont systemFontOfSize: label.font.pointSize];
                                }
                            }
                            
                            if ([view objectForKey: ContentFontNameParameterKey]) {
                                label.font = [UIFont fontWithName: [view objectForKey: ContentFontNameParameterKey] size: label.font.pointSize];
                            }
                            
                            // Shadow
                            if ([view objectForKey: DropShadowOptionKey]) {
                                label.shadowColor = [UIColor colorForWebColor: [[view objectForKey: DropShadowOptionKey] objectForKey: ColorParameterKey]];
                                
                                if ([[view objectForKey: DropShadowOptionKey] objectForKey: AlphaParameterKey]) {
                                    label.shadowColor = [label.shadowColor colorWithAlphaComponent: [[[view objectForKey: DropShadowOptionKey] objectForKey: AlphaParameterKey] floatValue]];
                                }
                                
                                NSDictionary *offset = [[view objectForKey: DropShadowOptionKey] objectForKey: OffsetParameterKey];
                                label.shadowOffset = CGSizeMake([[offset objectForKey: XCoordinateParameterKey] floatValue],
                                                                [[offset objectForKey: YCoordinateParameterKey] floatValue]);
                                }
                            
                                [subviews insertObject: label atIndex: idx];
                            } else {
                                NSLog(@"Unknown type \"%@\" encountered, ignoring", type);
                            }
                    }];
    
    return [NSArray arrayWithArray: subviews];
}

- (UIImageView *)rectangleInFrame: (CGRect)frame options: (NSDictionary *)options {
    // Keep note of any changes to the offset of drawing, this points to where, the main view should begin and how big it should be
    CGPoint origin = CGPointMake(0.0, 0.0);
    CGSize size = frame.size;
    
    // Additionally keep track of the canvasrect
    CGRect canvasRect = frame;
    
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
        [self balanceCornerRadiuses: radii toFitIntoSize: frame.size];
    }
    
    // If outer stroke, enlarge the frame
    if ([options objectForKey: OuterStrokeOptionKey]) {
        CGFloat strokeWidth = [[[options objectForKey: OuterStrokeOptionKey] objectForKey: WidthParameterKey] floatValue];
        
        // Create a stroke rect
        CGRect strokeRect = [self strokeRectForRect: frame andWidth: strokeWidth];
        
        // Find a union between the canvas and stroke rect
        canvasRect = CGRectUnion(canvasRect, strokeRect);
    }
    
    // If drop shadow is present adjust the size
    if ([options objectForKey: DropShadowOptionKey]) {
        // Create a special frame for the shadow
        NSDictionary *dictionary = [options objectForKey: DropShadowOptionKey];
        CGRect shadowRect = [self shadowRectForRect: frame andOptions: dictionary];
                        
        // Find the union between canvas and shadow
        canvasRect = CGRectUnion(canvasRect, shadowRect);
    }
    
    // Now as we have the frame, check cache for a view with same properties
    // As a key use a .strings representation of the NSDictionary
    if (_isCached && [_cache objectForKey: options]) {
        UIImageView *result = [[[UIImageView alloc] initWithImage: [_cache objectForKey: options]] autorelease];
        result.frame = CGRectMake(canvasRect.origin.x, canvasRect.origin.y, result.frame.size.width, result.frame.size.height);
        
        return result;
    }
    
    // Adjust the inner origin, this is where the actual view is located
    origin.x = frame.origin.x - canvasRect.origin.x;
    origin.y = frame.origin.y - canvasRect.origin.y;
    
    // Create the path incase the rectangle is rounded
    if (rounded)
        roundedPath = [self newRoundedPathForRect: CGRectMake(origin.x, origin.y, size.width, size.height) withRadiuses: radii];
    
    // Setup the context
    CGRect rect = CGRectMake(0.0, 0.0, canvasRect.size.width, canvasRect.size.height);
    UIGraphicsBeginImageContextWithOptions(rect.size, NO, 
                                       [[UIScreen mainScreen] scale]);
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    // Alpha
    if ([options objectForKey: AlphaParameterKey]) {
        CGContextSetAlpha(context, [[options objectForKey: AlphaParameterKey] floatValue]);
    }
        
    // Drawing code
    // Start with the main inner view
    CGContextSaveGState(context);
    
    // If shadow needed, draw it
    if ([options objectForKey: DropShadowOptionKey]) {
        NSDictionary *offsetOptions = [[options objectForKey: DropShadowOptionKey] objectForKey: OffsetParameterKey];
        NSDictionary *dictionary = [options objectForKey: DropShadowOptionKey];
        
        CGSize offset = CGSizeMake([[offsetOptions objectForKey: XCoordinateParameterKey] floatValue], [[offsetOptions objectForKey: YCoordinateParameterKey] floatValue]);
        CGFloat blur = 0.0;
        
        // Adjust blur if key is present
        if ([[dictionary objectForKey: BlurParameterKey] floatValue]) {
            blur = [[dictionary objectForKey: BlurParameterKey] floatValue];
        }
        
        // Check if blend mode is present
        if ([dictionary objectForKey: BlendModeParameterKey]) {
            // Get the blend mode and apply it to the context
            CGContextSetBlendMode(context, [self blendModeForString: [dictionary objectForKey: BlendModeParameterKey]]);
        }
        
        CGFloat alpha = 1.0;
        
        if ([dictionary objectForKey: AlphaParameterKey])
            alpha = [[dictionary objectForKey: AlphaParameterKey] floatValue];
        
        if ([dictionary objectForKey: ColorParameterKey])
            CGContextSetShadowWithColor(context, offset, blur, [[UIColor colorForWebColor: [dictionary objectForKey: ColorParameterKey]] colorWithAlphaComponent: alpha].CGColor);
        else
            CGContextSetShadowWithColor(context, offset, blur, [[UIColor blackColor] colorWithAlphaComponent: alpha].CGColor);
    }
    
    // Check if blend mode is present
    if ([options objectForKey: BlendModeParameterKey]) {
        // Get the blend mode and apply it to the context
        CGContextSetBlendMode(context, [self blendModeForString: [options objectForKey: BlendModeParameterKey]]);
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
        
        NSDictionary *dictionary = [options objectForKey: GradientFillOptionKey];
      
        // Gradient is present, first clip the context, either to a rect or to a path
        if (rounded) {            
            // Add path to context and fill it
            CGContextAddPath(context, roundedPath);
            CGContextClip(context);
        } else {
            CGContextClipToRect(context, CGRectMake(origin.x, origin.y, size.width, size.height));
        }
        
        // Check if blend mode is present
        if ([dictionary objectForKey: BlendModeParameterKey]) {
            // Get the blend mode and apply it to the context
            CGContextSetBlendMode(context, [self blendModeForString: [dictionary objectForKey: BlendModeParameterKey]]);
        }
        
        // Check if alpha is present
        if ([dictionary objectForKey: AlphaParameterKey]) {
            CGContextSetAlpha(context, [[dictionary objectForKey: AlphaParameterKey] floatValue]); 
        }
        
        // Create the gradient
        // First the colors
        NSArray *colors = [dictionary objectForKey: GradientColorsParameterKey];
        NSMutableArray *CGColors = [NSMutableArray arrayWithCapacity: [colors count]];
        [colors enumerateObjectsWithOptions: NSEnumerationConcurrent
                                 usingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                                        [CGColors insertObject: (id)[UIColor colorForWebColor: (NSString *)obj].CGColor atIndex: idx]; }];
        
        // And then the locations
        colors = [dictionary objectForKey: GradientPositionsParameterKey];
        __block CGFloat *positions = (CGFloat *)calloc(sizeof(CGFloat), [colors count]);
        [colors enumerateObjectsWithOptions: NSEnumerationConcurrent 
                                 usingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                                     positions[idx] = [(NSNumber *)obj floatValue]; }];
        
        CGGradientRef gradient = [self newGradientForColors: CGColors andLocations: positions];
        
        //Draw the gradient
        CGContextDrawLinearGradient(context, gradient, CGPointMake(origin.x, origin.y), CGPointMake(origin.x, origin.y + size.height), 0);
        
        // Release the gradient
        CGGradientRelease(gradient);
        
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
            CGMutablePathRef shadowRoundedPath = [self newRoundedPathForRect: CGRectMake(origin.x + [[[dictionary objectForKey: OffsetParameterKey] objectForKey: XCoordinateParameterKey] floatValue],
                                                                                   origin.y + [[[dictionary objectForKey: OffsetParameterKey] objectForKey: YCoordinateParameterKey] floatValue],
                                                                                   size.width, size.height) withRadiuses: radii];
            
            CGContextAddPath(context, shadowRoundedPath);            
            CGPathRelease(shadowRoundedPath);
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
            CGContextSetBlendMode(context, [self blendModeForString: [dictionary objectForKey: BlendModeParameterKey]]);
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
            
            CGMutablePathRef strokeRoundedPath = [self newRoundedPathForRect: CGRectMake(origin.x - strokeWidth / 2.0, origin.y - strokeWidth / 2.0,
                                                                                   size.width + strokeWidth, size.height + strokeWidth) withRadiuses: strokeRadii];
            
            // Add path to context and fill it
            CGContextAddPath(context, strokeRoundedPath);            
            CGPathRelease(strokeRoundedPath);
        } else {
            // Not rounded, add the rect
            CGContextAddRect(context, CGRectMake(origin.x - halfStroke, origin.y - halfStroke, size.width + strokeWidth, size.height + strokeWidth));
        }
        
        // Check if blend mode is present
        if ([dictionary objectForKey: BlendModeParameterKey]) {
            // Get the blend mode and apply it to the context
            CGContextSetBlendMode(context, [self blendModeForString: [dictionary objectForKey: BlendModeParameterKey]]);
        }
        
        if ([dictionary objectForKey: AlphaParameterKey])
            CGContextSetAlpha(context, [[dictionary objectForKey: AlphaParameterKey] floatValue]);
            
        if ([dictionary objectForKey: ColorParameterKey])
            CGContextSetStrokeColorWithColor(context, [UIColor colorForWebColor: [dictionary objectForKey: ColorParameterKey]].CGColor);
        else
            CGContextSetStrokeColorWithColor(context, [UIColor blackColor].CGColor);
        
        // Set the width
        CGContextSetLineWidth(context, strokeWidth);
        
        // Stroke it
        CGContextStrokePath(context);
        
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

            CGMutablePathRef strokeRoundedPath = [self newRoundedPathForRect: CGRectMake(origin.x + strokeWidth / 2.0, origin.y + strokeWidth / 2.0,
                                                                                   size.width - strokeWidth, size.height - strokeWidth) withRadiuses: strokeRadii];
            
            // Add path to context and fill it
            CGContextAddPath(context, strokeRoundedPath);            
            CGPathRelease(strokeRoundedPath);
        } else {
            // Not rounded, add the rect
            CGContextAddRect(context, CGRectMake(origin.x + halfStroke, origin.y + halfStroke, size.width - strokeWidth, size.height - strokeWidth));
        }
        
        // Check if blend mode is present
        if ([dictionary objectForKey: BlendModeParameterKey]) {
            // Get the blend mode and apply it to the context
            CGContextSetBlendMode(context, [self blendModeForString: [dictionary objectForKey: BlendModeParameterKey]]);
        }
        
        if ([dictionary objectForKey: AlphaParameterKey])
            CGContextSetAlpha(context, [[dictionary objectForKey: AlphaParameterKey] floatValue]);
        
        if ([dictionary objectForKey: ColorParameterKey])
            CGContextSetStrokeColorWithColor(context, [UIColor colorForWebColor: [dictionary objectForKey: ColorParameterKey]].CGColor);
        else
            CGContextSetStrokeColorWithColor(context, [UIColor blackColor].CGColor);
        
        // Set the width
        CGContextSetLineWidth(context, strokeWidth);
        
        // Stroke it
        CGContextStrokePath(context);
        
        CGContextRestoreGState(context);
    }
    
    // Release memory
    if (rounded)
        CGPathRelease(roundedPath);
    
    // Wrap up and return the image
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    // Store into cache, if needed. Use the same key created before
    if (_isCached)
        [_cache setObject: image forKey: options];

    // Create the view and return it
    UIImageView *view = [[[UIImageView alloc] initWithImage: image] autorelease];
    view.frame = CGRectMake(canvasRect.origin.x, canvasRect.origin.y, view.frame.size.width, view.frame.size.height);
    
    return view;
}

- (UIImageView *)circleInFrame:(CGRect)frame options:(NSDictionary *)options {
    // Keep note of any changes to the offset of drawing, this points to where, the main view should begin and how big it should be
    CGPoint origin = CGPointMake(0.0, 0.0);
    CGSize size = frame.size;
    
    // Additionally keep track of the canvasrect
    CGRect canvasRect = frame;
    
    // Check if there is a need for a outer stroke
    if ([options objectForKey: OuterStrokeOptionKey]) {
        // Adjust the canvasrect
        CGFloat strokeWidth = [[[options objectForKey: OuterStrokeOptionKey] objectForKey: WidthParameterKey] floatValue];
        
        CGRect strokeRect = [self strokeRectForRect: frame andWidth: strokeWidth];
        
        // Union to the canvasrect
        canvasRect = CGRectUnion(canvasRect, strokeRect);
    }
    
    // Check if there is a need for a drop shadow
    if ([options objectForKey: DropShadowOptionKey]) {
        // Adjust the canvasrect, first get the property dictionary
        NSDictionary *shadow = [options objectForKey: DropShadowOptionKey];
        
        CGRect shadowRect = [self shadowRectForRect: frame andOptions: shadow];
        
        // Union into the canvas
        canvasRect = CGRectUnion(canvasRect, shadowRect);
    }
    
    // Check cache
    if (_isCached && [_cache objectForKey: options]) {
        UIImageView *result = [[[UIImageView alloc] initWithImage: [_cache objectForKey: options]] autorelease];
        result.frame = CGRectMake(canvasRect.origin.x, canvasRect.origin.y, result.frame.size.width, result.frame.size.height);
        
        return result;
    }
    
    // Adjust the inner origin, this is where the actual view is located
    origin.x = frame.origin.x - canvasRect.origin.x;
    origin.y = frame.origin.y - canvasRect.origin.y;
        
    // Setup the context
    CGRect rect = CGRectMake(0.0, 0.0, canvasRect.size.width, canvasRect.size.height);
    UIGraphicsBeginImageContextWithOptions(rect.size, NO, [[UIScreen mainScreen] scale]);
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    // Alpha
    if ([options objectForKey: AlphaParameterKey]) {
        CGContextSetAlpha(context, [[options objectForKey: AlphaParameterKey] floatValue]);
    }
    
    // Start by drawing the main shape
    // Start with the main inner view
    CGContextSaveGState(context);
    
    // If shadow needed, draw it
    if ([options objectForKey: DropShadowOptionKey]) {
        NSDictionary *offsetOptions = [[options objectForKey: DropShadowOptionKey] objectForKey: OffsetParameterKey];
        NSDictionary *dictionary = [options objectForKey: DropShadowOptionKey];
        
        CGSize offset = CGSizeMake([[offsetOptions objectForKey: XCoordinateParameterKey] floatValue], [[offsetOptions objectForKey: YCoordinateParameterKey] floatValue]);
        CGFloat blur = 0.0;
        
        if ([[dictionary objectForKey: BlurParameterKey] floatValue]) {
            blur = [[dictionary objectForKey: BlurParameterKey] floatValue];
        }
        
        // Check if blend mode is present
        if ([dictionary objectForKey: BlendModeParameterKey]) {
            // Get the blend mode and apply it to the context
            CGContextSetBlendMode(context, [self blendModeForString: [dictionary objectForKey: BlendModeParameterKey]]);
        }
        
        CGFloat alpha = 1.0;
        
        if ([dictionary objectForKey: AlphaParameterKey])
            alpha = [[dictionary objectForKey: AlphaParameterKey] floatValue];
        
        if ([dictionary objectForKey: ColorParameterKey])
            CGContextSetShadowWithColor(context, offset, blur, [[UIColor colorForWebColor: [dictionary objectForKey: ColorParameterKey]] colorWithAlphaComponent: alpha].CGColor);
        else
            CGContextSetShadowWithColor(context, offset, blur, [[UIColor blackColor] colorWithAlphaComponent: alpha].CGColor);
    }
    
    // Check if blend mode is present
    if ([options objectForKey: BlendModeParameterKey]) {
        // Get the blend mode and apply it to the context
        CGContextSetBlendMode(context, [self blendModeForString: [options objectForKey: BlendModeParameterKey]]);
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
        
        // Create the gradient
        NSDictionary *dictionary = [options objectForKey: GradientFillOptionKey];
        
        // Check if alpha is present
        if ([dictionary objectForKey: AlphaParameterKey]) {
            CGContextSetAlpha(context, [[dictionary objectForKey: AlphaParameterKey] floatValue]); 
        }
        
        // Check if blend mode is present
        if ([dictionary objectForKey: BlendModeParameterKey]) {
            // Get the blend mode and apply it to the context
            CGContextSetBlendMode(context, [self blendModeForString: [dictionary objectForKey: BlendModeParameterKey]]);
        }

        // Create the gradient
        // First the colors
        NSArray *colors = [dictionary objectForKey: GradientColorsParameterKey];
        NSMutableArray *CGColors = [NSMutableArray arrayWithCapacity: [colors count]];
        [colors enumerateObjectsWithOptions: NSEnumerationConcurrent
                                 usingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                                     [CGColors insertObject: (id)[UIColor colorForWebColor: (NSString *)obj].CGColor atIndex: idx]; }];
        
        // And then the locations
        colors = [dictionary objectForKey: GradientPositionsParameterKey];
        __block CGFloat *positions = (CGFloat *)calloc(sizeof(CGFloat), [colors count]);
        [colors enumerateObjectsWithOptions: NSEnumerationConcurrent 
                                 usingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                                     positions[idx] = [(NSNumber *)obj floatValue]; }];
        
        CGGradientRef gradient = [self newGradientForColors: CGColors andLocations: positions];
        
        //Draw the gradient
        CGContextDrawLinearGradient(context, gradient, CGPointMake(origin.x, origin.y), CGPointMake(origin.x, origin.y + size.height), 0);
        
        // Release the gradient
        CGGradientRelease(gradient);        
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
            CGContextSetBlendMode(context, [self blendModeForString: [dictionary objectForKey: BlendModeParameterKey]]);
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
        
        // Check if blend mode is present
        if ([dictionary objectForKey: BlendModeParameterKey]) {
            // Get the blend mode and apply it to the context
            CGContextSetBlendMode(context, [self blendModeForString: [dictionary objectForKey: BlendModeParameterKey]]);
        }
        
        // There is a stroke, either create a path
        CGContextAddEllipseInRect(context, CGRectMake(origin.x - strokeWidth / 2.0, origin.y - strokeWidth / 2.0, size.width + strokeWidth, size.height + strokeWidth));
        
        if ([dictionary objectForKey: AlphaParameterKey])
            CGContextSetAlpha(context, [[dictionary objectForKey: AlphaParameterKey] floatValue]);
        
        if ([dictionary objectForKey: ColorParameterKey])
            CGContextSetStrokeColorWithColor(context, [UIColor colorForWebColor: [dictionary objectForKey: ColorParameterKey]].CGColor);
        else
            CGContextSetStrokeColorWithColor(context, [UIColor blackColor].CGColor);
        
        // Set the width
        CGContextSetLineWidth(context, strokeWidth + 0.5);
        
        // Stroke it
        CGContextStrokePath(context);
        
        CGContextRestoreGState(context);
    }
    
    // Inner
    if ([options objectForKey: InnerStrokeOptionKey]) {
        CGContextSaveGState(context);
        
        // Parameters
        NSDictionary *dictionary = [options objectForKey: InnerStrokeOptionKey];
        
        // Stroke width
        CGFloat strokeWidth = [[dictionary objectForKey: WidthParameterKey] floatValue];
        
        // Check if blend mode is present
        if ([dictionary objectForKey: BlendModeParameterKey]) {
            // Get the blend mode and apply it to the context
            CGContextSetBlendMode(context, [self blendModeForString: [dictionary objectForKey: BlendModeParameterKey]]);
        }
        
        // Add the ellipse
        CGContextAddEllipseInRect(context, CGRectMake(origin.x + strokeWidth / 2.0, origin.y + strokeWidth / 2.0, size.width - strokeWidth, size.height - strokeWidth));
                
        if ([dictionary objectForKey: AlphaParameterKey])
            CGContextSetAlpha(context, [[dictionary objectForKey: AlphaParameterKey] floatValue]);
        
        if ([dictionary objectForKey: ColorParameterKey])
            CGContextSetStrokeColorWithColor(context, [UIColor colorForWebColor: [dictionary objectForKey: ColorParameterKey]].CGColor);
        else
            CGContextSetStrokeColorWithColor(context, [UIColor blackColor].CGColor);
        
        // Set the width
        CGContextSetLineWidth(context, strokeWidth);
        
        // Stroke it
        CGContextStrokePath(context);
        
        CGContextRestoreGState(context);
    }
    
    // Wrap up and return the image
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    // Store into cache
    if (_isCached)
        [_cache setObject: image forKey: options];
    
    UIImageView *result = [[[UIImageView alloc] initWithImage: image] autorelease];
    result.frame = CGRectMake(canvasRect.origin.x, canvasRect.origin.y, result.frame.size.width, result.frame.size.height);
    
    return result;
}

- (UIImageView *)lineFromPoint:(CGPoint)fromPoint toPoint:(CGPoint)toPoint options:(NSDictionary *)options {
    // Stroke width
    CGFloat strokeWidth = [[options objectForKey: WidthParameterKey] floatValue];

    // Construct the frame for the line
    CGPoint origin = CGPointMake(MIN(fromPoint.x, toPoint.x) - strokeWidth / 2.0, MIN(fromPoint.y, toPoint.y) - strokeWidth / 2.0);
    if (toPoint.x == fromPoint.x) {
        origin.y += strokeWidth / 2.0;
    } else if (toPoint.y == fromPoint.y) {
        origin.x += strokeWidth / 2.0;
    }
    
    CGRect frame = CGRectMake(origin.x, origin.y, MAX(MAX(fromPoint.x, toPoint.x) - origin.x, strokeWidth), MAX(MAX(fromPoint.y, toPoint.y) - origin.y, strokeWidth));
        
    CGRect canvasRect = frame;
    origin = CGPointMake(0.0, 0.0);
    
    // Check if shadow is present, if it is, adjust the canvas
    if ([options objectForKey: DropShadowOptionKey]) {
        // Adjust the canvasrect, first get the property dictionary
        NSDictionary *shadow = [options objectForKey: DropShadowOptionKey];
        
        CGRect shadowRect = [self shadowRectForRect: frame andOptions: shadow];
        
        // Union into the canvas
        canvasRect = CGRectUnion(canvasRect, shadowRect);
    }
    
    // Check cache
    if (_isCached && [_cache objectForKey: options]) {
        UIImageView *result = [[[UIImageView alloc] initWithImage: [_cache objectForKey: options]] autorelease];
        result.frame = CGRectMake(canvasRect.origin.x, canvasRect.origin.y, result.frame.size.width, result.frame.size.height);
        
        return result;
    }
    
    // Adjust the inner origin, this is where the actual view is located
    origin.x = frame.origin.x - canvasRect.origin.x;
    origin.y = frame.origin.y - canvasRect.origin.y;
        
    // Setup the context
    UIGraphicsBeginImageContextWithOptions(canvasRect.size, NO, [[UIScreen mainScreen] scale]);
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    // Alpha
    if ([options objectForKey: AlphaParameterKey]) {
        CGContextSetAlpha(context, [[options objectForKey: AlphaParameterKey] floatValue]);
    }
    
    // Start by drawing the main shape
    // Start with the main inner view
    CGContextSaveGState(context);
    
    // If shadow needed, draw it
    if ([options objectForKey: DropShadowOptionKey]) {
        NSDictionary *offsetOptions = [[options objectForKey: DropShadowOptionKey] objectForKey: OffsetParameterKey];
        NSDictionary *dictionary = [options objectForKey: DropShadowOptionKey];
        
        CGSize offset = CGSizeMake([[offsetOptions objectForKey: XCoordinateParameterKey] floatValue], [[offsetOptions objectForKey: YCoordinateParameterKey] floatValue]);        
        CGFloat blur = 0.0;
        if ([[dictionary objectForKey: BlurParameterKey] floatValue]) {
            blur = [[dictionary objectForKey: BlurParameterKey] floatValue];
        }
        
        // Check if blend mode is present
        if ([dictionary objectForKey: BlendModeParameterKey]) {
            // Get the blend mode and apply it to the context
            CGContextSetBlendMode(context, [self blendModeForString: [dictionary objectForKey: BlendModeParameterKey]]);
        }
        
        CGFloat alpha = 1.0;
        
        if ([dictionary objectForKey: AlphaParameterKey])
            alpha = [[dictionary objectForKey: AlphaParameterKey] floatValue];
        
        if ([dictionary objectForKey: ColorParameterKey])
            CGContextSetShadowWithColor(context, offset, blur, [[UIColor colorForWebColor: [dictionary objectForKey: ColorParameterKey]] colorWithAlphaComponent: alpha].CGColor);
        else
            CGContextSetShadowWithColor(context, offset, blur, [[UIColor blackColor] colorWithAlphaComponent: alpha].CGColor);
    }
    
    // Check if blend mode is present
    if ([options objectForKey: BlendModeParameterKey]) {
        // Get the blend mode and apply it to the context
        CGContextSetBlendMode(context, [self blendModeForString: [options objectForKey: BlendModeParameterKey]]);
    }
    
    // Load in the fill color
    if ([options objectForKey: ColorParameterKey])
        CGContextSetStrokeColorWithColor(context, [UIColor colorForWebColor: [options objectForKey: ColorParameterKey]].CGColor);
    else
        CGContextSetStrokeColorWithColor(context, [UIColor whiteColor].CGColor);
        
    // Create the path and stroke it
    CGContextMoveToPoint(context, fromPoint.x - frame.origin.x + origin.x, fromPoint.y - frame.origin.y + origin.y);
    CGContextAddLineToPoint(context, toPoint.x - frame.origin.x + origin.x,
                            toPoint.y - frame.origin.y + origin.y);
    
    CGContextSetLineWidth(context, strokeWidth);
    CGContextStrokePath(context);
    
    CGContextRestoreGState(context);
        
    // Wrap up and return the image
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    // Store into cache
    if (_isCached)
        [_cache setObject: image forKey: options];
    
    UIImageView *result = [[[UIImageView alloc] initWithImage: image] autorelease];
    
    if (toPoint.x == fromPoint.x) {
        result.frame = CGRectMake(frame.origin.x, frame.origin.y - fmodf(strokeWidth, 2.0) * 0.5, result.frame.size.width, result.frame.size.height); 
    } else if (toPoint.y == fromPoint.y) {
        result.frame = CGRectMake(frame.origin.x - fmodf(strokeWidth, 2.0) * 0.5, frame.origin.y, result.frame.size.width, result.frame.size.height); 
    } else {
        result.frame = CGRectMake(frame.origin.x, frame.origin.y, result.frame.size.width, result.frame.size.height); 
    }
    
    return result;
}

- (UIImageView *)pathInFrame: (CGRect)frame options: (NSDictionary *)options {
    // Keep note of any changes to the offset of drawing, this points to where, the main view should begin and how big it should be
    CGPoint origin = CGPointMake(0.0, 0.0);
    CGSize size = frame.size;
    
    // Additionally keep track of the canvasrect
    CGRect canvasRect = frame;
    
    // Get the path described
    CGMutablePathRef mainPath = [self newPathForSVGSyntax: [options objectForKey: PathDescriptionKey]];
    
    // Adjust the frame
    frame = CGPathGetBoundingBox(mainPath);
    
    // If outer stroke, enlarge the frame
    if ([options objectForKey: OuterStrokeOptionKey]) {
        CGFloat strokeWidth = [[[options objectForKey: OuterStrokeOptionKey] objectForKey: WidthParameterKey] floatValue];
        
        // Create a stroke rect
        CGRect strokeRect = [self strokeRectForRect: frame andWidth: strokeWidth];
        
        // Find a union between the canvas and stroke rect
        canvasRect = CGRectUnion(canvasRect, strokeRect);
    }
    
    // If drop shadow is present adjust the size
    if ([options objectForKey: DropShadowOptionKey]) {
        // Create a special frame for the shadow
        NSDictionary *dictionary = [options objectForKey: DropShadowOptionKey];
        CGRect shadowRect = [self shadowRectForRect: frame andOptions: dictionary];
        
        // Find the union between canvas and shadow
        canvasRect = CGRectUnion(canvasRect, shadowRect);
    }
    
    // Now as we have the frame, check cache for a view with same properties
    // As a key use a .strings representation of the NSDictionary
    if (_isCached && [_cache objectForKey: options]) {
        UIImageView *result = [[[UIImageView alloc] initWithImage: [_cache objectForKey: options]] autorelease];
        result.frame = CGRectMake(canvasRect.origin.x, canvasRect.origin.y, result.frame.size.width, result.frame.size.height);
        
        return result;
    }
    
    // Adjust the inner origin, this is where the actual view is located
    origin.x = frame.origin.x - canvasRect.origin.x;
    origin.y = frame.origin.y - canvasRect.origin.y;
        
    // Setup the context
    CGRect rect = CGRectMake(0.0, 0.0, canvasRect.size.width, canvasRect.size.height);
    UIGraphicsBeginImageContextWithOptions(rect.size, NO, 
                                           [[UIScreen mainScreen] scale]);
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    // Alpha
    if ([options objectForKey: AlphaParameterKey]) {
        CGContextSetAlpha(context, [[options objectForKey: AlphaParameterKey] floatValue]);
    }
    
    // Drawing code
    // Start with the main inner view
    CGContextSaveGState(context);
    
    // If shadow needed, draw it
    if ([options objectForKey: DropShadowOptionKey]) {
        NSDictionary *offsetOptions = [[options objectForKey: DropShadowOptionKey] objectForKey: OffsetParameterKey];
        NSDictionary *dictionary = [options objectForKey: DropShadowOptionKey];
        
        CGSize offset = CGSizeMake([[offsetOptions objectForKey: XCoordinateParameterKey] floatValue], [[offsetOptions objectForKey: YCoordinateParameterKey] floatValue]);
        CGFloat blur = 0.0;
        
        // Adjust blur if key is present
        if ([[dictionary objectForKey: BlurParameterKey] floatValue]) {
            blur = [[dictionary objectForKey: BlurParameterKey] floatValue];
        }
        
        // Check if blend mode is present
        if ([dictionary objectForKey: BlendModeParameterKey]) {
            // Get the blend mode and apply it to the context
            CGContextSetBlendMode(context, [self blendModeForString: [dictionary objectForKey: BlendModeParameterKey]]);
        }
        
        CGFloat alpha = 1.0;
        
        if ([dictionary objectForKey: AlphaParameterKey])
            alpha = [[dictionary objectForKey: AlphaParameterKey] floatValue];
        
        if ([dictionary objectForKey: ColorParameterKey])
            CGContextSetShadowWithColor(context, offset, blur, [[UIColor colorForWebColor: [dictionary objectForKey: ColorParameterKey]] colorWithAlphaComponent: alpha].CGColor);
        else
            CGContextSetShadowWithColor(context, offset, blur, [[UIColor blackColor] colorWithAlphaComponent: alpha].CGColor);
    }
    
    // Check if blend mode is present
    if ([options objectForKey: BlendModeParameterKey]) {
        // Get the blend mode and apply it to the context
        CGContextSetBlendMode(context, [self blendModeForString: [options objectForKey: BlendModeParameterKey]]);
    }
    
    // Load in the fill color
    if ([options objectForKey: ColorParameterKey])
        CGContextSetFillColorWithColor(context, [UIColor colorForWebColor: [options objectForKey: ColorParameterKey]].CGColor);
    else
        CGContextSetFillColorWithColor(context, [UIColor whiteColor].CGColor);
    
    // Fill the path
    CGContextAddPath(context, mainPath);
    CGContextFillPath(context);
    
    CGContextRestoreGState(context);
    
    // Check if gradient is present, if so draw it over the fill
    if ([options objectForKey: GradientFillOptionKey]) {        
        CGContextSaveGState(context);
        
        NSDictionary *dictionary = [options objectForKey: GradientFillOptionKey];
        
        // Gradient is present, first clip the context
        CGContextAddPath(context, mainPath);
        CGContextClip(context);
        
        // Check if blend mode is present
        if ([dictionary objectForKey: BlendModeParameterKey]) {
            // Get the blend mode and apply it to the context
            CGContextSetBlendMode(context, [self blendModeForString: [dictionary objectForKey: BlendModeParameterKey]]);
        }
        
        // Check if alpha is present
        if ([dictionary objectForKey: AlphaParameterKey]) {
            CGContextSetAlpha(context, [[dictionary objectForKey: AlphaParameterKey] floatValue]); 
        }
        
        // Create the gradient
        // First the colors
        NSArray *colors = [dictionary objectForKey: GradientColorsParameterKey];
        NSMutableArray *CGColors = [NSMutableArray arrayWithCapacity: [colors count]];
        [colors enumerateObjectsWithOptions: NSEnumerationConcurrent
                                 usingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                                     [CGColors insertObject: (id)[UIColor colorForWebColor: (NSString *)obj].CGColor atIndex: idx]; }];
        
        // And then the locations
        colors = [dictionary objectForKey: GradientPositionsParameterKey];
        __block CGFloat *positions = (CGFloat *)calloc(sizeof(CGFloat), [colors count]);
        [colors enumerateObjectsWithOptions: NSEnumerationConcurrent 
                                 usingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                                     positions[idx] = [(NSNumber *)obj floatValue]; }];
        
        CGGradientRef gradient = [self newGradientForColors: CGColors andLocations: positions];
        
        //Draw the gradient
        CGContextDrawLinearGradient(context, gradient, CGPointMake(origin.x, origin.y), CGPointMake(origin.x, origin.y + size.height), 0);
        
        // Release the gradient
        CGGradientRelease(gradient);
        
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
        CGContextAddPath(context, CGPathCreateCopyByTransformingPath(mainPath, &transform));
        
        // Set the color and opacity
        if ([dictionary objectForKey: ColorParameterKey]) {
            CGContextSetFillColorWithColor(context, [UIColor colorForWebColor: [dictionary objectForKey: ColorParameterKey]].CGColor);
        }
        
        if ([dictionary objectForKey: AlphaParameterKey]) {
            CGContextSetAlpha(context, [[dictionary objectForKey: AlphaParameterKey] floatValue]);
        }
        
        // Set blend mode
        if ([dictionary objectForKey: BlendModeParameterKey]) {
            CGContextSetBlendMode(context, [self blendModeForString: [dictionary objectForKey: BlendModeParameterKey]]);
        }
        
        // Fill by using EO rule
        CGContextEOFillPath(context);
        
        CGContextRestoreGState(context);
    }
    
    // Release memory
    CGPathRelease(mainPath);
    
    // Wrap up and return the image
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    // Store into cache, if needed. Use the same key created before
    if (_isCached)
        [_cache setObject: image forKey: options];
    
    // Create the view and return it
    UIImageView *view = [[[UIImageView alloc] initWithImage: image] autorelease];
    view.frame = CGRectMake(canvasRect.origin.x, canvasRect.origin.y, view.frame.size.width, view.frame.size.height);
    
    return view;
}

- (void)balanceCornerRadiuses: (CGFloat *)radii toFitIntoSize: (CGSize)size {
    // This method is passed an array of floats always 4 long, compare each pair
    // The order is top-right bottom-right bottom-left top-left (clockwise, beginning in the top-right)
    CGFloat topright = radii[0];
    CGFloat bottomright = radii[1];
    CGFloat bottomleft = radii[2];
    CGFloat topleft = radii[3];
    
    // None should be larger than half of the either side
    // (as they both connect the width to height, we need to make 8 comparisons)
    CGFloat halfWidth = roundf(size.width / 2.0);
    CGFloat halfHeight = roundf(size.height / 2.0);
    
    // Top right
    topright = topright > halfWidth ? halfWidth : topright;
    topright = topright > halfHeight ? halfHeight : topright;
    
    // Bottom right
    bottomright = bottomright > halfWidth ? halfWidth : bottomright;
    bottomright = bottomright > halfHeight ? halfHeight : bottomright;

    // Bottom left
    bottomleft = bottomleft > halfWidth ? halfWidth : bottomleft;
    bottomleft = bottomleft > halfHeight ? halfHeight : bottomleft;

    // Top left
    topleft = topleft > halfWidth ? halfWidth : topleft;
    topleft = topleft > halfHeight ? halfHeight : topleft;
    
    // Adjust the passed array
    radii[0] = topright;
    radii[1] = bottomright;
    radii[2] = bottomleft;
    radii[3] = topleft;
}

- (CGMutablePathRef)newPathForSVGSyntax:(NSString *)description {
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
    
    return path;
}

- (CGMutablePathRef)newRoundedPathForRect: (CGRect)rect withRadiuses: (CGFloat *)radii {
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
    
    return roundedPath;
}

- (CGGradientRef)newGradientFromColor: (UIColor *)fromColor toColor: (UIColor *)toColor beginningAt: (CGFloat)begin ending: (CGFloat)end {
    CGColorSpaceRef rgbSpace = CGColorSpaceCreateDeviceRGB();
	CGFloat locations[2] = { begin, end };
    NSArray *colors = [NSArray arrayWithObjects: (id)fromColor.CGColor, (id)toColor.CGColor, nil];
	CGGradientRef gradient = CGGradientCreateWithColors(rgbSpace, (CFArrayRef)colors, locations);
    CGColorSpaceRelease(rgbSpace);
        
    return gradient;
}

- (CGGradientRef)newGradientForColors: (NSArray *)CGColors andLocations: (CGFloat[])locations {
    CGColorSpaceRef rgbSpace = CGColorSpaceCreateDeviceRGB();
	CGGradientRef gradient = CGGradientCreateWithColors(rgbSpace, (CFArrayRef)CGColors, locations);
    CGColorSpaceRelease(rgbSpace);
    
    return gradient;
}

- (CGBlendMode)blendModeForString: (NSString *)key {
    if ([key isEqualToString: @"overlay"]) {
        return kCGBlendModeOverlay;
    } else if ([key isEqualToString: @"multiply"]) {
        return kCGBlendModeMultiply;
    } else if ([key isEqualToString: @"softlight"]) {
        return kCGBlendModeSoftLight;
    } else {
        return kCGBlendModeNormal;
    }
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
        // First run over any non-relevant symbols
        [scanner scanCharactersFromSet: nonrelevant intoString: NULL];
        
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

- (CGRect)shadowRectForRect: (CGRect)frame andOptions: (NSDictionary *)options {
    NSDictionary *offsetDictionary = [options objectForKey: OffsetParameterKey];
    CGSize offset = CGSizeMake([[offsetDictionary objectForKey: XCoordinateParameterKey] floatValue], [[offsetDictionary objectForKey: YCoordinateParameterKey] floatValue]);
    CGFloat blur = [[options objectForKey: BlurParameterKey] floatValue];
    
    // Create the shadow rect
    CGRect shadowRect = frame;
    
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

- (CGRect)strokeRectForRect: (CGRect)frame andWidth: (CGFloat)strokeWidth {
    // Create a stroke rect
    CGRect strokeRect = frame;
    CGPoint strokeOrigin = strokeRect.origin;
    strokeOrigin.x -= strokeWidth;
    strokeOrigin.y -= strokeWidth;
    strokeRect.origin = strokeOrigin;
    
    CGSize strokeSize = strokeRect.size;
    strokeSize.width += 2 * strokeWidth;
    strokeSize.height += 2 * strokeWidth;
    strokeRect.size = strokeSize;
    
    // Return the result
    return strokeRect;
}


- (void)flushCache {
    NSLog(@"Flushing cache");
    
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
    
    // Next get the size parameters of the main dictionary - that is the size of self
    CGSize size = CGSizeMake([[[JSONDictionary objectForKey: SizeParameterKey] objectForKey: WidthParameterKey] floatValue],
                             [[[JSONDictionary objectForKey: SizeParameterKey] objectForKey: HeightParameterKey] floatValue]);
    
    // Create the container view
    UIView *view = [[[UIView alloc] initWithFrame: CGRectMake(0.0, 0.0, size.width, size.height)] autorelease];
    
    if (view) {
        // Grab the subviews
        NSArray *options = [JSONDictionary objectForKey: SubviewSectionKey];
        
        // Add them all as subviews
        NSArray *views = [self viewsForDescriptions: options];
        [views enumerateObjectsWithOptions: NSEnumerationConcurrent usingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            [view insertSubview: obj atIndex: idx];
        }];
    }
    
    // If cache enabled, store the final view (additional layer of caching, incase an identical view hierarchy is used later)
    if (_isCached) {
        [_cache setObject: view forKey: JSONData];
    }
    
    return view;
}

- (void)dealloc {
    // Remove observer for the memory warning
    [[NSNotificationCenter defaultCenter] removeObserver: self name: UIApplicationDidReceiveMemoryWarningNotification object: nil];
    
    [_cache release];
    [super dealloc];
}

@end