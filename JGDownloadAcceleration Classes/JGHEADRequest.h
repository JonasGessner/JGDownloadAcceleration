//
//  JGHEADRequest.h
//  JGDownloadAccelerator Tester
//
//  Created by Jonas Gessner on 05.05.13.
//  Copyright (c) 2013 Jonas Gessner. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "JGDownloadDefines.h"

@protocol JGHEADRequestDelegate <NSObject>

- (void)didRecieveResponse:(NSHTTPURLResponse *)response error:(NSError *)error;

@end

@interface JGHEADRequest : NSObject <NSURLConnectionDelegate, NSURLConnectionDataDelegate> {
    NSURLConnection *headerConnection;
}

@property (nonatomic, weak) id <JGHEADRequestDelegate> delegate;

- (id)initWithURL:(NSURL *)url;


- (void)start;
- (void)cancel;

@end
