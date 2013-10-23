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
#import "JGDownloadOperationPrivate.h"

@implementation JGDownloadOperation

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


+ (Class)chunkDownloaderClass {
    return [JGDownload class];
}

- (instancetype)initWithURL:(NSURL *)url destinationPath:(NSString *)path allowResume:(BOOL)resume {
    self = [super init];
    if (self) {
        _destinationPath = path;
        _originalRequest = [NSURLRequest requestWithURL:url];
        _append = resume;
        
        NSParameterAssert(_originalRequest != nil);
        NSParameterAssert(_destinationPath != nil);
    }
    return self;
}

- (instancetype)initWithRequest:(NSURLRequest *)request destinationPath:(NSString *)path allowResume:(BOOL)resume {
    self = [super init];
    if (self) {
        if ([request HTTPMethod] != nil && ![request.HTTPMethod isEqualToString:@"GET"]) {
            @throw [NSException exceptionWithName:@"Invalid Request" reason:@"JGDownloadAcceleration only supports HTTP GET requests" userInfo:nil];
            return nil;
        }
        _destinationPath = path;
        _originalRequest = request;
        _append = resume;
        
        NSParameterAssert(_originalRequest != nil);
        NSParameterAssert(_destinationPath != nil);
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
    _error = nil;
    _completed = NO;
    _cancelled = NO;
    _splittingUnavailable = NO;
    _resumedAtSize = 0;
    _waitForContentLength = NO;
    
    [self willChangeValueForKey:@"isExecuting"];
    _executing = YES;
    [self didChangeValueForKey:@"isExecuting"];
    
    BOOL reallyAppend = _append;
    if (![[NSFileManager defaultManager] fileExistsAtPath:self.destinationPath]) {
        reallyAppend = NO;
    }
    else if (![[NSFileManager defaultManager] fileExistsAtPath:[self downloadMetadataPathForFilePath:self.destinationPath]]) {
        if ([[NSFileManager defaultManager] fileExistsAtPath:self.destinationPath]) {
            [[NSFileManager defaultManager] removeItemAtPath:self.destinationPath error:nil];
        }
        reallyAppend = NO;
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
            NSString *metaPath = [self downloadMetadataPathForFilePath:_destinationPath];
            _resume = [[JGDownloadResumeMetadata alloc] initWithContentsAtPath:metaPath];
            [self resumeConnectionsFromResumeMetadata];
        }
        else {
            if (originalRequestHasRange) {
                _contentRange = rangeOfOriginalRequest;
            }
            else {
                _waitForContentLength = YES; //content length is unknown. Wait for download:didReceiveResponse: to eventually set the contentRange and be aware of the content length
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
            NSString *metaPath = [self downloadMetadataPathForFilePath:_destinationPath];
            _resume = [[JGDownloadResumeMetadata alloc] initWithContentsAtPath:metaPath];
            [self resumeConnectionsFromResumeMetadata];
        }
        else {
            if ([[NSFileManager defaultManager] fileExistsAtPath:self.destinationPath]) {
                [[NSFileManager defaultManager] removeItemAtPath:self.destinationPath error:nil];
            }
            [[NSFileManager defaultManager] createFileAtPath:self.destinationPath contents:nil attributes:nil];
            
            if (originalRequestHasRange) { //don't request the HTTP headers if the range has already been set in the original request
                _contentRange = rangeOfOriginalRequest;
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
    _output = [NSFileHandle fileHandleForWritingAtPath:self.destinationPath];
    
    for (JGDownload *download in _connections) {
        [download startLoading];
    }
}

- (void)downloadStarted:(JGDownload *)download {
    if (_started) {
        _started(self.tag, self.contentLength);
        _started = nil;
    }
}

#pragma mark - Resume Connection

- (void)resumeConnectionsFromResumeMetadata {
    _contentRange = JGRangeMake(0, _resume.totalSize, NO); //The original location is not stored in the resume metadata because it is irelevant when resuming a request
    
    _resumedAtSize = _resume.currentSize;
    
    NSMutableArray *preConnections = [NSMutableArray array];
    
    for (JGResumeObject *object in _resume) {
        if (object.range.final ? object.range.location+object.offset < self.contentLength : object.offset <= object.range.length) {
            JGDownload *download = [[self.class.chunkDownloaderClass alloc] initWithRequest:self.originalRequest object:object manager:self];
            [preConnections addObject:download];
        }
    }
    
    self.numberOfConnections = preConnections.count; //ignores maximum number, as its resuming the previous state of the operation
    
    if (!self.numberOfConnections) {
        NSLog(@"Error: Cannot Resume Operation: Tried to Resume Operation but there are no connections to resume");
        [self completeOperation];
        return;
    }
    
    _connections = preConnections.copy;
    
    [self startLoadingAllConnectionsAndOpenOutput];
}

#pragma mark - New Connection

- (void)startSplittedConnections {
    self.numberOfConnections = (_splittingUnavailable ? 1 : self.maximumNumberOfConnections); //is the Range header supported? If yes use max number of connections, if not use 1 connection
    
    NSString *metaPath = [self downloadMetadataPathForFilePath:self.destinationPath];
    _resume = [[JGDownloadResumeMetadata alloc] initWithNumberOfConnections:self.numberOfConnections filePath:metaPath];
    [_resume setTotalSize:self.contentLength];
	
    unsigned long splittedRest = (self.contentLength % self.numberOfConnections);
    unsigned long long evenSplitter = self.contentLength-splittedRest;
    unsigned long long singleLength = evenSplitter/self.numberOfConnections;
    
    unsigned long long currentOffset = _contentRange.location;
    
    NSMutableArray *preConnections = [NSMutableArray array];
    
    for (unsigned int i = 0; i < self.numberOfConnections; i++) {
        unsigned long long rangeLength = (i == 0 ? singleLength+splittedRest : singleLength);
        
        JGRange range = JGRangeMake(currentOffset, rangeLength, NO);
        currentOffset += rangeLength;
        
        JGResumeObject *object = [[JGResumeObject alloc] initWithRange:range offset:0];
        [_resume addObject:object];
        
        JGDownload *download = [[self.class.chunkDownloaderClass alloc] initWithRequest:self.originalRequest object:object manager:self];
        [preConnections addObject:download];
    }
    
    _connections = preConnections;
    
    [self startLoadingAllConnectionsAndOpenOutput];
}

- (void)startSingleRequest { //When the Range header is not supported or the number of connections is 1
    self.numberOfConnections = 1;
    
    NSString *metaPath = [self downloadMetadataPathForFilePath:self.destinationPath];
    _resume = [[JGDownloadResumeMetadata alloc] initWithNumberOfConnections:self.numberOfConnections filePath:metaPath];
    
    JGRange range = JGRangeMake(_contentRange.location, self.contentLength, YES);
    
    JGResumeObject *object = [[JGResumeObject alloc] initWithRange:range offset:0];
    
    JGDownload *download = [[self.class.chunkDownloaderClass alloc] initWithRequest:self.originalRequest object:object manager:self];
    
    _connections = @[download];
    
    [self startLoadingAllConnectionsAndOpenOutput];
}

#pragma mark - HTTP Headers

- (void)didReceiveHTTPHeaders:(NSHTTPURLResponse *)response error:(NSError *)error {
    if (_error) {
        _error = error;
        [self completeOperation];
    }
    else {
        NSInteger statusCode = response.statusCode;
        
        if (statusCode >= 400) {
            _error = [NSError errorWithDomain:@"de.j-gessner.JGDownloadAcceleration" code:409 userInfo:@{NSLocalizedDescriptionKey : [NSString stringWithFormat:@"Invalid status code: %i %@", statusCode, [NSHTTPURLResponse localizedStringForStatusCode:statusCode]]}]; //409 = Conflict
            [self completeOperation];
            return;
        }
        NSDictionary *headers = [response allHeaderFields];
        
        if (!_splittingUnavailable) {
            _splittingUnavailable = ![[headers objectForKey:@"Accept-Ranges"] hasPrefix:@"bytes"];
        }
        
        unsigned long long size = (unsigned long long)[response expectedContentLength];
        
        _contentRange = JGRangeMake(0, size, NO);
        
        unsigned long long free = getFreeSpace(self.destinationPath.stringByDeletingLastPathComponent, nil);
        unsigned long long umax = ULLONG_MAX;
        
        if (free == umax) {
            _error = [NSError errorWithDomain:@"de.j-gessner.JGDownloadAcceleration" code:409 userInfo:@{NSLocalizedDescriptionKey : @"Invalid content size (content size unavailable)"}]; //409 = Conflict
            [self completeOperation];
            return;
        }
        
        if (free <= self.contentLength) {
            _error = [NSError errorWithDomain:@"de.j-gessner.JGDownloadAcceleration" code:409 userInfo:@{NSLocalizedDescriptionKey : @"There's not enough free space on the disk to download this file"}]; //409 = Conflict
            [self completeOperation];
            return;
        }
        
        if (_resume && _splittingUnavailable) {
            [self startSingleRequest];
        }
        else {
            [self startSplittedConnections];
        }
    }
}

- (void)didRecieveResponse:(NSHTTPURLResponse *)response error:(NSError *)error {
    _headerProvider = nil;
    [self didReceiveHTTPHeaders:response error:error];
}

- (void)getHTTPHeadersAndProceed {
    _headerProvider = [[JGHEADRequest alloc] initWithRequest:self.originalRequest];
    _headerProvider.delegate = self;
    [_headerProvider start];
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
        __weak __typeof(self) weakSelf = self;
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
            if (!_clear) {
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
    if (_waitForContentLength) {
        _contentRange = JGRangeMake(0, (unsigned long long)[response expectedContentLength], NO);
        [_resume setTotalSize:self.contentLength];
        _waitForContentLength = NO;
    }
}

- (void)download:(JGDownload *)download didReadData:(NSData *)data {
    JGResumeObject *object = download.object;
    
    NSUInteger realLength = data.length;
    
    unsigned long long length = (unsigned long long)realLength;
    
    _resume.currentSize += length;
    
    unsigned long long offset = object.offset;
    
    unsigned long long finalLocation = object.range.location+offset;
    
    [_output seekToFileOffset:finalLocation];
    [_output writeData:data];
    
    if (self.downloadProgress && !_completed) {
        self.downloadProgress(realLength, _resume.currentSize-_resumedAtSize, _resume.currentSize, self.contentLength, self.tag);
    }
    
    [_output synchronizeFile];
    
    offset += length;
    
    [object setOffset:offset];
    if (_append) {
        [_resume write];
    }
    
    //NSLog(@"DOWNLOAD %i OFFSET %llu PREVIOUS %llu", [_connections indexOfObject:download], offset, offset-data.length);
}

- (NSUInteger)retryCount {
    NSUInteger retry = _retryCount;
    if (!retry) {
        retry = (NSUInteger)self.numberOfConnections/2;
    }
    return retry;
}

- (void)downloadDidFinish:(JGDownload *)download withError:(NSError *)error {
    if (error) {
        if (_errorRetryAttempts > _retryCount) {
            //            NSLog(@"Error: Cannot finish Operation: Too many errors occured, canceling");
            _error = error;
            [self completeOperation];
        }
        else {
            [download retry];
            _errorRetryAttempts++;
        }
    }
    else {
        NSMutableArray *cons = [_connections mutableCopy];
        [cons removeObjectIdenticalTo:download];
        _connections = cons.copy;
        if (!_connections.count) {
            _connections = nil;
            [self completeOperation];
        }
    }
}

#pragma mark - Completion

- (void)operationFinishedCleanup {
    [_headerProvider cancel];
    _headerProvider = nil;
    
    for (JGDownload *download in self.connections) {
        [download cancel];
    }
    
    _connections = nil;
    
    [_output closeFile];
    
    _output = nil;
    
    if ((self.error || !_clear || (self.isCancelled && !_clear)) && _append) { //write when error, cancelled, or not told to remove file
        [_resume write];
    }
    else {
        [_resume removeFile];
    }
    
    _resume = nil;
}

- (void)cancelAndClearFiles { //probably called from main thread
    _clear = YES; //will clear
    
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
    _executing = NO;
    _completed = YES;
    _cancelled = YES;
    [super cancel];
    [self didChangeValueForKey:@"isFinished"];
    [self didChangeValueForKey:@"isExecuting"];
}

- (void)completeOperation {
    if (!self.isExecuting) {
        NSLog(@"Error: Cannot Complete Operation: Operation is not executing");
        return;
    }
    
    _clear = YES;
    
    [self operationFinishedCleanup];
    
    [self willChangeValueForKey:@"isExecuting"];
    [self willChangeValueForKey:@"isFinished"];
    _completed = YES;
    _executing = NO;
    [self didChangeValueForKey:@"isFinished"];
    [self didChangeValueForKey:@"isExecuting"];
}

#pragma mark - States

- (BOOL)isConcurrent {
    return YES;
}

- (BOOL)isExecuting {
    return _executing;
}

- (BOOL)isFinished {
    return _completed;
}

#pragma mark - Custom Property Getters & Setters

- (unsigned long long)contentLength {
    return _contentRange.length;
}

- (NSUInteger)actualNumberOfConnections {
    return self.numberOfConnections;
}

- (NSUInteger)numberOfConnections {
    if (!_numberOfConnections) {
        return defaultMaxConnections();
    }
    else {
        return _numberOfConnections;
    }
}

@end
