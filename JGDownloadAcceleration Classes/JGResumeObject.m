//
//  JGResumeObject.m
//  JGDownloadAcceleration Tester
//
//  Created by Jonas Gessner on 22.04.13.
//  Copyright (c) 2013 Jonas Gessner. All rights reserved.
//

#import "JGResumeObject.h"

@implementation JGResumeObject

- (instancetype)initWithRange:(JGRange)ran offset:(unsigned long long)of {
    self = [super init];
    if (self) {
        self.range = ran;
        self.offset = of;
    }
    return self;
}

- (instancetype)initWithString:(NSString *)string {
    self = [super init];
    if (self) {
        NSArray *components = [string componentsSeparatedByString:OBJECT_BREAK];
        if (components.count) {
            NSString *range = [components objectAtIndex:0];
            NSArray *comps = [range componentsSeparatedByString:@"-"];
            if (comps.count == 2) {
                unsigned long long location = (unsigned long long)[[comps objectAtIndex:0] longLongValue];
                unsigned long long length = (unsigned long long)[[comps objectAtIndex:1] longLongValue];
                self.range = JGRangeMake(location, length, NO);
            }
            else if (comps.count == 1) {
                unsigned long long location = (unsigned long long)[[comps objectAtIndex:0] longLongValue];
                self.range = JGRangeMake(location, 0, YES);
            }
            
            NSString *offset = nil;
            if (components.count > 1) {
                offset = [components objectAtIndex:1];
            }
            self.offset = (unsigned long long)offset.longLongValue;
            
        }
    }
    return self;
}

- (NSString *)stringRepresentation {
    return [NSString stringWithFormat:@"%@%@%llu", NSStringForFileFromJGRange(self.range), OBJECT_BREAK, self.offset];
}


@end
