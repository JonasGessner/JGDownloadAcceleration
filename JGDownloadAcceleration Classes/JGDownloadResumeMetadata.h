//
//  JGDownloadResumeMetadata.h
//  JGDownloadAcceleration Tester
//
//  Created by Jonas Gessner on 22.04.13.
//  Copyright (c) 2013 Jonas Gessner. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "JGDownloadDefines.h"
#import "JGResumeObject.h"

@interface JGDownloadResumeMetadata : NSObject <NSFastEnumeration>

@property (nonatomic, assign) unsigned long long totalSize;
@property (nonatomic, assign) unsigned long long currentSize;

- (instancetype)initWithNumberOfConnections:(NSUInteger)number filePath:(NSString *)path;
- (instancetype)initWithContentsAtPath:(NSString *)path;

- (void)addObject:(JGResumeObject *)object;

- (BOOL)write;
- (void)removeFile;

@end
