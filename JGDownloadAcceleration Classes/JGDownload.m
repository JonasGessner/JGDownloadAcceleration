
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

@synthesize owner, connection, object, request;

#pragma mark NSURLConnectionDelegate methods
//completion states
- (void)connection:(NSURLConnection *)__unused _connection didFailWithError:(NSError *)error {
    [self.owner downloadDidFinish:self withError:error];
    connection = nil;
}

- (void)connectionDidFinishLoading:(NSURLConnection *)__unused _connection {
    [self.owner downloadDidFinish:self withError:nil];
    connection = nil;
}


//data handling
- (void)connection:(NSURLConnection *)__unused _connection didReceiveData:(NSData *)data {
    [self.owner download:self didReadData:data];
}

- (void)connection:(NSURLConnection *)__unused _connection didReceiveResponse:(NSURLResponse *)response {
    [self.owner download:self didReceiveResponse:(NSHTTPURLResponse *)response];
    [self.owner downloadStarted:self];
}


#pragma mark - Handle Connection

- (id)initWithRequest:(NSURLRequest *)_request object:(JGResumeObject *)_object owner:(id <JGDownloadManager>)_owner {
    self = [super init];
    if (self) {
        owner = _owner;
        request = _request;
        object = _object;
        
        NSParameterAssert(request != nil);
        NSParameterAssert(owner != nil);
        NSParameterAssert(object != nil);
    }
    return self;
}

- (void)cancel {
    //needs to be called on network thread!!
    owner = nil;
    [connection cancel];
    connection = nil;
}

- (void)retry {
//    NSLog(@"Error: Request failed, restarting");
    connection = nil;
    [self startLoading];
}

- (BOOL)startLoading {
    //requires runloop, needs to be called on network Thread
    
    NSMutableURLRequest *finalRequest = self.request.mutableCopy;
    
    NSString *rangeText = NSStringFromJGRangeWithOffset(self.object.range, self.object.offset);
    
    [finalRequest setValue:rangeText forHTTPHeaderField:@"Range"]; //overrides the Range header (if present) in the original request
    
    connection = [[NSURLConnection alloc] initWithRequest:finalRequest delegate:self startImmediately:NO];
    
    [connection scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
    
    [connection start];

    return YES;
}

@end
