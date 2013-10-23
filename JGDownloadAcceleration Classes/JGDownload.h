//
//  JGDownload.h
//  JGDownloadAcceleration Tester
//
//  Created by Jonas Gessner on 21.04.13.
//  Copyright (c) 2013 Jonas Gessner. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "JGDownloadDefines.h"
#import "JGResumeObject.h"

@interface JGDownload : NSObject

@property (nonatomic, readonly, weak) id <JGDownloadManager> downloadManager; //"Owner" does its own thing, therefore weak reference
@property (nonatomic, readonly, weak) JGResumeObject *object; //owned by the operation's JGDownloadResumeMetadata, therefore weak reference
@property (nonatomic, readonly, weak) NSURLRequest *request; //owned by the operation, therefore weak reference

- (BOOL)startLoading;
- (void)retry;
- (void)cancel;

- (instancetype)initWithRequest:(NSURLRequest *)request object:(JGResumeObject *)object manager:(id <JGDownloadManager>)manager;

@end
