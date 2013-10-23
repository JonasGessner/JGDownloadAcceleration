//
//  JGDownloadOperationPrivate.h
//  JGHLSRipper
//
//  Created by Jonas Gessner on 31.08.13.
//  Copyright (c) 2013 Jonas Gessner. All rights reserved.
//

#import "JGDownloadOperation.h"
#import "JGHEADRequest.h"
#import "JGDownloadResumeMetadata.h"

@interface JGDownloadOperation () <JGDownloadManager, JGHEADRequestDelegate> {
    BOOL _waitForContentLength;
    
    JGRange _contentRange;
    
    NSUInteger _finished;
    BOOL _append;
    NSUInteger _errorRetryAttempts;
    
    BOOL _completed;
    BOOL _executing;
    BOOL _cancelled;
    
    BOOL _splittingUnavailable;
    
    unsigned long long _resumedAtSize;
    
    BOOL _clear;
    
    JGHEADRequest *_headerProvider;
    
    NSFileHandle *_output;
    JGDownloadResumeMetadata *_resume;
    
    NSError *_error;
}

@property (nonatomic, copy) JGConnectionOperationProgressBlock downloadProgress;
@property (nonatomic, copy) JGConnectionOperationStartedBlock started;

@property (nonatomic, assign) NSUInteger numberOfConnections; //actual number of connections, not maximum number

@property (nonatomic, strong, readonly) NSArray *connections;


+ (Class)chunkDownloaderClass;


- (void)getHTTPHeadersAndProceed;
- (void)startLoadingAllConnectionsAndOpenOutput;

- (void)startSingleRequest;

- (void)didReceiveHTTPHeaders:(NSHTTPURLResponse *)response error:(NSError *)_error;


//Network Thread Handling
+ (NSThread *)networkRequestThread;
+ (BOOL)networkRequestThreadIsAvailable;
+ (void)endNetworkThread;

@end

