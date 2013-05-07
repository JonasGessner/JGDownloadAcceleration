
//
//  JGDownload.m
//  JGDownloadAccelerator Tester
//
//  Created by Jonas Gessner on 21.04.13.
//  Copyright (c) 2013 Jonas Gessner. All rights reserved.
//

#import "JGDownload.h"

@interface JGDownload () <NSURLConnectionDelegate, NSURLConnectionDataDelegate>

@property (nonatomic, strong, readonly) NSURLConnection *connection;

@end

@implementation JGDownload

@synthesize owner, url, connection, object;

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
    [self.owner downloadStarted:self];
}


#pragma mark - Handle Connection

- (id)initWithURL:(NSURL *)_url object:(JGResumeObject *)_object owner:(id <JGDownloadManager>)_owner {
    self = [super init];
    if (self) {
        owner = _owner;
        url = _url;
        object = _object;
        
        NSParameterAssert(url != nil);
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
    NSLog(@"Error: Request failed, restarting");
    connection = nil;
    [self startLoading];
}

- (BOOL)startLoading {
    //requires runloop, needs to be called on network Thread
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:self.url];
    
    [request setValue:USER_AGENT forHTTPHeaderField:@"User-Agent"];
    
    NSString *rangeText = NSStringFromJGRangeWithOffset(self.object.range, self.object.offset);
    
    [request setValue:rangeText forHTTPHeaderField:@"Range"];
    
    connection = [[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately:NO];
    
    [connection scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
    
    [connection start];

    return YES;
}

@end
