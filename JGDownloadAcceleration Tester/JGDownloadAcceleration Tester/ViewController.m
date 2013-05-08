//
//  ViewController.m
//  JGDownloadAcceleration Tester
//
//  Created by Jonas Gessner on 20.04.13.
//  Copyright (c) 2013 Jonas Gessner. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
}

- (BOOL)shouldAutorotate {
    return YES;
}

- (NSUInteger)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskAll;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    UIScrollView *scroll = self.view.subviews.lastObject;
    scroll.contentSize = CGSizeMake(scroll.contentSize.width, [UIScreen mainScreen].bounds.size.height*1.5f);
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
