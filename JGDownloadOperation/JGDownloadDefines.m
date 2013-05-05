//
//  JGDownloadDefines.m
//  JGDownloadAccelerator Tester
//
//  Created by Jonas Gessner on 22.04.13.
//  Copyright (c) 2013 Jonas Gessner. All rights reserved.
//

#import "JGDownloadDefines.h"


NSUInteger getMaxConnections() {
    return 6;
}

JGRange JGRangeMake(unsigned long long loc, unsigned long long len, BOOL final) {
    JGRange r;
    r.location = loc;
    r.length = len;
    r.final = final;
    return r;
}

NSString *NSStringForFileFromJGRange(JGRange range) {
    return (range.final ? [NSString stringWithFormat:@"%llu",range.location] : [NSString stringWithFormat:@"%llu-%llu",range.location, range.length]);
}

NSString *NSStringFromJGRangeWithOffset(JGRange range, unsigned long long offset) {
    return (range.final ? [NSString stringWithFormat:@"bytes=%llu-", range.location+offset] : [NSString stringWithFormat:@"bytes=%llu-%llu", range.location+offset, range.location+range.length]);
}

unsigned long long getFreeSpace(NSString *folder, NSError **error) {
    unsigned long long freeSpace = 0;
    
    NSDictionary *dictionary = [[NSFileManager defaultManager] attributesOfFileSystemForPath:folder error:error];
    
    if (dictionary) {
        NSNumber *fileSystemFreeSizeInBytes = [dictionary objectForKey:NSFileSystemFreeSize];
        freeSpace = [fileSystemFreeSizeInBytes unsignedLongLongValue];
    }
    
    return freeSpace;
}