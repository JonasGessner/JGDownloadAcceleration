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

@interface JGDownloadOperation : NSOperation <JGDownloadManager, JGHEADRequestDelegate>

//required to be set
@property (nonatomic, readonly, strong) NSString *destinationPath;
@property (nonatomic, assign) NSUInteger maxConnections;

//optional
@property (nonatomic, assign) NSUInteger tag;


//readonly
@property (nonatomic, assign, readonly) unsigned long long contentLength;
@property (nonatomic, strong, readonly) NSError *error;
@property (nonatomic, strong, readonly) NSURL *url;



- (id)initWithURL:(NSURL *)url destinationPath:(NSString *)path resume:(BOOL)resume;


- (void)cancelAndClearFiles; //cancel the operation and remove the partial file as well as the metadata file


//Delegate blocks
- (void)setCompletionBlockWithSuccess:(void (^)(JGDownloadOperation *operation))success failure:(void (^)(JGDownloadOperation *operation, NSError *error))failure;
- (void)setDownloadProgressBlock:(void (^)(NSUInteger bytesRead, unsigned long long totalBytesReadThisSession, unsigned long long totalBytesWritten, unsigned long long totalBytesExpectedToRead, NSUInteger tag))block;
- (void)setOperationStartedBlock:(void (^)(NSUInteger tag, unsigned long long totalBytesExpectedToRead))block;

@end
