//
//  ThemeKit
//
//  Created by Henri Normak on 13/11/2011.
//

#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

#import "JSONKit.h"

#pragma mark - UIColor extension

@interface UIColor (Extensions)

// Method for converting web hex color into a UIColor object, pass in a string similar to "FFFFFF" or "#FFFFFF"
// If less than six characters long, will be used as a pattern - "FFA" will result in "FFAFFA" and "FFFA" results in "FFFAFF"
+ (UIColor *)colorForWebColor: (NSString *)colorCode;

// Reverse of the first method, returning a hex value of a UIColor
- (NSString *)hexValue;

@end

#pragma mark - Keys for drawing

// Main parts of the JSON
static NSString *const SubviewSectionKey = @"subviews";

// Type keys, distinction between primitive shapes
static NSString *const TypeParameterKey = @"type";
static NSString *const RectangleTypeKey = @"rectangle";
static NSString *const EllipseTypeKey = @"ellipse";
static NSString *const PathTypeKey = @"path";
static NSString *const LabelTypeKey = @"label";
static NSString *const ButtonTypeKey = @"button";

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
static NSString *const BindingVariableName = @"bind-to";    // Additional bindings dictionary will be returned,
                                                            // where specific views will be accessable under specified names (similar to IBOutlet)
static NSString *const ContainerParameterKey = @"is-container"; // When set, the view is not drawn and is simply there for hierarchical reasons.
                                                                // only checked for rectangle (the rest wouldn't make sense to be used as containers)

// Label content
static NSString *const ContentStringParameterKey = @"content-string";
static NSString *const ContentColorParameterKey = @"content-color";
static NSString *const ContentGradientParameterKey = @"content-gradient-fill";
static NSString *const ContentShadowParameterKey = @"content-shadow";
static NSString *const ContentAlignmentParameterKey = @"content-align";
static NSString *const ContentFontSizeParameterKey = @"font-size";
static NSString *const ContentFontNameParameterKey = @"font-name";
static NSString *const ContentFontWeightParameterKey = @"font-weight";

// Button images/views
static NSString *const ButtonNormalStateView = @"normal-state";
static NSString *const ButtonHighlightedStateView = @"highlighted-state";
static NSString *const ButtonSelectedStateView = @"selected-state";
static NSString *const ButtonHighlightedSelectedStateView = @"highlighted-selected-state";  // If not present, but highlighted-state is, then that will be used for both
static NSString *const ButtonDisabledStateView = @"disabled-state";

static NSString *const ButtonViewStretchable = @"stretchable-edges";
static NSString *const ButtonContentImage = @"content-image";   // The image, displayed to the right of the label
static NSString *const ButtonContentInsets = @"content-insets"; // Insets are either arrays with 4 values or single value to be used for all sides
static NSString *const ButtonContentImageInsets = @"content-image-insets";

// Path description
static NSString *const PathDescriptionKey = @"description";

// Sizes
static NSString *const WidthParameterKey = @"width";
static NSString *const HeightParameterKey = @"height";
static NSString *const OffsetParameterKey = @"offset";

// Drop shadow
static NSString *const BlurParameterKey = @"blur";

// Gradients
static NSString *const GradientColorsParameterKey = @"gradient-colors";
static NSString *const GradientPositionsParameterKey = @"gradient-positions";

// Position
static NSString *const XCoordinateParameterKey = @"x";
static NSString *const YCoordinateParameterKey = @"y";

// Rounded corners
static NSString *const CornerRadiusParameterKey = @"corner-radius";     // Can be either a fixed value or an array of 1-4 values

#pragma mark - ThemeView Header

@interface ThemeKit : NSObject {
    BOOL _isCached;
    
    // Image cache, works wonders for images that are repeatedly
    // compressed - i.e custom button graphics etc.
    NSMutableDictionary *_imageCache;
    
    // Contains cached drawingblocks for TKViews, 
    // this is to make sure each caching returns a new view not one already in use
    NSMutableDictionary *_cache;
    
    // Secondary cache used to avoid deserializing files at paths
    // will cache the resulting JSON dictionary, which in turn will produce cached blocks (if possible)
    NSMutableDictionary *_JSONCache;
}

// Main initializer, used as a singleton
+ (ThemeKit *)defaultEngine;

// Main generator, uses caching on the solution, not the data
- (UIView *)viewHierarchyFromJSON: (NSData *)JSONData bindings: (NSDictionary **)bindings;

// Secondary generator, just as a convienience
- (UIView *)viewHierarchyForJSONAtPath: (NSString *)path bindings: (NSDictionary **)bindings;

// Another helpful method, will turn any given UIView hierarchy into a UIImage
- (UIImage *)compressedImageForView: (UIView *)view;

@end