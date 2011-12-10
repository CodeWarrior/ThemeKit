//
//  ThemeKit
//
//  Created by Henri Normak on 13/11/2011.
//

#import <UIKit/UIKit.h>

#import "JSONKit.h"

#pragma mark - Keys for drawing

// Main parts of the JSON
static NSString *const SubviewSectionKey = @"subviews";

// Type keys, distinction between primitive shapes
static NSString *const TypeParameterKey = @"type";
static NSString *const RectangleTypeKey = @"rectangle";
static NSString *const EllipseTypeKey = @"ellipse";
static NSString *const PathTypeKey = @"path";
static NSString *const LabelTypeKey = @"label";

// First some major parameters, that will have additional subparameters
static NSString *const InnerStrokeOptionKey = @"inner-stroke";
static NSString *const OuterStrokeOptionKey = @"outer-stroke";
static NSString *const GradientFillOptionKey = @"gradient-fill";
static NSString *const DropShadowOptionKey = @"drop-shadow";
static NSString *const InnerShadowOptionKey = @"inner-shadow";

// And general parameters
static NSString *const TitleParameterKey = @"title";    // Useful to identify the themes
static NSString *const ColorParameterKey = @"color";
static NSString *const OriginParameterKey = @"origin";
static NSString *const AlphaParameterKey = @"alpha";
static NSString *const SizeParameterKey = @"size";
static NSString *const BlendModeParameterKey = @"blend-mode";

// Label content
static NSString *const ContentStringParameterKey = @"content-string";
static NSString *const ContentFontSizeParameterKey = @"font-size";
static NSString *const ContentFontNameParameterKey = @"font-name";
static NSString *const ContentFontWeightParameterKey = @"font-weight";
static NSString *const ContentAlignmentParameterKey = @"content-align";

// Path description
static NSString *const PathDescriptionKey = @"description";

// Sizes
static NSString *const WidthParameterKey = @"width";
static NSString *const HeightParameterKey = @"height";

// Drop shadow
static NSString *const OffsetParameterKey = @"offset";
static NSString *const BlurParameterKey = @"blur";

// Line positioning
static NSString *const StartPointParameterKey = @"start-point";
static NSString *const EndPointParameterKey = @"end-point";

// Gradients
static NSString *const GradientColorsParameterKey = @"gradient-colors";
static NSString *const GradientPositionsParameterKey = @"gradient-positions";

// Position, gradient start and end (inside)
static NSString *const XCoordinateParameterKey = @"x";
static NSString *const YCoordinateParameterKey = @"y";

// Rounded corners
static NSString *const CornerRadiusParameterKey = @"corner-radius";     // Can be either a fixed value or an array of 1-4 values

#pragma mark - ThemeView Header

@interface ThemeKit : NSObject {    
    BOOL _isCached;
    NSMutableDictionary *_cache; // Contains UIImages/UIViews for NSDictionary descriptions of the view/part of it
    // Two tiered cache is used, first it checks if the entire description has been already drawn, if not, it also checks for each view separately
}

// Main initializer, used as a singleton
+ (ThemeKit *)defaultEngine;

// Main generator, uses caching on the solution, not the data
- (UIView *)viewHierarchyFromJSON: (NSData *)JSONData;

// Secondary generator, uses caching on both the solution and the data given (both point to same image in the cache)
- (UIView *)viewHierarchyForJSONAtPath: (NSString *)path;

@end
