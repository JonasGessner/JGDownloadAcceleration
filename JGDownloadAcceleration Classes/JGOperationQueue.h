//
//  JGOperationQueue.h
//  JGDownloadAcceleration Tester
//
//  Created by Jonas Gessner on 25.04.13.
//  Copyright (c) 2013 Jonas Gessner. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "JGDownloadOperation.h"

@interface JGOperationQueue : NSOperationQueue

@property (nonatomic, assign) BOOL handleNetworkActivityIndicator;
@property (nonatomic, assign) BOOL handleBackgroundTask;

- (void)addOperation:(JGDownloadOperation *)op;

@end
