//
//  JGDownloadOperation.h
//  JGDownloadAcceleration Tester
//
//  Created by Jonas Gessner on 21.04.13.
//  Copyright (c) 2013 Jonas Gessner. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface JGDownloadOperation : NSOperation

//optional settings
@property (nonatomic, assign) NSUInteger tag; //default 0
@property (nonatomic, assign) NSUInteger maximumNumberOfConnections; //default 6
@property (nonatomic, assign) NSUInteger retryCount; //default maximumNumberOfConnections/2

//readonly
@property (nonatomic, strong, readonly) NSURLRequest *originalRequest;
@property (nonatomic, strong, readonly) NSString *destinationPath;

@property (nonatomic, assign, readonly) NSUInteger actualNumberOfConnections;

@property (nonatomic, strong, readonly) NSError *error;


- (unsigned long long)contentLength;


//custom init methods
- (instancetype)initWithURL:(NSURL *)url destinationPath:(NSString *)path allowResume:(BOOL)resume;
- (instancetype)initWithRequest:(NSURLRequest *)request destinationPath:(NSString *)path allowResume:(BOOL)resume;



- (void)cancelAndClearFiles; //cancel the operation and remove the partial file as well as the metadata file


//Delegate blocks
- (void)setCompletionBlockWithSuccess:(void (^)(JGDownloadOperation *operation))success failure:(void (^)(JGDownloadOperation *operation, NSError *error))failure;
- (void)setDownloadProgressBlock:(void (^)(NSUInteger bytesRead, unsigned long long totalBytesReadThisSession, unsigned long long totalBytesRead, unsigned long long totalBytesExpectedToRead, NSUInteger tag))block;
- (void)setOperationStartedBlock:(void (^)(NSUInteger tag, unsigned long long totalBytesExpectedToRead))block;

@end
