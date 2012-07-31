//
//  TKDDetailViewController.m
//  ThemeKitDemo
//
//  Created by Henri Normak on 01/07/2012.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "TKDDetailViewController.h"

@interface TKDDetailViewController ()
@property (strong, nonatomic) UIPopoverController *masterPopoverController;

@property (strong, nonatomic) UIView *renderResult;
@property (strong, nonatomic) UIScrollView *renderView;

@property (strong, nonatomic) UITextView *sourceView;

- (void)keyboardChanged: (NSNotification *)notification;

- (void)balanceRenderView;
- (void)renderJSON;

@end

@implementation TKDDetailViewController

@synthesize exampleJSONData = _exampleJSONData;
@synthesize masterPopoverController = _masterPopoverController;

@synthesize renderResult = _renderResult;
@synthesize renderView = _renderView;

@synthesize sourceView = _sourceView;

- (void)dealloc {
    [_exampleJSONData release];
    [_renderResult release];
    [_renderView release];
    [_sourceView release];
    [_masterPopoverController release];
    [super dealloc];
}

#pragma mark - UITextViewDelegate

- (void)textViewDidChange:(UITextView *)textView {
    // Text changed, render the contents
    NSString *JSON = textView.text;
    
    // Test the JSON before rendering
    NSData *data = [JSON dataUsingEncoding: NSUTF8StringEncoding];
    
    // Use the NSData we created
    [_exampleJSONData autorelease];
    _exampleJSONData = [data retain];
    [self renderJSON];
}

#pragma mark - Keyboard notification

- (void)keyboardChanged: (NSNotification *)notification {
    // Adjust the view accordingly
    CGRect bounds = [[notification.userInfo objectForKey: UIKeyboardFrameEndUserInfoKey] CGRectValue];
    
    // Convert the rect to self.view
    bounds = [self.view convertRect: bounds fromView: [[UIApplication sharedApplication] keyWindow]];
    
    // Adjust the height of the views
    [UIView animateWithDuration: 0.25
                     animations:^{
         CGRect frame = self.sourceView.frame;
         frame.size.height = CGRectGetMinY(bounds);
         self.sourceView.frame = frame;
         
         frame = self.renderView.frame;
         frame.size.height = CGRectGetMinY(bounds);
         self.renderView.frame = frame;
                         
         // Balance the renderview (will make sure the render result is placed nicely)
         [self balanceRenderView];
     }];
    
    // Scroll the selected line of the textview to the center
    [self.sourceView scrollRangeToVisible: self.sourceView.selectedRange];
}

#pragma mark - Managing the detail item

- (void)setExampleJSONData:(NSData *)exampleJSONData {
    [_exampleJSONData autorelease];
    _exampleJSONData = [exampleJSONData retain];
    
    // Grab the source
    NSString *source = [[NSString alloc] initWithData: exampleJSONData encoding: NSUTF8StringEncoding];
    self.sourceView.text = source;
    [source release];
    
    // Re-render the view
    [self renderJSON];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Draw the background image (pattern image) from a predefined JSON
    UIImage *image = [[ThemeKit defaultEngine] compressedImageForJSONAtPath: [[NSBundle mainBundle] pathForResource: @"checkerboard" ofType: @"json"]];
    
    // Layout
    CGFloat halfWidth = CGRectGetWidth(self.view.frame) / 2.0;
    
    // Add the render view
    self.renderView = [[[UIScrollView alloc] initWithFrame: 
                        CGRectMake(0.0, 0.0, halfWidth, CGRectGetHeight(self.view.frame))] autorelease];
    self.renderView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    self.renderView.backgroundColor = [UIColor colorWithPatternImage: image];
    self.renderView.bounces = YES;
    self.renderView.delaysContentTouches = NO;
    [self.view addSubview: self.renderView];
    
    // Add the sourceView
    self.sourceView = [[[UITextView alloc] initWithFrame:
                        CGRectMake(halfWidth, 0.0, halfWidth, CGRectGetHeight(self.view.frame))] autorelease];
    self.sourceView.delegate = self;
    self.sourceView.editable = YES;
    self.sourceView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    self.sourceView.bounces = YES;
    
    [self.view addSubview: self.sourceView];
    
    // Start listening to keyboard notifications
    [[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(keyboardChanged:) name: UIKeyboardWillChangeFrameNotification object: nil];
}

- (void)viewDidUnload {
    [super viewDidUnload];
    
    self.renderView = nil;
    self.sourceView = nil;
    
    // Stop keyboard notifications
    [[NSNotificationCenter defaultCenter] removeObserver: self name: UIKeyboardDidChangeFrameNotification object: nil];
}

- (void)balanceRenderView {    
    // Move the rendered view to the center of the render view
    CGRect frame = self.renderResult.frame;
    CGPoint origin = frame.origin;
    origin.x = MAX(100.0, roundf((CGRectGetWidth(self.renderView.frame) - CGRectGetWidth(frame)) / 2.0));
    origin.y = MAX(100.0, roundf((CGRectGetHeight(self.renderView.frame) - CGRectGetHeight(frame)) / 2.0));
    frame.origin = origin;
    self.renderResult.frame = frame;
    
    // Adjust the content size of the renderView
    self.renderView.contentSize = CGSizeMake(CGRectGetMaxX(self.renderResult.frame) + 100.0, CGRectGetMaxY(self.renderResult.frame) + 100.0);
}

- (void)renderJSON {
    // Clear the contents of the scrollView
    for (UIView *view in self.renderView.subviews) {
        [view removeFromSuperview];
    }
    
    // Render the JSON into a view and place it into the scrollView
    self.renderResult = [[ThemeKit defaultEngine] viewHierarchyFromJSON: _exampleJSONData bindings: NULL];
    
    // Move the rendered view to the center of the render view
    CGRect frame = self.renderResult.frame;
    CGPoint origin = frame.origin;
    origin.x = MAX(100.0, roundf((CGRectGetWidth(self.renderView.frame) - CGRectGetWidth(frame)) / 2.0));
    origin.y = MAX(100.0, roundf((CGRectGetHeight(self.renderView.frame) - CGRectGetHeight(frame)) / 2.0));
    frame.origin = origin;
    self.renderResult.frame = frame;
    
    // Adjust the content size of the renderView
    self.renderView.contentSize = CGSizeMake(CGRectGetMaxX(self.renderResult.frame) + 100.0, CGRectGetMaxY(self.renderResult.frame) + 100.0);
    [self.renderView addSubview: self.renderResult];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return YES;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        self.title = @"Example";
    }
    return self;
}
							
#pragma mark - Split view

- (void)splitViewController:(UISplitViewController *)splitController willHideViewController:(UIViewController *)viewController withBarButtonItem:(UIBarButtonItem *)barButtonItem forPopoverController:(UIPopoverController *)popoverController {
    barButtonItem.title = @"Examples";
    [self.navigationItem setLeftBarButtonItem:barButtonItem animated:YES];
    self.masterPopoverController = popoverController;
}

- (void)splitViewController:(UISplitViewController *)splitController willShowViewController:(UIViewController *)viewController invalidatingBarButtonItem:(UIBarButtonItem *)barButtonItem {
    // Called when the view is shown again in the split view, invalidating the button and popover controller.
    [self.navigationItem setLeftBarButtonItem:nil animated:YES];
    self.masterPopoverController = nil;
}

@end
