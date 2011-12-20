//
//  CLYouTubeKiller.m
//  Tash
//
//  Created by Chris Lundie on 11-12-02.
//  Copyright (c) 2011 Chris Lundie. All rights reserved.
//

#import "CLYouTubeKiller.h"
#import "GTMHTTPFetcher.h"
#import "GTMNSString+URLArguments.h"
#import "GTMNSDictionary+URLArguments.h"


NSString * const kCLYouTubeKillerErrorDomain = @"kCLYouTubeKillerErrorDomain";
const NSInteger kCLYouTubeKillerNotStartedError = 1;
const NSInteger kCLYouTubeKillerStatusNotOKError = 2;
const NSInteger kCLYouTubeKillerNoMP4Error = 3;


@interface CLYouTubeKiller () {
@private
	GTMHTTPFetcher *_fetcher;
}

@end


@implementation CLYouTubeKiller

- (void)getURLForVideoID:(NSString *)videoID completionHandler:(CLYouTubeKillerCompletionHandler)completionHandler {
	[self stop];
	NSString *infoURLStr = [NSString stringWithFormat:@"https://www.youtube.com/get_video_info?video_id=%@&eurl=http%3A%2F%2Fwww%2Eyoutube%2Ecom%2F", [videoID gtm_stringByEscapingForURLArgument]];
	_fetcher = [GTMHTTPFetcher fetcherWithURLString:infoURLStr];
	BOOL started = [_fetcher beginFetchWithCompletionHandler:^(NSData *data, NSError *error) {
		if (error != nil) {
			completionHandler(nil, error);
		} else {
			NSString *videoInfoString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
			NSDictionary *videoInfo = [NSDictionary gtm_dictionaryWithHttpArgumentsString:videoInfoString];
			NSString *status = [videoInfo objectForKey:@"status"];
			if (![status isEqualToString:@"ok"]) {
				NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
				NSString *reason = [videoInfo objectForKey:@"reason"];
				if (reason != nil) {
					[userInfo setObject:reason forKey:NSLocalizedDescriptionKey];
				}
				completionHandler(nil, [NSError errorWithDomain:kCLYouTubeKillerErrorDomain code:kCLYouTubeKillerStatusNotOKError userInfo:userInfo]);
				return;
			}
			NSArray *encodedStreams = [[videoInfo objectForKey:@"url_encoded_fmt_stream_map"] componentsSeparatedByString:@","];
			NSMutableArray *streams = [NSMutableArray arrayWithCapacity:[encodedStreams count]];
			[encodedStreams enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
				NSString *encodedStream = obj;
				[streams addObject:[NSDictionary gtm_dictionaryWithHttpArgumentsString:encodedStream]];
			}];
			__block NSURL *videoURL = nil;
			[streams enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
				NSDictionary *stream = obj;
				NSString *itag = [stream objectForKey:@"itag"];
				NSString *urlStr = [stream objectForKey:@"url"];
				if (![urlStr length]) {
					return;
				}
				if ([itag isEqualToString:@"18"]) {
					videoURL = [[NSURL alloc] initWithString:urlStr];
					*stop = YES;
				}
			}];
			if (videoURL != nil) {
				completionHandler(videoURL, nil);
			} else {
				completionHandler(nil, [NSError errorWithDomain:kCLYouTubeKillerErrorDomain code:kCLYouTubeKillerNoMP4Error userInfo:nil]);
			}
		}
	}];
	if (!started) {
		completionHandler(nil, [NSError errorWithDomain:kCLYouTubeKillerErrorDomain code:kCLYouTubeKillerNotStartedError userInfo:nil]);
	}
}

- (void)stop {
	[_fetcher stopFetching];
	_fetcher = nil;
}

@end
