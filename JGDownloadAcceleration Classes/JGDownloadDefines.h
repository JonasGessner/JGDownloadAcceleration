//
//  JGDownloadDefines.h
//  JGDownloadAcceleration Tester
//
//  Created by Jonas Gessner on 22.04.13.
//  Copyright (c) 2013 Jonas Gessner. All rights reserved.
//

#import <Foundation/Foundation.h>

#define OBJECT_BREAK @"#"
#define DOWNLOAD_BREAK @"\n"
#define DOWNLOAD_BREAK_OLD @"*"

typedef void (^JGConnectionOperationProgressBlock)(NSUInteger bytesRead, unsigned long long totalBytesReadThisSession, unsigned long long totalBytesRead, unsigned long long totalBytesExpectedToRead, NSUInteger tag);
typedef void (^JGConnectionOperationStartedBlock)(NSUInteger tag, unsigned long long totalBytesExpectedToRead);

typedef struct {
    unsigned long long location;
    unsigned long long length;
    BOOL final;
} JGRange;


NS_INLINE NSUInteger defaultMaxConnections() {
    return 6; //Seems to be a good number to maximise speeds while not having too many connections
}

NS_INLINE JGRange JGRangeMake(unsigned long long loc, unsigned long long len, BOOL final) { //Used like NSRange
    JGRange r;
    r.location = loc;
    r.length = len;
    r.final = final;
    return r;
}

NS_INLINE NSString *NSStringForFileFromJGRange(JGRange range) {
    return (range.final ? [NSString stringWithFormat:@"%llu",range.location] : [NSString stringWithFormat:@"%llu-%llu",range.location, range.length]);
}

NS_INLINE NSString *NSStringFromJGRangeWithOffset(JGRange range, unsigned long long offset) { //HTTP Request ready string
    return (range.final ? [NSString stringWithFormat:@"bytes=%llu-", range.location+offset] : [NSString stringWithFormat:@"bytes=%llu-%llu", range.location+offset, range.location+range.length]);
}

NS_INLINE unsigned long long getFreeSpace(NSString *folder, NSError *error) {
    unsigned long long freeSpace = 0;
    //Error is not used
    NSDictionary *dictionary = [[NSFileManager defaultManager] attributesOfFileSystemForPath:folder error:nil];
    
    if (dictionary) {
        NSNumber *fileSystemFreeSizeInBytes = [dictionary objectForKey:NSFileSystemFreeSize];
        freeSpace = [fileSystemFreeSizeInBytes unsignedLongLongValue];
    }
    
    return freeSpace;
}



@class JGDownload, JGResumeObject;

@protocol JGDownloadManager <NSObject>

- (void)download:(JGDownload *)download didReceiveResponse:(NSHTTPURLResponse *)response;

- (void)download:(JGDownload *)download didReadData:(NSData *)data;
- (void)downloadDidFinish:(JGDownload *)download withError:(NSError *)error;

- (void)downloadStarted:(JGDownload *)download;

@end
