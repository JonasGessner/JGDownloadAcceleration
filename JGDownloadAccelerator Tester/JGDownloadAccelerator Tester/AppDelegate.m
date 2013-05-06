//
//  AppDelegate.m
//  JGDownloadAccelerator Tester
//
//  Created by Jonas Gessner on 20.04.13.
//  Copyright (c) 2013 Jonas Gessner. All rights reserved.
//

#import "AppDelegate.h"

#import "ViewController.h"

#import "JGDownloadOperation.h"

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    // Override point for customization after application launch.
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        self.viewController = [[ViewController alloc] initWithNibName:@"ViewController_iPhone" bundle:nil];
    } else {
        self.viewController = [[ViewController alloc] initWithNibName:@"ViewController_iPad" bundle:nil];
    }
    self.window.rootViewController = self.viewController;
    [self.window makeKeyAndVisible];
    
    //get a valid URL for a video file from YouTube
    LBYouTubeExtractor *ex = [[LBYouTubeExtractor alloc] initWithID:@"1aqwk5Ip6cM" quality:LBYouTubeVideoQualitySmall];
    ex.delegate = self;
    [ex startExtracting];
    
    return YES;
}

- (void)youTubeExtractor:(LBYouTubeExtractor *)extractor didSuccessfullyExtractYouTubeURL:(NSURL *)videoURL {
    NSString *file = [NSTemporaryDirectory() stringByAppendingPathComponent:@"DL.mp4"];
    
    BOOL resume = YES;
    
    //start downloading the YouTube video to the temporary directory
    JGDownloadOperation *operation = [[JGDownloadOperation alloc] initWithURL:videoURL destinationPath:file resume:resume];
    
    [operation setMaxConnections:6];
    
    [operation setCompletionBlockWithSuccess:
     ^(JGDownloadOperation *operation) {
        NSLog(@"SUCCESS");
    } failure:^(JGDownloadOperation *operation, NSError *error) {
        NSLog(@"FIAILED %@", error.localizedDescription);
    }];
    
    __block NSTimeInterval started;
    
    [operation setDownloadProgressBlock:^(NSUInteger bytesRead, unsigned long long totalBytesReadThisSession, unsigned long long totalBytesWritten, unsigned long long totalBytesExpectedToRead, NSUInteger tag) {
        NSTimeInterval delta = [NSDate timeIntervalSinceReferenceDate]-started;
        NSLog(@"PROGRESS %llu/%llu : %.2f%% SPEED %.2f kB/s", totalBytesWritten, totalBytesExpectedToRead, ((double)totalBytesWritten/(double)totalBytesExpectedToRead)*100.0f, totalBytesReadThisSession/1024.0f/delta);
    }];
    
    [operation setOperationStartedBlock:^(NSUInteger tag, unsigned long long totalBytesExpectedToRead) {
        started = [NSDate timeIntervalSinceReferenceDate];
        NSLog(@"STARTED");
    }];
    
    if (!q) {
        q = [[JGOperationQueue alloc] init];
    }
    
    [q addOperation:operation];
}

- (void)youTubeExtractor:(LBYouTubeExtractor *)extractor failedExtractingYouTubeURLWithError:(NSError *)error {
    NSLog(@"YT EXTRCATOR DID FAIL %@", error.localizedDescription);
}

- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

@end
