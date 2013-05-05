//
//  JGDownloadOperation.h
//  JGDownloadAccelerator Tester
//
//  Created by Jonas Gessner on 21.04.13.
//  Copyright (c) 2013 Jonas Gessner. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "JGDownloadDefines.h"
#import "JGHEADRequest.h"
#import "JGDownloadResumeMetadata.h"

@interface JGDownloadOperation : NSOperation <JGDownloadManager, NSURLConnectionDataDelegate, JGHEADRequestDelegate>


@property (nonatomic, assign) NSUInteger maxConnections;
@property (nonatomic, assign) NSUInteger tag;

@property (nonatomic, strong) NSError *error;

@property (nonatomic, readonly, strong) NSString *destinationPath;

@property (nonatomic, assign, readonly) unsigned long long contentLength;
@property (nonatomic, strong, readonly) NSURL *url;

- (void)cancelAndClearFiles;

- (id)initWithURL:(NSURL *)url destinationPath:(NSString *)path resume:(BOOL)resume;

- (void)setCompletionBlockWithSuccess:(void (^)(JGDownloadOperation *operation))success failure:(void (^)(JGDownloadOperation *operation, NSError *error))failure;
- (void)setDownloadProgressBlock:(void (^)(NSUInteger bytesRead, unsigned long long totalBytesReadThisSession, unsigned long long totalBytesWritten, unsigned long long totalBytesExpectedToRead, NSUInteger tag))block;
- (void)setOperationStartedBlock:(void (^)(NSUInteger tag, unsigned long long totalBytesExpectedToRead))block;

//Network Thread Handling
+ (NSThread *)networkRequestThread;
+ (BOOL)networkRequestThreadIsAvailable;
+ (void)endNetworkThread;

@end
