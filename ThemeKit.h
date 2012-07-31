//
//  ThemeKit
//
//  An open-source Core Graphics drawing engine. Original source - https://github.com/henrinormak/ThemeKit
//
//  Created by Henri Normak on 13/11/2011.
//

#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

#import "TKHelpers.h"
#import "TKConstants.h"

// JSONKit, needed for < iOS 5, after that NSJSONSerialization is preferred
#import "JSONKit.h"

// Macro that will enable caching, set to 0 to disable caching
#define kCachingEnabled 1

#pragma mark - ThemeView Header

@interface ThemeKit : NSObject {    
    // Image cache, works wonders for images that are repeatedly
    // compressed - i.e custom button graphics etc.
    NSCache *_imageCache;
    
    // Contains cached drawingblocks for TKViews, 
    // this is to make sure each caching returns a new view not one already in use
    NSCache *_cache;
    
    // Secondary cache used to avoid deserializing files at paths
    // will cache the resulting JSON dictionary, which in turn will produce cached blocks (if possible)
    NSCache *_JSONCache;
}

// Main initializer, used as a singleton
+ (ThemeKit *)defaultEngine;

// Force a flush of cache, although NSCache takes care of memory warnings automatically, 
// there may be situations in which flushing the cache is a good idea
- (void)flushCache;

// Main generator, uses caching on the solution, not the data
- (UIView *)viewHierarchyFromJSON: (NSData *)JSONData bindings: (NSDictionary **)bindings;

// Secondary generator, just as a convienience
- (UIView *)viewHierarchyForJSONAtPath: (NSString *)path bindings: (NSDictionary **)bindings;

// Preffered way of creating images, will cache the results
- (UIImage *)compressedImageForJSONAtPath: (NSString *)path;

// A helper, will not cache the result, but can be useful nevertheless
- (UIImage *)compressedImageForView: (UIView *)view;

@end