//
//  JGHEADRequest.m
//  JGDownloadAcceleration Tester
//
//  Created by Jonas Gessner on 05.05.13.
//  Copyright (c) 2013 Jonas Gessner. All rights reserved.
//

#import "JGHEADRequest.h"

@implementation JGHEADRequest

#pragma mark NSURLConnectionDelegate methods

- (void)connection:(NSURLConnection *)__unused connection didFailWithError:(NSError *)error {
    [self.delegate didRecieveResponse:nil error:error];
}

- (void)connection:(NSURLConnection *)__unused connection didReceiveResponse:(NSURLResponse *)response {
    [self cancel];
    [self.delegate didRecieveResponse:(NSHTTPURLResponse *)response error:nil];
}

#pragma mark - Handle Connection

- (instancetype)initWithRequest:(NSURLRequest *)request {
    self = [super init];
    if (self) {
        NSParameterAssert(request != nil);
        
        NSMutableURLRequest *newRequest = request.mutableCopy;
        
        [newRequest setHTTPMethod:@"HEAD"];
        
        headerConnection = [[NSURLConnection alloc] initWithRequest:newRequest delegate:self startImmediately:NO];
    }
    return self;
}

- (void)start {
    //requires runloop, method has to be called on netowrk thread
    [headerConnection scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
    [headerConnection start];
}

- (void)cancel {
    //method has to be called on netowrk thread
    [headerConnection cancel];
}

@end
