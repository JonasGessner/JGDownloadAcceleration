//
//  JGDownloadResumeMetadata.h
//  JGDownloadAccelerator Tester
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

- (id)initWithNumberOfConnections:(NSUInteger)number filePath:(NSString *)path;
- (id)initWithContentsAtPath:(NSString *)path;

- (void)addObject:(JGResumeObject *)object;

- (BOOL)write;
- (void)removeFile;

@end
