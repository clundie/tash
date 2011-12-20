//
//  CLAppDelegate.h
//  Tash
//
//  Created by Chris Lundie on 11-12-01.
//  Copyright (c) 2011 Chris Lundie. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class QTMovieView;

@interface CLAppDelegate : NSObject <NSApplicationDelegate>

- (IBAction)urlTextFieldAction:(id)sender;
- (IBAction)urlButtonAction:(id)sender;

@property (assign) IBOutlet NSWindow *window;
@property (assign) IBOutlet QTMovieView *movieView;
@property (assign) IBOutlet NSTextField *urlTextField;
@property (assign) IBOutlet NSProgressIndicator *progressIndicator;

@end
