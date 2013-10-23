//
//  JGDownloadResumeMetadata.m
//  JGDownloadAcceleration Tester
//
//  Created by Jonas Gessner on 22.04.13.
//  Copyright (c) 2013 Jonas Gessner. All rights reserved.
//

#import "JGDownloadResumeMetadata.h"

@interface JGDownloadResumeMetadata () {
    NSMutableArray *infos;
    NSString *path;
}

@end

@implementation JGDownloadResumeMetadata

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state objects:(id __unsafe_unretained [])buffer count:(NSUInteger)len {
    return [infos countByEnumeratingWithState:state objects:buffer count:len];
}

//Reading:

- (void)read {
    NSString *serialized = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
    if (!serialized.length) {
        return;
    }
    NSArray *downloads = ([serialized hasSuffix:@"v2.0"] ? [serialized componentsSeparatedByString:DOWNLOAD_BREAK] : [serialized componentsSeparatedByString:DOWNLOAD_BREAK_OLD]);
    
    infos = [NSMutableArray array];
    
    self.totalSize = (unsigned long long)[[downloads lastObject] longLongValue];
    NSUInteger index = downloads.count-2;
    if (index == NSNotFound) {
        return;
    }
    if (index) {
        self.currentSize = (unsigned long long)[[downloads objectAtIndex:downloads.count-2] longLongValue];
    }
    
    for (int i = 0; i < index; i++) {
        NSString *component = [downloads objectAtIndex:i];
        JGResumeObject *object = [[JGResumeObject alloc] initWithString:component];
        [infos addObject:object];
    }
}

- (instancetype)initWithContentsAtPath:(NSString *)daPath {
    self = [super init];
    if (self) {
        path = daPath;
        [self read];
    }
    return self;
}


//Writing

- (instancetype)initWithNumberOfConnections:(NSUInteger)number filePath:(NSString *)daPath {
    self = [super init];
    if (self) {
        infos = [NSMutableArray arrayWithCapacity:number];
        path = daPath;
    }
    return self;
}

- (void)addObject:(JGResumeObject *)object {
    [infos addObject:object];
}

- (NSString *)stringRepresentation {
    NSMutableString *string = [NSMutableString string];
    for (JGResumeObject *object in infos.copy) {
        if (string.length) {
            [string appendString:DOWNLOAD_BREAK];
        }
        NSString *final = [object stringRepresentation];
        [string appendString:final];
    }
    [string appendFormat:@"%@%llu%@%lluv2.0", DOWNLOAD_BREAK, self.currentSize, DOWNLOAD_BREAK, self.totalSize];
    return string.copy;
}

- (BOOL)write {
    NSString *string = [self stringRepresentation];
    dispatch_async(dispatch_get_main_queue(), ^{
        [string writeToFile:path atomically:NO encoding:NSUTF8StringEncoding error:nil];
    });
    return YES;
}

- (void)removeFile {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
    });
}


@end
