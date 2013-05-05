//
//  JGResumeObject.h
//  JGDownloadAccelerator Tester
//
//  Created by Jonas Gessner on 22.04.13.
//  Copyright (c) 2013 Jonas Gessner. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "JGDownloadDefines.h"

@interface JGResumeObject : NSObject

@property (nonatomic, assign) JGRange range;
@property (nonatomic, assign) unsigned long long offset;

- (id)initWithRange:(JGRange)ran offset:(unsigned long long)of;
- (id)initWithString:(NSString *)string;

- (NSString *)stringRepresentation;

@end

//NS_INLINE NSString *NSStringFromResumeObject(JGResumeObject *resume) {
//    return NSStringFromJGRangeWithOffset(resume.range, resume.offset);
//}
