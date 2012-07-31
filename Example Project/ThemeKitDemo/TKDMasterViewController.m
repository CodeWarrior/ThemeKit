//
//  TKDMasterViewController.m
//  ThemeKitDemo
//
//  Created by Henri Normak on 01/07/2012.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "TKDMasterViewController.h"

#import "TKDDetailViewController.h"

@interface TKDMasterViewController () {
    NSArray *_objects;
}
@end

@implementation TKDMasterViewController

@synthesize detailViewController = _detailViewController;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        self.title = @"ThemeKit Examples";
        self.clearsSelectionOnViewWillAppear = NO;
        self.contentSizeForViewInPopover = CGSizeMake(320.0, 600.0);
    }
    
    return self;
}
							
- (void)dealloc {
    [_detailViewController release];
    [_objects release];
    [super dealloc];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Load in the folder with the example JSONs
    // To do this iterate over the example files 
    NSArray *paths = [[NSBundle mainBundle] pathsForResourcesOfType: nil inDirectory: @"Examples"];
    
    // Store the paths
    _objects = [paths retain];
    
    [self.tableView reloadData];
}

- (void)viewDidUnload {
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    
    [_objects release];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return YES;
}

#pragma mark - Table View

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _objects.count;
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"Cell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
    }
    
    // The objects stored are paths, grab the last component and remove the extension
    NSString *name = [[_objects objectAtIndex: indexPath.row] lastPathComponent];
    name = [name stringByDeletingPathExtension];
    cell.textLabel.text = [name capitalizedString];
    
    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the specified item to be editable.
    return YES;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    // Grab the file path
    NSString *path = [_objects objectAtIndex: indexPath.row];
    
    // Load in the data
    NSData *data = [NSData dataWithContentsOfFile: path];
    
    // Pass that to the detail controller
    self.detailViewController.exampleJSONData = data;
    
    // Adjust the title as well
    self.detailViewController.title = [[[[_objects objectAtIndex: indexPath.row] lastPathComponent] stringByDeletingPathExtension] capitalizedString];
}

@end
