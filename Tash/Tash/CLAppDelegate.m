//
//  CLAppDelegate.m
//  Tash
//
//  Created by Chris Lundie on 11-12-01.
//  Copyright (c) 2011 Chris Lundie. All rights reserved.
//


#import "CLAppDelegate.h"
#import "CLYouTubeKiller.h"
#import "GTMNSDictionary+URLArguments.h"
#import <QTKit/QTKit.h>
#import <QuartzCore/QuartzCore.h>
#import <math.h>


@interface CLAppDelegate () <NSWindowDelegate> {
@private
	QTMovie *_movie;
	CIDetector *_faceDetector;
	CGImageRef _tashImage;
	CLYouTubeKiller *_killer;
	CGContextRef _cgContext;
	CIContext *_ciContext;
	CGColorSpaceRef _cgColorSpace;
}

- (CIDetector *)faceDetector;
- (CGImageRef)tashImage;
- (void)startMovie;
- (CGContextRef)cgContextWithSize:(CGSize)size;
- (CIContext *)ciContextWithSize:(CGSize)size;

@end


@implementation CLAppDelegate

@synthesize window = _window;
@synthesize movieView = _movieView;
@synthesize urlTextField = _urlTextField;
@synthesize progressIndicator = _progressIndicator;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	_killer = [[CLYouTubeKiller alloc] init];
}

- (CGColorSpaceRef)cgColorSpace {
	if (_cgColorSpace == NULL) {
		_cgColorSpace = CGColorSpaceCreateWithName(kCGColorSpaceGenericRGB);
	}
	return _cgColorSpace;
}

- (CIContext *)ciContextWithSize:(CGSize)size {
	if (_ciContext != nil) {
		size_t width = CGBitmapContextGetWidth(_cgContext);
		size_t height = CGBitmapContextGetHeight(_cgContext);
		if ((width != (size_t)size.width) || (height != (size_t)size.height)) {
			_ciContext = nil;
		}
	}
	if (_ciContext == nil) {
		_ciContext = [CIContext contextWithCGContext:[self cgContextWithSize:size] options:[NSDictionary dictionary]];
	}
	return _ciContext;
}

- (CGContextRef)cgContextWithSize:(CGSize)size {
	if (_cgContext != NULL) {
		size_t width = CGBitmapContextGetWidth(_cgContext);
		size_t height = CGBitmapContextGetHeight(_cgContext);
		if ((width != (size_t)size.width) || (height != (size_t)size.height)) {
			CGContextRelease(_cgContext);
			_cgContext = NULL;
		}
	}
	if (_cgContext == NULL) {
		_cgContext = CGBitmapContextCreate(NULL, size.width, size.height, 8, size.width * (CGFloat)4.0, [self cgColorSpace], kCGImageAlphaPremultipliedFirst);
	}
	return _cgContext;
}

- (CIDetector *)faceDetector {
	if (_faceDetector == nil) {
		_faceDetector = [CIDetector detectorOfType:CIDetectorTypeFace context:NULL options:[NSDictionary dictionaryWithObjectsAndKeys:CIDetectorAccuracyLow, CIDetectorAccuracy, nil]];
	}
	return _faceDetector;
}

- (CGImageRef)tashImage {
	if (_tashImage == NULL) {
		NSURL *imageURL = [[NSBundle mainBundle] URLForImageResource:@"mustache_03.png"];
		CGDataProviderRef provider = CGDataProviderCreateWithURL((__bridge CFURLRef)imageURL);
		_tashImage = CGImageCreateWithPNGDataProvider(provider, NULL, false, kCGRenderingIntentDefault);
		CGDataProviderRelease(provider);
	}
	return _tashImage;
}

- (IBAction)urlTextFieldAction:(id)sender {
	if ([[_urlTextField stringValue] length]) {
		[self startMovie];
	}
}

- (IBAction)urlButtonAction:(id)sender {
	[self startMovie];
}

- (void)startMovie {
	_movie = nil;
	__block QTMovieView *movieView = self.movieView;
	[movieView setDelegate:nil];
	[movieView pause:self];
	[movieView setMovie:nil];
	NSDictionary *queryDict = [NSDictionary gtm_dictionaryWithHttpArgumentsString:[[[NSURL alloc] initWithString:[_urlTextField stringValue]] query]];
	NSString *videoID = [queryDict objectForKey:@"v"];
	if (![videoID length]) {
		NSAlert *alert = [NSAlert alertWithMessageText:@"No video ID" defaultButton:nil alternateButton:nil otherButton:nil informativeTextWithFormat:@"Enter a YouTube video URL"];
		[alert beginSheetModalForWindow:self.window modalDelegate:nil didEndSelector:NULL contextInfo:NULL];
		return;
	}
	[_killer stop];
	[self.progressIndicator startAnimation:self];
	[_killer getURLForVideoID:videoID completionHandler:^(NSURL *movieURL, NSError *error) {
		[self.progressIndicator stopAnimation:self];
		if (error != nil) {
			NSAlert *alert = [NSAlert alertWithError:error];
			[alert beginSheetModalForWindow:self.window modalDelegate:nil didEndSelector:NULL contextInfo:NULL];
			return;
		}
		if (movieURL == nil) {
			return;
		}
		movieView = self.movieView;
		[movieView pause:self];
		_movie = [[QTMovie alloc] initWithAttributes:[NSDictionary dictionaryWithObjectsAndKeys:movieURL, QTMovieURLAttribute, [NSNumber numberWithBool:YES], QTMovieOpenForPlaybackAttribute, nil] error:NULL];
		[movieView setDelegate:self];
		[movieView setMovie:_movie];
	}];
}

- (CIImage *)view:(QTMovieView *)view willDisplayImage:(CIImage *)image {
	if (view != self.movieView) {
		return nil;
	}
	CIDetector *faceDetector = [self faceDetector];
	if (image == nil) {
		return nil;
	}
	CGRect imageExtent = image.extent;
	if ((imageExtent.size.width < 1) || (imageExtent.size.height < 1)) {
		return nil;
	}
	CIContext *ciContext = [self ciContextWithSize:imageExtent.size];
	void *cgContextData = CGBitmapContextGetData(_cgContext);
	size_t cgContextHeight = CGBitmapContextGetHeight(_cgContext);
	size_t cgContextBytesPerRow = CGBitmapContextGetBytesPerRow(_cgContext);
	[ciContext render:image toBitmap:cgContextData rowBytes:cgContextBytesPerRow bounds:imageExtent format:kCIFormatARGB8 colorSpace:[self cgColorSpace]];
	NSArray *features = [faceDetector featuresInImage:image];
	NSMutableArray *faceFeatures = [NSMutableArray arrayWithCapacity:[features count]];
	for (CIFeature *feature in features) {
		if ([feature.type isEqualToString:CIFeatureTypeFace]) {
			CIFaceFeature *face = (CIFaceFeature *)feature;
			if (face.hasMouthPosition && face.hasLeftEyePosition && face.hasRightEyePosition) {
				[faceFeatures addObject:feature];
			}
		}
	}
	CGImageRef tashImage = [self tashImage];
	CGContextSaveGState(_cgContext);
	CGContextSetInterpolationQuality(_cgContext, kCGInterpolationHigh);
	for (CIFaceFeature *face in faceFeatures) {
		CGPoint leftEyePosition = face.leftEyePosition;
		CGPoint rightEyePosition = face.rightEyePosition;
		CGFloat o = rightEyePosition.y - leftEyePosition.y;
		CGFloat a = rightEyePosition.x - leftEyePosition.x;
		if (a < (CGFloat)0.01) {
			a = (CGFloat)0.01;
		}
		float angle = atanf(o/a);
		CGPoint eyeMidpoint = CGPointMake((leftEyePosition.x + rightEyePosition.x) / 2.0, (leftEyePosition.y + rightEyePosition.y) / 2.0);
		CGPoint mouthPosition = face.mouthPosition;
		CGFloat eyeToMouthDistance = fabs(eyeMidpoint.y - mouthPosition.y);
		mouthPosition.y = (mouthPosition.y + eyeToMouthDistance / 6.0);
		CGFloat imageWidth = sqrt(pow(leftEyePosition.x - rightEyePosition.x, 2.0) + pow(leftEyePosition.y - rightEyePosition.y, 2.0)) * 2.0;
		CGFloat imageHeight = imageWidth / 4.0;
		NSRect tashRect = NSMakeRect(mouthPosition.x - imageWidth / 2, mouthPosition.y - imageHeight / 2, imageWidth, imageHeight);
		CGContextSaveGState(_cgContext);
		CGContextTranslateCTM(_cgContext, tashRect.origin.x + tashRect.size.width / (CGFloat)2, tashRect.origin.y + tashRect.size.height / (CGFloat)2);
		CGContextRotateCTM(_cgContext, angle);
		CGContextDrawImage(_cgContext, CGRectMake(-tashRect.size.width / (CGFloat)2, -tashRect.size.height / (CGFloat)2, tashRect.size.width, tashRect.size.height), tashImage);
		CGContextRestoreGState(_cgContext);
	}
	CGContextRestoreGState(_cgContext);
	CIImage *outputImage = [[CIImage alloc] initWithBitmapData:[NSData dataWithBytesNoCopy:cgContextData length:cgContextHeight * cgContextBytesPerRow freeWhenDone:NO] bytesPerRow:cgContextBytesPerRow size:imageExtent.size format:kCIFormatARGB8 colorSpace:[self cgColorSpace]];
	return outputImage;
}

- (void)windowWillClose:(NSNotification *)notification {
	[[NSApplication sharedApplication] terminate:self];
}

@end
