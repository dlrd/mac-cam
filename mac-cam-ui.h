#pragma once

#import <Cocoa/Cocoa.h>
#import "mac-cam.h"

@class OpenGLCamView;

@interface AVCaptureDocument : NSDocument

@property (readonly) NSObject* capture;

@property (assign) IBOutlet OpenGLCamView *glCamView;

- (IBAction)start:(id)sender;
- (IBAction)stop:(id)sender;

@end
