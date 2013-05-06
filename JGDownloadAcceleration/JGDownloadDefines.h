//
//  JGDownloadDefines.h
//  JGDownloadAccelerator Tester
//
//  Created by Jonas Gessner on 22.04.13.
//  Copyright (c) 2013 Jonas Gessner. All rights reserved.
//

#import <Foundation/Foundation.h>

#if !__has_feature(objc_arc)
#error "JGDownloadOperation requires ARC!"
#endif

#if defined(__cplusplus)
#define JGExtern extern "C"
#else
#define JGExtern extern
#endif

#define OBJECT_BREAK @"#"
#define DOWNLOAD_BREAK @"*"

#define USER_AGENT @"Mozilla/5.0 (Windows NT 6.1; WOW64) AppleWebKit/535.7 (KHTML, like Gecko) Chrome/16.0.912.75 Safari/535.7"

typedef void (^JGConnectionOperationProgressBlock)(NSUInteger bytesRead, unsigned long long totalBytesReadThisSession, unsigned long long totalBytesWritten, unsigned long long totalBytesExpectedToRead, NSUInteger tag);
typedef void (^JGConnectionOperationStartedBlock)(NSUInteger tag, unsigned long long totalBytesExpectedToRead);

typedef struct {
    unsigned long long location;
    unsigned long long length;
    BOOL final;
} JGRange;


JGExtern NSUInteger defaultMaxConnections();

JGExtern JGRange JGRangeMake(unsigned long long loc, unsigned long long len, BOOL final);

JGExtern NSString *NSStringForFileFromJGRange(JGRange range);

JGExtern NSString *NSStringFromJGRangeWithOffset(JGRange range, unsigned long long offset);

JGExtern unsigned long long getFreeSpace(NSString *folder, NSError **error);



@class JGDownload, JGResumeObject;

@protocol JGDownloadManager <NSObject>

- (void)download:(JGDownload *)download didReadData:(NSData *)data;
- (void)downloadDidFinish:(JGDownload *)download withError:(NSError *)error;

- (void)downloadStarted:(JGDownload *)download;

@end
