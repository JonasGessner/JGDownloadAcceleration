
//
//  JGDownload.m
//  JGDownloadAcceleration Tester
//
//  Created by Jonas Gessner on 21.04.13.
//  Copyright (c) 2013 Jonas Gessner. All rights reserved.
//

#import "JGDownload.h"

@interface JGDownload () <NSURLConnectionDelegate, NSURLConnectionDataDelegate>

@property (nonatomic, strong, readonly) NSURLConnection *connection;

@end

@implementation JGDownload

#pragma mark NSURLConnectionDelegate methods
//completion states
- (void)connection:(NSURLConnection *)__unused connection didFailWithError:(NSError *)error {
    [self.downloadManager downloadDidFinish:self withError:error];
    _connection = nil;
}

- (void)connectionDidFinishLoading:(NSURLConnection *)__unused connection {
    [self.downloadManager downloadDidFinish:self withError:nil];
    _connection = nil;
}


//data handling
- (void)connection:(NSURLConnection *)__unused connection didReceiveData:(NSData *)data {
    [self.downloadManager download:self didReadData:data];
}

- (void)connection:(NSURLConnection *)__unused connection didReceiveResponse:(NSURLResponse *)response {
    [self.downloadManager download:self didReceiveResponse:(NSHTTPURLResponse *)response];
    [self.downloadManager downloadStarted:self];
}


#pragma mark - Handle Connection

- (instancetype)initWithRequest:(NSURLRequest *)request object:(JGResumeObject *)object manager:(id <JGDownloadManager>)manager {
    self = [super init];
    if (self) {
        _downloadManager = manager;
        _request = request;
        _object = object;
        
        NSParameterAssert(_request != nil);
        NSParameterAssert(_downloadManager != nil);
        NSParameterAssert(_object != nil);
    }
    return self;
}

- (void)cancel {
    //needs to be called on network thread!!
    _downloadManager = nil;
    [_connection cancel];
    _connection = nil;
}

- (void)retry {
//    NSLog(@"Error: Request failed, restarting");
    _connection = nil;
    [self startLoading];
}

- (BOOL)startLoading {
    //requires runloop, needs to be called on network Thread
    
    NSMutableURLRequest *finalRequest = self.request.mutableCopy;
    
    NSString *rangeText = NSStringFromJGRangeWithOffset(self.object.range, self.object.offset);
    
    [finalRequest setValue:rangeText forHTTPHeaderField:@"Range"]; //overrides the Range header (if present) in the original request
    
    _connection = [[NSURLConnection alloc] initWithRequest:finalRequest delegate:self startImmediately:NO];
    
    [_connection scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
    
    [_connection start];

    return YES;
}

@end
