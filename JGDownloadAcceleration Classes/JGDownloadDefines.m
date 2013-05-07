//
//  JGDownloadDefines.m
//  JGDownloadAccelerator Tester
//
//  Created by Jonas Gessner on 22.04.13.
//  Copyright (c) 2013 Jonas Gessner. All rights reserved.
//

#import "JGDownloadDefines.h"


NSUInteger defaultMaxConnections() {
    return 6; //Seems to be a good number from my testing
}

JGRange JGRangeMake(unsigned long long loc, unsigned long long len, BOOL final) {
    JGRange r;
    r.location = loc;
    r.length = len;
    r.final = final;
    return r;
}

NSString *NSStringForFileFromJGRange(JGRange range) { //NSRange style
    return (range.final ? [NSString stringWithFormat:@"%llu",range.location] : [NSString stringWithFormat:@"%llu-%llu",range.location, range.length]);
}

NSString *NSStringFromJGRangeWithOffset(JGRange range, unsigned long long offset) { //HTTP Request ready string
    return (range.final ? [NSString stringWithFormat:@"bytes=%llu-", range.location+offset] : [NSString stringWithFormat:@"bytes=%llu-%llu", range.location+offset, range.location+range.length]);
}

unsigned long long getFreeSpace(NSString *folder, NSError *error) {
    unsigned long long freeSpace = 0;
    
    NSLog(@"GET");
    NSDictionary *dictionary = [[NSFileManager defaultManager] attributesOfFileSystemForPath:folder error:&error];
    NSLog(@"GOT");
    
    if (dictionary) {
        NSNumber *fileSystemFreeSizeInBytes = [dictionary objectForKey:NSFileSystemFreeSize];
        freeSpace = [fileSystemFreeSizeInBytes unsignedLongLongValue];
    }
    
    return freeSpace;
}