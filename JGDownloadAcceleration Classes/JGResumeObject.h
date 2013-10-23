//
//  JGResumeObject.h
//  JGDownloadAcceleration Tester
//
//  Created by Jonas Gessner on 22.04.13.
//  Copyright (c) 2013 Jonas Gessner. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "JGDownloadDefines.h"

@interface JGResumeObject : NSObject

@property (nonatomic, assign) JGRange range; //Range to download
@property (nonatomic, assign) unsigned long long offset; //Current offset in the range


//New object
- (instancetype)initWithRange:(JGRange)ran offset:(unsigned long long)of;

//Read from file
- (instancetype)initWithString:(NSString *)string;

//Writing
- (NSString *)stringRepresentation;

@end