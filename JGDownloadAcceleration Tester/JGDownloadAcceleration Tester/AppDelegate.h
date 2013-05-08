//
//  AppDelegate.h
//  JGDownloadAcceleration Tester
//
//  Created by Jonas Gessner on 20.04.13.
//  Copyright (c) 2013 Jonas Gessner. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "LBYouTubeExtractor.h"
#import "JGOperationQueue.h"

@class ViewController;

#import "JGDownloadOperation.h"

@interface AppDelegate : UIResponder <UIApplicationDelegate, LBYouTubeExtractorDelegate, UIActionSheetDelegate> {
    JGOperationQueue *q;
}

@property (strong, nonatomic) UIWindow *window;

@property (strong, nonatomic) ViewController *viewController;

@end
