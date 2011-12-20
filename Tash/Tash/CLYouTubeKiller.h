//
//  CLYouTubeKiller.h
//  Tash
//
//  Created by Chris Lundie on 11-12-02.
//  Copyright (c) 2011 Chris Lundie. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString * const kCLYouTubeKillerErrorDomain;
extern const NSInteger kCLYouTubeKillerNotStartedError;
extern const NSInteger kCLYouTubeKillerStatusNotOKError;
extern const NSInteger kCLYouTubeKillerNoMP4Error;

typedef void (^CLYouTubeKillerCompletionHandler)(NSURL *videoURL, NSError *error);

@interface CLYouTubeKiller : NSObject

- (void)getURLForVideoID:(NSString *)videoID completionHandler:(CLYouTubeKillerCompletionHandler)completionHandler;

- (void)stop;

@end
