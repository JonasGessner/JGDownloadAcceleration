//
//  AppDelegate.m
//  JGDownloadAcceleration Tester
//
//  Created by Jonas Gessner on 20.04.13.
//  Copyright (c) 2013 Jonas Gessner. All rights reserved.
//

#import "AppDelegate.h"

#import "ViewController.h"

#import "JGDownloadAcceleration.h"

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
    [self load];
    
    return YES;
}

- (void)load {
    LBYouTubeExtractor *ex = [[LBYouTubeExtractor alloc] initWithID:@"1aqwk5Ip6cM" quality:LBYouTubeVideoQualityLarge];
    ex.delegate = self;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        [ex startExtracting]; //Don't put LBYouTubeExtractor on the main thread..
        CFRunLoopRun(); //give the LBYouTubeExtractor a run loop (or better, the NSURLConnection used inside LBYouTubeExtractor
    });
}

- (void)youTubeExtractor:(LBYouTubeExtractor *)extractor didSuccessfullyExtractYouTubeURL:(NSURL *)_videoURL {
    CFRunLoopStop(CFRunLoopGetCurrent()); //stop the run loop on the background queue that we started in -application:didFinishLaunchingWithOptions:
    NSURL *videoURL = [NSURL URLWithString:[[[_videoURL.absoluteString stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
    
    if (!videoURL.absoluteString) {
        return [self load];
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{ //go back to the main thread (not necessary)
        NSString *file = [NSTemporaryDirectory() stringByAppendingPathComponent:@"DL.mp4"];
        
        NSLog(@"URL %@", videoURL);
        
        BOOL resume = YES;
        
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:videoURL];
        
        //customize the request if needed... Example:
        [request setTimeoutInterval:90.0];
        
        
        //start downloading the YouTube video to the temporary directory
        JGDownloadOperation *operation = [[JGDownloadOperation alloc] initWithRequest:request destinationPath:file allowResume:resume];
        
        [operation setMaximumNumberOfConnections:6];
        [operation setRetryCount:3];
        
        __block CFTimeInterval started;
        
        [operation setCompletionBlockWithSuccess:^(JGDownloadOperation *operation) {
             double kbLength = (double)operation.contentLength/1024.0f;
             CFTimeInterval delta = CFAbsoluteTimeGetCurrent()-started;
             NSLog(@"Success! Downloading %.2f MB took %.1f seconds, average Speed: %.2f kb/s", kbLength/1024.0f, delta, kbLength/delta);
         } failure:^(JGDownloadOperation *operation, NSError *error) {
             NSLog(@"Operation Failed: %@", error.localizedDescription);
         }];
        
        [operation setDownloadProgressBlock:^(NSUInteger bytesRead, unsigned long long totalBytesReadThisSession, unsigned long long totalBytesWritten, unsigned long long totalBytesExpectedToRead, NSUInteger tag) {
            CFTimeInterval delta = CFAbsoluteTimeGetCurrent()-started;
            NSLog(@"Progress: %.2f%% Average Speed: %.2f kB/s", ((double)totalBytesWritten/(double)totalBytesExpectedToRead)*100.0f, totalBytesReadThisSession/1024.0f/delta);
        }];
        
        [operation setOperationStartedBlock:^(NSUInteger tag, unsigned long long totalBytesExpectedToRead) {
            started = CFAbsoluteTimeGetCurrent();
            NSLog(@"Operation Started, JGDownloadAcceleration version %@", kJGDownloadAccelerationVersion);
        }];
        
        if (!q) {
            q = [[JGOperationQueue alloc] init];
            q.handleNetworkActivityIndicator = YES;
            q.handleBackgroundTask = YES;
        }
        
        [q addOperation:operation];
    });
}

- (void)youTubeExtractor:(LBYouTubeExtractor *)extractor failedExtractingYouTubeURLWithError:(NSError *)error {
    CFRunLoopStop(CFRunLoopGetCurrent()); //stop the background run loop we started in -application:didFinishLaunchingWithOptions:
    NSLog(@"YouTube Extractor Failed With Error: %@", error.localizedDescription);
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
