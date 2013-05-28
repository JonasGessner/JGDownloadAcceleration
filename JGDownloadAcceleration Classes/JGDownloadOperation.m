//
//  JGDownloadOperation.m
//  JGDownloadAcceleration Tester
//
//  Created by Jonas Gessner on 21.04.13.
//  Copyright (c) 2013 Jonas Gessner. All rights reserved.
//

#import "JGDownloadOperation.h"
#import "JGDownload.h"
#import "JGDownloadDefines.h"
#import "JGOperationQueue.h"
#import "JGHEADRequest.h"
#import "JGDownloadResumeMetadata.h"

@interface JGDownloadOperation () //Private

//Network Thread Handling
+ (NSThread *)networkRequestThread;
+ (BOOL)networkRequestThreadIsAvailable;
+ (void)endNetworkThread;

@end


@interface JGDownloadOperation () <JGDownloadManager, JGHEADRequestDelegate> {
    BOOL waitForContentLength;
    
    JGRange contentRange;
    
    NSUInteger finished;
    BOOL append;
    NSUInteger errorRetryAttempts;
    
    BOOL completed;
    BOOL executing;
    BOOL cancelled;
    
    BOOL splittingUnavailable;
    
    unsigned long long resumedAtSize;
    
    BOOL clear;
    
    JGHEADRequest *headerProvider;
    
    NSFileHandle *output;
    JGDownloadResumeMetadata *resume;
}

@property (nonatomic, copy) JGConnectionOperationProgressBlock downloadProgress;
@property (nonatomic, copy) JGConnectionOperationStartedBlock started;

@property (nonatomic, assign) NSUInteger numberOfConnections; //actual number of connections, not maximum number

@property (nonatomic, strong, readonly) NSArray *connections;

- (void)getHTTPHeadersAndProceed;
- (void)startLoadingAllConnectionsAndOpenOutput;

- (void)startSingleRequest;

- (void)didReceiveHTTPHeaders:(NSHTTPURLResponse *)response error:(NSError *)_error;

@end

@implementation JGDownloadOperation

@synthesize maximumNumberOfConnections, destinationPath, connections, tag, error, downloadProgress, started, numberOfConnections, retryCount, originalRequest;


#pragma mark - Network Thread

+ (void)networkRequestThreadEntryPoint:(id)__unused object {
    @autoreleasepool {
        [[NSThread currentThread] setName:@"JGDownloadAcceleration"];
        do {
            [[NSRunLoop currentRunLoop] run];
        }
        while (YES);
    }
}

static NSThread *_networkRequestThread = nil;

+ (void)endNetworkThread {
    if (!_networkRequestThread) {
        return;
    }
    
    if ([NSThread currentThread] == _networkRequestThread) {
        [NSThread exit];
    }
    else {
        [NSThread performSelector:@selector(exit) onThread:_networkRequestThread withObject:nil waitUntilDone:NO];
    }
    
    _networkRequestThread = nil;
}

+ (BOOL)networkRequestThreadIsAvailable {
    return (_networkRequestThread != nil);
}

+ (NSThread *)networkRequestThread {
    if (!_networkRequestThread) {
        _networkRequestThread = [[NSThread alloc] initWithTarget:self selector:@selector(networkRequestThreadEntryPoint:) object:nil];
        [_networkRequestThread start];
    }
    
    return _networkRequestThread;
}

#pragma mark - General

- (id)initWithURL:(NSURL *)_url destinationPath:(NSString *)_path allowResume:(BOOL)_resume {
    self = [super init];
    if (self) {
        destinationPath = _path;
        originalRequest = [NSURLRequest requestWithURL:_url];
        append = _resume;
        
        NSParameterAssert(originalRequest != nil);
        NSParameterAssert(destinationPath != nil);
    }
    return self;
}

- (instancetype)initWithRequest:(NSURLRequest *)request destinationPath:(NSString *)_path allowResume:(BOOL)_resume {
    self = [super init];
    if (self) {
        if ([request HTTPMethod] != nil && ![request.HTTPMethod isEqualToString:@"GET"]) {
            @throw [NSException exceptionWithName:@"Invalid Request" reason:@"JGDownloadAcceleration only supports HTTP GET requests" userInfo:nil];
            return nil;
        }
        destinationPath = _path;
        originalRequest = request;
        append = _resume;
        
        NSParameterAssert(originalRequest != nil);
        NSParameterAssert(destinationPath != nil);
    }
    return self;
}

- (NSString *)downloadMetadataPathForFilePath:(NSString *)file {
    return [[file stringByDeletingPathExtension] stringByAppendingPathExtension:@"jgd"];
}

- (void)start {
    if ([self isReady]) {
        [self performSelector:@selector(main) onThread:[[self class] networkRequestThread] withObject:nil waitUntilDone:NO];
    }
    else {
        NSLog(@"Error: Cannot start Operation: Operation is not ready to start");
    }
}

- (void)main {
    error = nil;
    completed = NO;
    cancelled = NO;
    splittingUnavailable = NO;
    resumedAtSize = 0;
    waitForContentLength = NO;
    
    [self willChangeValueForKey:@"isExecuting"];
    executing = YES;
    [self didChangeValueForKey:@"isExecuting"];
    
    
    BOOL reallyAppend = append;
    if (![[NSFileManager defaultManager] fileExistsAtPath:self.destinationPath]) {
        reallyAppend = NO;
    }
    else if (![[NSFileManager defaultManager] fileExistsAtPath:[self downloadMetadataPathForFilePath:self.destinationPath]]) {
        if ([[NSFileManager defaultManager] fileExistsAtPath:self.destinationPath]) {
            [[NSFileManager defaultManager] removeItemAtPath:self.destinationPath error:nil];
            reallyAppend = NO;
        }
        else {
            reallyAppend = NO;
        }
    }
    
    JGRange rangeOfOriginalRequest;
    
    NSString *rangeText = [self.originalRequest valueForHTTPHeaderField:@"Range"];
    if (rangeText.length) {
        NSArray *components = [[rangeText stringByReplacingOccurrencesOfString:@"bytes=" withString:@""] componentsSeparatedByString:@"-"];
        NSString *locationText;
        NSString *lengthText;
        if (components.count) {
            locationText = components[0];
            if (components.count > 1) {
                lengthText = components[1];
            }
            unsigned long long location = (unsigned long long)locationText.longLongValue;
            unsigned long long length = (unsigned long long)lengthText.longLongValue-location; //Convert HTTP Range to JGRange (NSRange style)
            
            rangeOfOriginalRequest = JGRangeMake(location, length, (lengthText == nil));
        }
    }
    
    BOOL originalRequestHasRange = (rangeText.length > 0);
    
    if (self.maximumNumberOfConnections == 1) {
        if (reallyAppend) {
            NSString *metaPath = [self downloadMetadataPathForFilePath:destinationPath];
            resume = [[JGDownloadResumeMetadata alloc] initWithContentsAtPath:metaPath];
            [self resumeConnectionsFromResumeMetadata];
        }
        else {
            if (originalRequestHasRange) {
                contentRange = rangeOfOriginalRequest;
            }
            else {
                waitForContentLength = YES; //content length is unknown. Wait for download:didReceiveResponse: to eventually set the contentRange and be aware of the content length
            }
            
            if ([[NSFileManager defaultManager] fileExistsAtPath:self.destinationPath]) {
                [[NSFileManager defaultManager] removeItemAtPath:self.destinationPath error:nil];
            }
            [[NSFileManager defaultManager] createFileAtPath:self.destinationPath contents:nil attributes:nil];
            
            [self startSingleRequest]; //Number of connections is 1, only run 1 request
        }
    }
    else {
        if (reallyAppend) {
            NSString *metaPath = [self downloadMetadataPathForFilePath:destinationPath];
            resume = [[JGDownloadResumeMetadata alloc] initWithContentsAtPath:metaPath];
            [self resumeConnectionsFromResumeMetadata];
        }
        else {
            if ([[NSFileManager defaultManager] fileExistsAtPath:self.destinationPath]) {
                [[NSFileManager defaultManager] removeItemAtPath:self.destinationPath error:nil];
            }
            [[NSFileManager defaultManager] createFileAtPath:self.destinationPath contents:nil attributes:nil];
            
            if (originalRequestHasRange) { //don't request the HTTP headers if the range has already been set in the original request
                contentRange = rangeOfOriginalRequest;
                [self startSplittedConnections];
            }
            else {
                [self getHTTPHeadersAndProceed];
            }
        }
    }
}


#pragma mark - Starting Operations

- (void)startLoadingAllConnectionsAndOpenOutput {
    output = [NSFileHandle fileHandleForWritingAtPath:self.destinationPath];
    
    for (JGDownload *download in connections) {
        [download startLoading];
    }
}

- (void)downloadStarted:(JGDownload *)download {
    if (started) {
        started(self.tag, self.contentLength);
        started = nil;
    }
}

#pragma mark - Resume Connection

- (void)resumeConnectionsFromResumeMetadata {
    contentRange = JGRangeMake(0, resume.totalSize, NO); //The original location is not stored in the resume metadata because it is irelevant when resuming a request
    
    resumedAtSize = resume.currentSize;
    
    NSMutableArray *preConnections = [NSMutableArray array];
    
    for (JGResumeObject *object in resume) {
        if (object.range.final ? object.range.location+object.offset < self.contentLength : object.offset <= object.range.length) {
            JGDownload *download = [[JGDownload alloc] initWithRequest:self.originalRequest object:object owner:self];
            [preConnections addObject:download];
        }
    }
    
    self.numberOfConnections = preConnections.count; //ignores maximum number, as its resuming the previous state of the operation
    
    if (!self.numberOfConnections) {
        NSLog(@"Error: Cannot Resume Operation: Tried to Resume Operation but there are no connections to resume");
        [self completeOperation];
        return;
    }
    
    connections = preConnections.copy;
    
    [self startLoadingAllConnectionsAndOpenOutput];
}

#pragma mark - New Connection

- (void)startSplittedConnections {
    self.numberOfConnections = (splittingUnavailable ? 1 : self.maximumNumberOfConnections); //is the Range header supported? If yes use max number of connections, if not use 1 connection
    
    NSString *metaPath = [self downloadMetadataPathForFilePath:self.destinationPath];
    resume = [[JGDownloadResumeMetadata alloc] initWithNumberOfConnections:self.numberOfConnections filePath:metaPath];
    [resume setTotalSize:self.contentLength];
    
    unsigned long splittedRest = (self.contentLength % self.numberOfConnections);
    unsigned long long evenSplitter = self.contentLength-splittedRest;
    unsigned long long singleLength = evenSplitter/self.numberOfConnections;
    
    unsigned long long currentOffset = contentRange.location;
    
    NSMutableArray *preConnections = [NSMutableArray array];
    
    for (unsigned int i = 0; i < self.numberOfConnections; i++) {
        unsigned long rangeLength = (i == 0 ? singleLength+splittedRest : singleLength)-1;
        
        JGRange range = JGRangeMake(currentOffset, rangeLength, NO);
        currentOffset += rangeLength;
        
        JGResumeObject *object = [[JGResumeObject alloc] initWithRange:range offset:0];
        [resume addObject:object];
        
        JGDownload *download = [[JGDownload alloc] initWithRequest:self.originalRequest object:object owner:self];
        [preConnections addObject:download];
    }
    
    connections = preConnections;
    
    [self startLoadingAllConnectionsAndOpenOutput];
}

- (void)startSingleRequest { //When the Range header is not supported or the number of connections is 1
    self.numberOfConnections = 1;
    
    NSString *metaPath = [self downloadMetadataPathForFilePath:self.destinationPath];
    resume = [[JGDownloadResumeMetadata alloc] initWithNumberOfConnections:self.numberOfConnections filePath:metaPath];
    
    JGRange range = JGRangeMake(contentRange.location, self.contentLength, YES);
    
    JGResumeObject *object = [[JGResumeObject alloc] initWithRange:range offset:0];
    
    JGDownload *download = [[JGDownload alloc] initWithRequest:self.originalRequest object:object owner:self];
    
    connections = @[download];
    
    [self startLoadingAllConnectionsAndOpenOutput];
}

#pragma mark - HTTP Headers

- (void)didReceiveHTTPHeaders:(NSHTTPURLResponse *)response error:(NSError *)_error {
    if (_error) {
        error = _error;
        [self completeOperation];
    }
    else {
        NSDictionary *headers = [response allHeaderFields];
        
        if (!splittingUnavailable) {
            splittingUnavailable = ![[headers objectForKey:@"Accept-Ranges"] hasPrefix:@"bytes"];
        }
        
        contentRange = JGRangeMake(0, (unsigned long long)[response expectedContentLength], NO);
        
        unsigned long long free = getFreeSpace(self.destinationPath.stringByDeletingLastPathComponent, nil);
        
        if (free <= self.contentLength) {
            error = [NSError errorWithDomain:@"de.j-gessner.JGDownloadAcceleration" code:409 userInfo:@{NSLocalizedDescriptionKey : @"There's not enough free space on the disk to download this file"}]; //409 = Conflict
            [self completeOperation];
            return;
        }
        
        if (resume && splittingUnavailable) {
            [self startSingleRequest];
        }
        else {
            [self startSplittedConnections];
        }
    }
}

- (void)didRecieveResponse:(NSHTTPURLResponse *)response error:(NSError *)_error {
    headerProvider = nil;
    [self didReceiveHTTPHeaders:response error:_error];
}

- (void)getHTTPHeadersAndProceed {
    headerProvider = [[JGHEADRequest alloc] initWithRequest:self.originalRequest];
    headerProvider.delegate = self;
    [headerProvider start];
}

#pragma mark - Delegate Blocks


- (void)setOperationStartedBlock:(void (^)(NSUInteger tag, unsigned long long totalBytesExpectedToRead))block {
    self.started = block;
}

- (void)setDownloadProgressBlock:(void (^)(NSUInteger bytesRead, unsigned long long totalBytesReadThisSession, unsigned long long totalBytesRead, unsigned long long totalBytesExpectedToRead, NSUInteger tag))block {
    self.downloadProgress = block;
}

- (void)setCompletionBlock:(void (^)(void))block {
    if (!block) {
        [super setCompletionBlock:NULL];
    } else {
        __weak __typeof(&*self) weakSelf = self;
        [super setCompletionBlock:^ {
            __strong __typeof(&*weakSelf) strongSelf = weakSelf;
            
            block();
            [strongSelf setCompletionBlock:NULL];
        }];
    }
}

- (void)setCompletionBlockWithSuccess:(void (^)(JGDownloadOperation *op))success failure:(void (^)(JGDownloadOperation *op, NSError *_error))failure {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-retain-cycles"
    self.completionBlock = ^{
        if (self.isCancelled) {
            if (!clear) {
                failure(self, [NSError errorWithDomain:@"de.j-gessner.JGDownloadAcceleration" code:NSURLErrorCancelled userInfo:@{NSLocalizedDescriptionKey : @"The Download was Cancelled"}]);
            }
        }
        else if (!!self.error) {
            if (failure && !!self.error) {
                failure(self, self.error);
            }
        } else {
            if (success) {
                success(self);
            }
        }
    };
#pragma clang diagnostic pop
}

#pragma mark - JGDownloadDelegate

- (void)download:(JGDownload *)download didReceiveResponse:(NSHTTPURLResponse *)response {
    if (waitForContentLength) {
        contentRange = JGRangeMake(0, (unsigned long long)[response expectedContentLength], NO);
        [resume setTotalSize:self.contentLength];
        waitForContentLength = NO;
    }
}

- (void)download:(JGDownload *)download didReadData:(NSData *)data {
    JGResumeObject *object = download.object;
    
    NSUInteger realLength = data.length;
    
    unsigned long long length = (unsigned long long)realLength;
    
    resume.currentSize += length;
    
    unsigned long long offset = object.offset;
    unsigned long long finalLocation = object.range.location+offset;
    
    [output seekToFileOffset:finalLocation];
    [output writeData:data];
    
    if (self.downloadProgress && !completed) {
        self.downloadProgress(realLength, resume.currentSize-resumedAtSize, resume.currentSize, self.contentLength, self.tag);
    }
    [output synchronizeFile];
    
    offset += length;
    
    [object setOffset:offset];
    if (append) {
        [resume write];
    }
}

- (NSUInteger)retryCount {
    NSUInteger retry = retryCount;
    if (!retry) {
        retry = (NSUInteger)self.numberOfConnections/2;
    }
    return retry;
}

- (void)downloadDidFinish:(JGDownload *)download withError:(NSError *)_error {
    if (_error) {
        if (errorRetryAttempts > retryCount) {
//            NSLog(@"Error: Cannot finish Operation: Too many errors occured, canceling");
            error = _error;
            [self completeOperation];
        }
        else {
            [download retry];
            errorRetryAttempts++;
        }
    }
    else {
        NSMutableArray *cons = [connections mutableCopy];
        [cons removeObjectIdenticalTo:download];
        connections = cons.copy;
        if (!connections.count) {
            connections = nil;
            [self completeOperation];
        }
    }
}

#pragma mark - Completion

- (void)operationFinishedCleanup {
    [headerProvider cancel];
    headerProvider = nil;
    
    for (JGDownload *download in self.connections) {
        [download cancel];
    }
    
    connections = nil;
    
    [output closeFile];
    
    output = nil;
    
    if ((self.error || !clear || (self.isCancelled && !clear)) && append) { //write when error, cancelled, or not told to remove file
        [resume write];
    }
    else {
        [resume removeFile];
    }
    
    resume = nil;
}

- (void)cancelAndClearFiles { //probably called from main thread
    clear = YES; //will clear
    
    [self cancel];
    [[NSFileManager defaultManager] removeItemAtPath:self.destinationPath error:nil];
}

- (void)cancel {
    if (!self.isExecuting) {
        NSLog(@"Error: Cannot Cancel Operation: Operation is not executing");
        return;
    }
    
    //clear will be NO when not called -cancelAndClearFiles
    
    BOOL calledOnConnectionThread = ([NSThread currentThread] == [[self class] networkRequestThread]);
    
    if (calledOnConnectionThread) {
        [self operationFinishedCleanup];
    }
    else {
        [self performSelector:@selector(operationFinishedCleanup) onThread:[[self class] networkRequestThread] withObject:nil waitUntilDone:NO];
    }
    
    [self willChangeValueForKey:@"isExecuting"];
    [self willChangeValueForKey:@"isFinished"];
    executing = NO;
    completed = YES;
    cancelled = YES;
    [super cancel];
    [self didChangeValueForKey:@"isFinished"];
    [self didChangeValueForKey:@"isExecuting"];
}

- (void)completeOperation {
    if (!self.isExecuting) {
        NSLog(@"Error: Cannot Complete Operation: Operation is not executing");
        return;
    }
    
    clear = YES;
    
    [self operationFinishedCleanup];
    
    [self willChangeValueForKey:@"isExecuting"];
    [self willChangeValueForKey:@"isFinished"];
    completed = YES;
    executing = NO;
    [self didChangeValueForKey:@"isFinished"];
    [self didChangeValueForKey:@"isExecuting"];
}

#pragma mark - States

- (BOOL)isConcurrent {
    return YES;
}

- (BOOL)isExecuting {
    return executing;
}

- (BOOL)isFinished {
    return completed;
}

#pragma mark - Custom Property Getters & Setters

- (unsigned long long)contentLength {
    return contentRange.length;
}

- (NSUInteger)numberOfConnections {
    if (!numberOfConnections) {
        return defaultMaxConnections();
    }
    else {
        return numberOfConnections;
    }
}

@end
