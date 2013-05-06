//
//  JGDownloadOperation.m
//  JGDownloadAccelerator Tester
//
//  Created by Jonas Gessner on 21.04.13.
//  Copyright (c) 2013 Jonas Gessner. All rights reserved.
//

#import "JGDownloadOperation.h"
#import "JGDownload.h"
#import "JGDownloadDefines.h"
#import "JGOperationQueue.h"

@interface JGDownloadOperation () //Private

//Network Thread Handling
+ (NSThread *)networkRequestThread;
+ (BOOL)networkRequestThreadIsAvailable;
+ (void)endNetworkThread;

@end


@interface JGDownloadOperation () {
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

@property (nonatomic, assign) NSUInteger numberOfConnections; //actual number of connections, not maxmum number

@property (nonatomic, strong, readonly) NSArray *connections;

- (void)getHTTPHeadersAndProceed;
- (void)startLoadingAllConnectionsAndOpenOutput;

- (void)didReceiveHTTPHeaders:(NSHTTPURLResponse *)response error:(NSError *)_error;

@end

@implementation JGDownloadOperation

@synthesize maxConnections, url, destinationPath, contentLength, connections, tag, error, downloadProgress, started, numberOfConnections;


#pragma mark - Network Thread

+ (void)networkRequestThreadEntryPoint:(id)__unused object {
    @autoreleasepool {
        [[NSThread currentThread] setName:@"JGDownloadAccelerator"];
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

- (id)initWithURL:(NSURL *)_url destinationPath:(NSString *)_path resume:(BOOL)_resume {
    self = [super init];
    if (self) {
        destinationPath = _path;
        url = _url;
        append = _resume;
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
    
    if (reallyAppend) {
        if (splittingUnavailable) {
            [self getHTTPHeadersAndProceed];
        }
        else {
            NSString *metaPath = [self downloadMetadataPathForFilePath:destinationPath];
            resume = [[JGDownloadResumeMetadata alloc] initWithContentsAtPath:metaPath];
            [self resumeConnectionsFromResumeMetadata];
        }
    }
    else {
        if ([[NSFileManager defaultManager] fileExistsAtPath:self.destinationPath]) {
            [[NSFileManager defaultManager] removeItemAtPath:self.destinationPath error:nil];
        }
        [[NSFileManager defaultManager] createFileAtPath:self.destinationPath contents:nil attributes:nil];
        
        [self getHTTPHeadersAndProceed];
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
    contentLength = resume.totalSize;
    resumedAtSize = resume.currentSize;
    
    NSMutableArray *preConnections = [NSMutableArray array];
    
    for (JGResumeObject *object in resume) {
        if (object.range.final ? object.range.location+object.offset < self.contentLength : object.offset <= object.range.length) {
            JGDownload *download = [[JGDownload alloc] initWithURL:self.url object:object owner:self];
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
    self.numberOfConnections = (splittingUnavailable ? 1 : self.maxConnections); //is the Range header supported? If yes use max number of connections, if not use 1 connection
    
    NSString *metaPath = [self downloadMetadataPathForFilePath:destinationPath];
    resume = [[JGDownloadResumeMetadata alloc] initWithNumberOfConnections:self.numberOfConnections filePath:metaPath];
    [resume setTotalSize:self.contentLength];
    
    unsigned long splittedRest = (self.contentLength % self.numberOfConnections);
    unsigned long long evenSplitter = self.contentLength-splittedRest;
    unsigned long long singleLength = evenSplitter/self.numberOfConnections;
    
    unsigned long long currentOffset = 0;
    
    NSMutableArray *preConnections = [NSMutableArray array];
    
    for (unsigned int i = 0; i < self.numberOfConnections; i++) {
        unsigned long rangeLength = (i == 0 ? singleLength+splittedRest : singleLength);
        BOOL final = (i == self.numberOfConnections-1);
        if (final) {
            rangeLength -= i;
        }
        JGRange range = JGRangeMake(currentOffset, rangeLength, final);
        currentOffset += rangeLength+1;
        
        JGResumeObject *object = [[JGResumeObject alloc] initWithRange:range offset:0];
        [resume addObject:object];
        
        JGDownload *download = [[JGDownload alloc] initWithURL:self.url object:object owner:self];
        [preConnections addObject:download];
    }
    
    connections = preConnections;
    
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
        
        contentLength = (unsigned long long)[response expectedContentLength];
        
        NSError *__error = nil;
        unsigned long long free = getFreeSpace(self.destinationPath.stringByDeletingLastPathComponent, &__error);
        
        if (free <= contentLength) {
            error = [NSError errorWithDomain:@"de.j-gessner.jgdownloadaccelerator" code:409 userInfo:@{NSLocalizedDescriptionKey : @"There's not enough free space on the disk to download this file"}]; //409 = Conflict ?
            [self completeOperation];
            return;
        }
        
        if (resume && splittingUnavailable) {
            NSDictionary *fileAttribs = [[NSFileManager defaultManager] attributesOfItemAtPath:self.destinationPath error:nil];
            unsigned long long size = [fileAttribs fileSize];
            if (size >= self.contentLength) {
                if (size == self.contentLength) {
                    NSLog(@"Error: Cannot Resume Operation: Downloaded bytes are equal to the available bytes");
                }
                else {
                    NSLog(@"Error: Cannot Resume Operation: Downloaded bytes exceed available bytes");
                }
                [self completeOperation];
            }
            else {
                JGRange range = JGRangeMake(0, contentLength, YES);
                
                JGResumeObject *object = [[JGResumeObject alloc] initWithRange:range offset:size];
                
                JGDownload *download = [[JGDownload alloc] initWithURL:self.url object:object owner:self];
                
                self.numberOfConnections = 1;
                
                connections = @[download];
                
                [self startLoadingAllConnectionsAndOpenOutput];
            }
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
    headerProvider = [[JGHEADRequest alloc] initWithURL:self.url];
    headerProvider.delegate = self;
    [headerProvider start];
}

#pragma mark - Delegate Blocks


- (void)setOperationStartedBlock:(void (^)(NSUInteger tag, unsigned long long totalBytesExpectedToRead))block {
    self.started = block;
}

- (void)setDownloadProgressBlock:(void (^)(NSUInteger bytesRead, unsigned long long totalBytesReadThisSession, unsigned long long totalBytesWritten, unsigned long long totalBytesExpectedToRead, NSUInteger tag))block {
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
            return; //no completion call when cancelled
        }
        if (!!self.error) {
            if (failure && !!self.error) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    failure(self, self.error);
                });
            }
        } else {
            if (success) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    success(self);
                });
            }
        }
    };
#pragma clang diagnostic pop
}

#pragma mark - JGDownloadDelegate

- (void)download:(JGDownload *)download didReadData:(NSData *)data {
    JGResumeObject *object = download.object;
    
    NSUInteger realLength = data.length;
    
    unsigned long long length = (unsigned long long)realLength;
    
    resume.currentSize += length;
    
    unsigned long long offset = object.offset;
    unsigned long long finalLocation = object.range.location+offset;
    
    [output seekToFileOffset:finalLocation];
    [output writeData:data];
    
    if (self.downloadProgress) {
        self.downloadProgress(realLength, resume.currentSize-resumedAtSize, resume.currentSize, self.contentLength, self.tag);
    }
    [output synchronizeFile];
    
    offset += length;
    
    [object setOffset:offset];
    [resume write];
}


- (void)downloadDidFinish:(JGDownload *)download withError:(NSError *)_error {
    if (_error) {
        if (errorRetryAttempts >= self.numberOfConnections/2) {
            NSLog(@"Error: Cannot finish Operation: Too many errors occured, canceling");
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
    
    if (self.error || !clear || self.isCancelled) { //write when error, cancelled, or not told to remove file
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
        [self performSelector:@selector(operationFinishedCleanup) onThread:[[self class] networkRequestThread] withObject:nil waitUntilDone:YES];
    }
    
    [self willChangeValueForKey:@"isExecuting"];
    [self willChangeValueForKey:@"isFinished"];
    executing = NO;
    cancelled = YES;
    completed = YES;
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

- (NSUInteger)numberOfConnections {
    if (!numberOfConnections) {
        return defaultMaxConnections();
    }
    else {
        return numberOfConnections;
    }
}

@end
