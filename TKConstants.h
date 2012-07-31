//
//  TKConstants.h
//  ThemeEngine
//
//  Keys used in accessing the JSON descriptions of the views
//
//  Created by Henri Normak on 30/06/2012.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

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
