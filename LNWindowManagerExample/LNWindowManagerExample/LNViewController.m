//
//  LNViewController.m
//  LNWindowManagerExample
//
//  Created by Leo Natan on 3/10/14.
//  Copyright (c) 2014 Leo Natan. All rights reserved.
//

#import "LNViewController.h"
#import "LNWindowManager.h"

@interface LNViewController ()

@end

@implementation LNViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)displayButtonTapped:(UIButton *)sender
{
	UINavigationController* nvc = [self.storyboard instantiateViewControllerWithIdentifier:@"__presentationNVC"];
	nvc.topViewController.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(dismissWindow:)];
	
	UIWindow* window = [LNWindowManager templateWindowForName:@"demo"];
	window.rootViewController = nvc;
	
	[[LNWindowManager sharedWindowManager].topWindow presentWindow:window animated:YES completion:nil];
}

- (void)dismissWindow:(UIBarButtonItem*)barButtonItem
{
	[[LNWindowManager sharedWindowManager].topWindow.presentingWindow dismissWindow:[LNWindowManager sharedWindowManager].topWindow animated:YES completion:nil];
}

@end
