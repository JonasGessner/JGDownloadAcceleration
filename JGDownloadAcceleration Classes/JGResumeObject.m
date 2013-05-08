//
//  JGResumeObject.m
//  JGDownloadAcceleration Tester
//
//  Created by Jonas Gessner on 22.04.13.
//  Copyright (c) 2013 Jonas Gessner. All rights reserved.
//

#import "JGResumeObject.h"

@implementation JGResumeObject

@synthesize range, offset;

- (id)initWithRange:(JGRange)ran offset:(unsigned long long)of {
    self = [super init];
    if (self) {
        self.range = ran;
        self.offset = of;
    }
    return self;
}

- (id)initWithString:(NSString *)string {
    self = [super init];
    if (self) {
        NSArray *components = [string componentsSeparatedByString:OBJECT_BREAK];
        if (components.count) {
            NSString *_range = [components objectAtIndex:0];
            NSArray *comps = [_range componentsSeparatedByString:@"-"];
            if (comps.count == 2) {
                unsigned long long location = (unsigned long long)[[comps objectAtIndex:0] longLongValue];
                unsigned long long length = (unsigned long long)[[comps objectAtIndex:1] longLongValue];
                self.range = JGRangeMake(location , length, NO);
            }
            else if (comps.count == 1) {
                unsigned long long location = (unsigned long long)[[comps objectAtIndex:0] longLongValue];
                self.range = JGRangeMake(location , 0, YES);
            }
            
            NSString *_offset;
            if (components.count > 1) {
                _offset = [components objectAtIndex:1];
            }
            self.offset = (unsigned long long)_offset.longLongValue;
            
        }
    }
    return self;
}

- (NSString *)stringRepresentation {
    NSString *rangeText = NSStringForFileFromJGRange(range);
    NSString *current = [NSString stringWithFormat:@"%llu", offset];
    NSString *final = [NSString stringWithFormat:@"%@%@%@", rangeText, OBJECT_BREAK, current];
    return final;
}


@end
