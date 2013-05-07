//
//  JGOperationQueue.m
//  JGDownloadAccelerator Tester
//
//  Created by Jonas Gessner on 25.04.13.
//  Copyright (c) 2013 Jonas Gessner. All rights reserved.
//

#import "JGOperationQueue.h"

@interface JGDownloadOperation () //Private

//Network Thread Handling
+ (NSThread *)networkRequestThread;
+ (BOOL)networkRequestThreadIsAvailable;
+ (void)endNetworkThread;

@end


@interface JGOperationQueue () {
    UIBackgroundTaskIdentifier bgTask;
    BOOL running;
}

+ (NSThread *)operationThreadIfAvailable;

@end

@implementation JGOperationQueue

+ (NSThread *)operationThreadIfAvailable {
    return ([JGDownloadOperation networkRequestThreadIsAvailable] ? [JGDownloadOperation networkRequestThread] : nil);
}

- (id)init {
    self = [super init];
    if (self) {
        [self addObserver:self forKeyPath:@"operations" options:0 context:NULL];
        self.maxConcurrentOperationCount = 5;
    }
    return self;
}

- (void)startBackgroundTask {
    running = YES;
    bgTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        if (self.operationCount > 0) {
            [self startBackgroundTask];
        }
        else {
            bgTask = UIBackgroundTaskInvalid;
        }
    }];
}

- (void)stopBackgroundTaskAndNetworkThread {
    [[UIApplication sharedApplication] endBackgroundTask:bgTask];
    running = NO;
    [JGDownloadOperation endNetworkThread];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (object == self && [keyPath isEqualToString:@"operations"]) {
        [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:(self.operationCount > 0)];
        if (self.operationCount > 0 && !running) {
            [self startBackgroundTask];
        }
        else if (!self.operationCount && running) {
            [self stopBackgroundTaskAndNetworkThread];
        }
    }
    else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

@end
